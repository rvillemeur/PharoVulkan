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

{ #category : 'reflection' }
PVKernelCompiler class >> stageClassNames [
	"The stages decode runs, named in the order it sends them and read from that method's own
	 syntax tree. Listing them again would let the Pipeline view outlive a stage."

	^ (((self >> #decode) ast allChildren select: [ :each |
		    each isMessage and: [
			    each receiver isVariable and: [
				    each receiver name first isUppercase ] ] ]) collect: [ :each |
		   each receiver name ]) asArray
]

{ #category : 'accessing' }
PVKernelCompiler >> annotation [
^ annotation
]

{ #category : 'accessing' }
PVKernelCompiler >> annotation: ann [
	annotation := ann
]

{ #category : 'accessing' }
PVKernelCompiler >> basicBlocks [
	"The basic blocks the CFG builder left, which the recogniser reads to find a shape."

	^ blocks
]

{ #category : 'compiling' }
PVKernelCompiler >> compile [
	"Front door of the instance side: the annotation decides the target, the prologue runs
	 once, and one target method emits."

	annotation := PVTypeAnnotation fromMethod: method.
	annotation isGPU ifFalse: [ PVTypeError signal:
			'Method is not annotated with <gpu>, <gpuVertex>, or <gpuFragment>' ].
	self decode.
	^ self perform: self targetSelector
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileComputeKernel [
	"A compute kernel with control flow must go through the recogniser like any other
	 kernel. Returning straight to compileComputeKernel: emitted the linearised register
	 ops as one basic block, which dropped the loop and still passed spirv-val."

	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileComputeKernel: regOps
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	^ (self recognizedNodeOr: 'Unrecognized CFG shape') emitComputeKernelWith: self
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileFragmentShader [
	"A fragment shader is shaped as a vertex shader is; only the straight-line emitter and
	 the execution model differ."

	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileFragmentShader: regOps
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	^ (self recognizedNodeOr: 'Unrecognized CFG shape in fragment shader')
		  emitShaderWith: self
		  executionModel: SpvExecutionModel fragment
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileGenericKernel [
	"The non-compute, non-shader kernel: a plain <gpu> method, emitted as one basic block or
	 by the shape the recogniser matched."

	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileKernel: regOps
			   typeMap: typeMap
			   annotation: annotation
			   selectorTable: selectorTable
			   name: method selector ].
	^ (self recognizedNodeOr: 'Unrecognized CFG shape') emitKernelWith: self
]

{ #category : 'compiling - targets' }
PVKernelCompiler >> compileVertexShader [
	"A vertex shader is either straight-line code or a shape with a shader emitter behind
	 it, which the node itself answers."

	blocks size = 1 ifTrue: [ ^ PVSPIRVEmitter
			   compileVertexShader: regOps
			   annotation: annotation
			   typeMap: typeMap
			   selectorTable: selectorTable ].
	^ (self recognizedNodeOr: 'Unrecognized CFG shape in vertex shader')
		  emitShaderWith: self
		  executionModel: SpvExecutionModel vertex
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

{ #category : 'inspector' }
PVKernelCompiler >> inspectorPipeline: aBuilder [
	"How far a compile got: the stages of the decode in the order they run, the target that
	 emits, and the size of what each stage left behind. Read from the compiler as it stands;
	 nothing is compiled to show it."

	<inspectorPresentationOrder: 10 title: 'Pipeline'>
	^ PVFactRow
		  tableOf: self pipelineRows
		  nameColumn: 'Stage or fact'
		  valueColumn: 'Value'
		  in: aBuilder
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

{ #category : 'inspector' }
PVKernelCompiler >> methodName [
	"The method being compiled, as a reader names it: class and selector, or nothing when the
	 compiler has not been given one."

	^ method ifNil: [ nil ] ifNotNil: [
		  method methodClass name , ' >> ' , method selector ]
]

{ #category : 'inspector' }
PVKernelCompiler >> pipelineRows [
	"The stages this compile ran and what they left behind. The stage classes are read from the
	 syntax tree of decode, in the order it sends them, so a stage added or removed shows here
	 by itself; the target is the selector compile dispatches on. Nothing is compiled to build
	 the rows: a compiler that has not run shows its stages with no state beside them."

	| rows position |
	rows := OrderedCollection new.
	position := 0.
	self class stageClassNames do: [ :each |
		position := position + 1.
		rows add: (PVFactRow
				 name: each
				 value: 'stage ' , position printString , ' of decode') ].
	rows add: (PVFactRow name: 'method' value: self methodName).
	rows add:
		(PVFactRow name: 'target' value: (annotation ifNotNil: [ self targetSelector ])).
	rows add: (PVFactRow
			 name: 'register operations'
			 value: (regOps ifNotNil: [ :each | each size ])).
	rows add: (PVFactRow
			 name: 'inferred types'
			 value: (typeMap ifNotNil: [ :each | each size ])).
	rows add: (PVFactRow
			 name: 'basic blocks'
			 value: (blocks ifNotNil: [ :each | each size ])).
	^ rows asArray
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

{ #category : 'accessing' }
PVKernelCompiler >> registerOperations [
	"The register IR the stack simulator left, which every target emits from."

	^ regOps
]

{ #category : 'accessing' }
PVKernelCompiler >> selectorTable [
	^ selectorTable
]

{ #category : 'compiling - stages' }
PVKernelCompiler >> targetSelector [
	"Which of the four targets emits for this method: the one place that choice is made, so
	 compile and the Pipeline view name the same target. The annotation decides a shader, the
	 declared parameters decide a compute kernel, and anything else is the generic kernel."

	annotation isVertex ifTrue: [ ^ #compileVertexShader ].
	annotation isFragment ifTrue: [ ^ #compileFragmentShader ].
	self isCompute ifTrue: [ ^ #compileComputeKernel ].
	^ #compileGenericKernel
]

{ #category : 'accessing' }
PVKernelCompiler >> typeMap [
	^ typeMap
]
