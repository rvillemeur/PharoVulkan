"
Orchestrates all 9 compiler stages: 
1. bytecode decode 
2. stack simulation 
3. CFG build 
4. SSA construction 
5. type inference 
6. structured-CFG recognition 
7. SPIR-V emit 
8.  validation. 


Entry point: compile:forDevice:.
"
Class {
	#name : 'PVKernelCompiler',
	#superclass : 'Object',
	#instVars : [
		'method',
		'annotation'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan',
	#tag : 'Compiler-Pipeline'
}

{ #category : 'compiling' }
PVKernelCompiler class >> compile: aCompiledMethod [
	^ self new method: aCompiledMethod; compile
]

{ #category : 'constants' }
PVKernelCompiler class >> computeParamTypes [
	"A method is a compute kernel if it takes a work item or any kernel buffer. The buffer
	 types come from the emitter so a new element type is accepted here by adding it there
	 once."

	^ { #workItem } , PVSPIRVEmitter bufferElementTypes keys asArray
]

{ #category : 'accessing' }
PVKernelCompiler >> annotation [
^ annotation
]

{ #category : 'accessing' }
PVKernelCompiler >> annotation: ann [
	annotation := ann
]

{ #category : 'compiling' }
PVKernelCompiler >> compile [
	| bytecodeOps blocks structNode regOps st typeMap typeInf isCompute |
	annotation := PVTypeAnnotation fromMethod: method.
	annotation isGPU ifFalse: [ PVTypeError signal: 'Method is not annotated with <gpu>, <gpuVertex>, or <gpuFragment>' ].
	annotation isVertex ifTrue: [
		bytecodeOps := PVBytecodeDecoder decode: method.
		regOps := PVStackSimulator simulate: bytecodeOps paramCount: annotation params size.
		st := PVSelectorTable standard.
		typeInf := PVTypeInferencer new initialize annotation: annotation.
		[ typeMap := typeInf inferAll: regOps selectorTable: st ] on: PVTypeError do: [ :e | typeMap := typeInf typeMap ].
		blocks := PVCFGBuilder buildBytecodeBlocks: bytecodeOps.
		blocks size = 1 ifTrue: [
			^ PVSPIRVEmitter compileVertexShader: regOps annotation: annotation typeMap: typeMap selectorTable: st ].
		structNode := PVStructuredCFGRecognizer recognizeFrom: blocks.
		structNode isNil ifTrue: [ PVTypeError signal: 'Unrecognized CFG shape in vertex shader' ].
		(structNode isKindOf: PVSelectionNode) ifTrue: [
			^ PVSPIRVEmitter compileShaderKernelSelection: structNode annotation: annotation typeMap: typeMap selectorTable: st executionModel: SpvExecutionModel vertex ].
		PVTypeError signal: 'Unsupported CFG in vertex shader: ' , structNode class name ].
	annotation isFragment ifTrue: [
		bytecodeOps := PVBytecodeDecoder decode: method.
		regOps := PVStackSimulator simulate: bytecodeOps paramCount: annotation params size.
		st := PVSelectorTable standard.
		typeInf := PVTypeInferencer new initialize annotation: annotation.
		[ typeMap := typeInf inferAll: regOps selectorTable: st ] on: PVTypeError do: [ :e | typeMap := typeInf typeMap ].
		blocks := PVCFGBuilder buildBytecodeBlocks: bytecodeOps.
		blocks size = 1 ifTrue: [
			^ PVSPIRVEmitter compileFragmentShader: regOps annotation: annotation typeMap: typeMap selectorTable: st ].
		structNode := PVStructuredCFGRecognizer recognizeFrom: blocks.
		structNode isNil ifTrue: [ PVTypeError signal: 'Unrecognized CFG shape in fragment shader' ].
		(structNode isKindOf: PVSelectionNode) ifTrue: [
			^ PVSPIRVEmitter compileShaderKernelSelection: structNode annotation: annotation typeMap: typeMap selectorTable: st executionModel: SpvExecutionModel fragment ].
		PVTypeError signal: 'Unsupported CFG in fragment shader: ' , structNode class name ].
	isCompute := annotation params anySatisfy: [ :p |
		self class computeParamTypes includes: p type ].
	bytecodeOps := PVBytecodeDecoder decode: method.
	regOps := PVStackSimulator simulate: bytecodeOps paramCount: annotation params size.
	st := PVSelectorTable standard.
	typeInf := PVTypeInferencer new initialize annotation: annotation.
	[ typeMap := typeInf inferAll: regOps selectorTable: st ] on: PVTypeError do: [ :e | typeMap := typeInf typeMap ].
	blocks := PVCFGBuilder buildBytecodeBlocks: bytecodeOps.
	isCompute ifTrue: [
		^ self compileComputeBlocks: blocks regOps: regOps typeMap: typeMap selectorTable: st ].
	blocks size = 1 ifTrue: [
		| cfg ssaCFG |
		cfg := PVCFGBuilder buildFrom: regOps.
		ssaCFG := PVSSAConstructor construct: cfg.
		^ PVSPIRVEmitter compileKernel: regOps typeMap: typeMap annotation: annotation selectorTable: st name: method selector ].
	structNode := PVStructuredCFGRecognizer recognizeFrom: blocks.
	structNode isNil ifTrue: [ PVTypeError signal: 'Unrecognized CFG shape' ].
	(structNode isKindOf: PVSelectionNode) ifTrue: [
		^ PVSPIRVEmitter compileSelection: structNode annotation: annotation typeMap: typeMap selectorTable: st ].
	(structNode isKindOf: PVLoopNode) ifTrue: [
		^ PVSPIRVEmitter compileLoop: structNode annotation: annotation typeMap: typeMap selectorTable: st ].
	PVTypeError signal: 'Unrecognized control flow node: ' , structNode class name
]

{ #category : 'compiling' }
PVKernelCompiler >> compileComputeBlocks: blocks regOps: regOps typeMap: typeMap selectorTable: st [
	"A compute kernel with control flow must go through the recogniser like any other
	 kernel. Returning straight to compileComputeKernel: emitted the linearised register
	 ops as one basic block, which dropped the loop and still passed spirv-val. The two
	 structured emitters infer their own types, because the per-block simulations number
	 registers differently from the whole-method one that typeMap came from."

	| structNode |
	blocks size = 1 ifTrue: [
		^ PVSPIRVEmitter
			  compileComputeKernel: regOps
			  annotation: annotation
			  typeMap: typeMap
			  selectorTable: st ].
	structNode := PVStructuredCFGRecognizer recognizeFrom: blocks.
	structNode isNil ifTrue: [ PVTypeError signal: 'Unrecognized CFG shape' ].
	(structNode isKindOf: PVLoopNode) ifTrue: [
		^ PVSPIRVEmitter
			  compileComputeKernelLoop: structNode
			  annotation: annotation
			  selectorTable: st ].
	(structNode isKindOf: PVSelectionNode) ifTrue: [
		^ PVSPIRVEmitter
			  compileComputeKernelSelection: structNode
			  annotation: annotation
			  selectorTable: st ].
	PVTypeError signal:
		'Unrecognized control flow node: ' , structNode class name
]

{ #category : 'accessing' }
PVKernelCompiler >> method [
^ method
]

{ #category : 'accessing' }
PVKernelCompiler >> method: aCompiledMethod [
	method := aCompiledMethod
]
