"
Orchestrates the seven compiler stages that turn one annotated Pharo method into SPIR-V bytes:

1. PVBytecodeDecoder — Sista bytecode to PVBytecodeOp
2. PVStackSimulator — stack machine to PVRegisterOp register IR
3. PVTypeInferencer — register to SpvType, seeded from the <gpu> and <param:named:> pragmas
4. PVCFGBuilder — bytecode split into PVBytecodeBlock
5. PVStructuredCFGRecognizer — PVSelectionNode or PVLoopNode, skipped for a single block
6. PVSPIRVEmitter — the SpvModule
7. SpvSerializer and SpvValidator — the 32-bit little-endian binary

There is no SSA stage: PVSPIRVEmitter writes OpPhi itself by saving and restoring its register map at a merge point.

Entry point: compileMethod:. It is not called compile:, which is Behavior >> compile:.

decode runs stages one to four, once per compile whatever the target. One target method then runs stages five to seven: compileVertexShader, compileFragmentShader, compileComputeKernel or compileGenericKernel.
"
Class {
	#name : 'PVKernelCompiler',
	#superclass : 'Object',
	#instVars : [
		'method',
		'annotation',
		'regOps',
		'typeMap',
		'selectorTable',
		'blocks'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Pipeline'
}

{ #category : 'compiling' }
PVKernelCompiler class >> compileMethod: aCompiledMethod [
	"Front door of the compiler: the SPIR-V bytes of one annotated Pharo method.
	 Not named compile:, which is Behavior >> compile: and would hide it here."

	^ self new
		  method: aCompiledMethod;
		  compile
]

{ #category : 'constants' }
PVKernelCompiler class >> computeParamTypes [
	"A method is a compute kernel if it takes a work item, any kernel buffer or any
	 workgroup tile. The buffer and tile types come from the emitter so a new element type
	 is accepted here by adding it there once."

	^ { #workItem } , PVSPIRVEmitter bufferElementTypes keys asArray
	  , PVSPIRVEmitter sharedElementTypes keys asArray
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
	"Front door of the instance side: the annotation decides the target, the prologue runs
	 once, and one target method emits."

	annotation := PVTypeAnnotation fromMethod: method.
	annotation isGPU ifFalse: [ PVTypeError signal:
			'Method is not annotated with <gpu>, <gpuVertex>, or <gpuFragment>' ].
	self decode.
	annotation isVertex ifTrue: [ ^ self compileVertexShader ].
	annotation isFragment ifTrue: [ ^ self compileFragmentShader ].
	self isCompute ifTrue: [ ^ self compileComputeKernel ].
	^ self compileGenericKernel
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileComputeKernel [
	"A compute kernel with control flow must go through the recogniser like any other
	 kernel. Returning straight to compileComputeKernel: emitted the linearised register
	 ops as one basic block, which dropped the loop and still passed spirv-val. The
	 structured emitters infer their own types, because the per-block simulations number
	 registers differently from the whole-method one that typeMap came from."

	| structNode |
	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileComputeKernel: regOps
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	structNode := self recognizedNodeOr: 'Unrecognized CFG shape'.
	(structNode isKindOf: PVNestedLoopNode) ifTrue: [ ^ PVSPIRVEmitter
			   compileComputeKernelNestedLoop: structNode
			   annotation: annotation
			   selectorTable: selectorTable ].
	(structNode isKindOf: PVLoopNode) ifTrue: [ ^ PVSPIRVEmitter
			   compileComputeKernelLoop: structNode
			   annotation: annotation
			   selectorTable: selectorTable ].
	(structNode isKindOf: PVSelectionNode) ifTrue: [ ^ PVSPIRVEmitter
			   compileComputeKernelSelection: structNode
			   annotation: annotation
			   selectorTable: selectorTable ].
	PVTypeError signal:
		'Unrecognized control flow node: ' , structNode class name
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileFragmentShader [
	"A fragment shader is either straight-line code or one selection, as a vertex shader is;
	 only the emitter entry point and the execution model differ."

	| structNode |
	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileFragmentShader: regOps
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	structNode := self recognizedNodeOr: 'Unrecognized CFG shape in fragment shader'.
	(structNode isKindOf: PVSelectionNode) ifTrue: [ ^ PVSPIRVEmitter
			   compileShaderKernelSelection: structNode
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable
			   executionModel: SpvExecutionModel fragment ].
	PVTypeError signal:
		'Unsupported CFG in fragment shader: ' , structNode class name
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileGenericKernel [
	"The non-compute, non-shader kernel: a plain <gpu> method, which the emitter compiles
	 either as one basic block or through the recognised selection or loop."

	| structNode |
	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileKernel: regOps
			   typeMap: typeMap
			   annotation: annotation
			   selectorTable: selectorTable
			   name: method selector ].
	structNode := self recognizedNodeOr: 'Unrecognized CFG shape'.
	(structNode isKindOf: PVSelectionNode) ifTrue: [ ^ PVSPIRVEmitter
			   compileSelection: structNode
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	(structNode isKindOf: PVLoopNode) ifTrue: [ ^ PVSPIRVEmitter
			   compileLoop: structNode
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	PVTypeError signal:
		'Unrecognized control flow node: ' , structNode class name
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileVertexShader [
	"A vertex shader is either straight-line code or one selection. Anything else the
	 recogniser knows has no vertex emitter behind it."

	| structNode |
	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileVertexShader: regOps
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	structNode := self recognizedNodeOr: 'Unrecognized CFG shape in vertex shader'.
	(structNode isKindOf: PVSelectionNode) ifTrue: [ ^ PVSPIRVEmitter
			   compileShaderKernelSelection: structNode
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable
			   executionModel: SpvExecutionModel vertex ].
	PVTypeError signal:
		'Unsupported CFG in vertex shader: ' , structNode class name
]

{ #category : 'compiling - stages' }
PVKernelCompiler >> decode [
	"Stages one to four, the same whatever the target: bytecode to register operations,
	 types inferred over them, and the basic blocks the recogniser reads. The compute path,
	 the vertex path and the fragment path each wrote this prologue out in full."

	| bytecodeOps typeInferencer |
	bytecodeOps := PVBytecodeDecoder decode: method.
	regOps := PVStackSimulator
		          simulate: bytecodeOps
		          paramCount: annotation params size.
	selectorTable := PVSelectorTable standard.
	typeInferencer := PVTypeInferencer new initialize annotation: annotation.
	typeMap := typeInferencer inferAll: regOps selectorTable: selectorTable.
	blocks := PVCFGBuilder buildBytecodeBlocks: bytecodeOps
]

{ #category : 'compiling - stages' }
PVKernelCompiler >> isCompute [
	"A kernel is a compute kernel when one of its declared parameters is of a type only the
	 compute path has, the work item or a buffer."

	^ annotation params anySatisfy: [ :each |
		  self class computeParamTypes includes: each type ]
]

{ #category : 'accessing' }
PVKernelCompiler >> method [
^ method
]

{ #category : 'accessing' }
PVKernelCompiler >> method: aCompiledMethod [
	method := aCompiledMethod
]

{ #category : 'compiling - stages' }
PVKernelCompiler >> recognizedNodeOr: aMessageText [
	"The recogniser answers nil for a shape it does not know, and nil reaches the emitter as
	 a missing register rather than as the refusal it is."

	| node |
	node := PVStructuredCFGRecognizer recognizeFrom: blocks.
	node ifNil: [ PVTypeError signal: aMessageText ].
	^ node
]
