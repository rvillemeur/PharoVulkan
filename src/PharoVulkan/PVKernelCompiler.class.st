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

{ #category : 'accessing' }
PVKernelCompiler >> annotation [
^ annotation
]

{ #category : 'accessing' }
PVKernelCompiler >> annotation: ann [
	annotation := ann
]

{ #category : 'compilation' }
PVKernelCompiler >> compile [
	| bytecodeOps blocks structNode regOps cfg ssaCFG st typeMap typeInf |
	annotation := PVTypeAnnotation fromMethod: method.
	annotation isGPU ifFalse: [ PVTypeError signal: 'Method is not annotated with <gpu>' ].
	bytecodeOps := PVBytecodeDecoder decode: method.
	blocks := PVCFGBuilder buildBytecodeBlocks: bytecodeOps.
	blocks size = 1 ifTrue: [
		regOps := PVStackSimulator simulate: bytecodeOps.
		cfg := PVCFGBuilder buildFrom: regOps.
		ssaCFG := PVSSAConstructor construct: cfg.
		st := PVSelectorTable standard.
		typeInf := PVTypeInferencer new initialize annotation: annotation.
		typeMap := typeInf inferAll: regOps selectorTable: st.
		^ PVSPIRVEmitter compileKernel: regOps typeMap: typeMap annotation: annotation selectorTable: st name: method selector ].
	structNode := PVStructuredCFGRecognizer recognizeFrom: blocks.
	structNode isNil ifTrue: [ PVTypeError signal: 'Unrecognized CFG shape' ].
	regOps := PVStackSimulator simulate: bytecodeOps.
	st := PVSelectorTable standard.
	typeMap := Dictionary new.
	typeInf := PVTypeInferencer new initialize annotation: annotation.
	[ typeInf inferAll: regOps selectorTable: st ] on: PVTypeError do: [ :e | typeMap ].
	typeMap := typeInf typeMap.
	(structNode isKindOf: PVSelectionNode) ifTrue: [
		^ PVSPIRVEmitter compileSelection: structNode annotation: annotation typeMap: typeMap selectorTable: st ].
	(structNode isKindOf: PVLoopNode) ifTrue: [
		^ PVSPIRVEmitter compileLoop: structNode annotation: annotation typeMap: typeMap selectorTable: st ].
	PVTypeError signal: 'Unrecognized control flow node: ' , structNode class name
]

{ #category : 'accessing' }
PVKernelCompiler >> method [
^ method
]

{ #category : 'accessing' }
PVKernelCompiler >> method: aCompiledMethod [
	method := aCompiledMethod
]
