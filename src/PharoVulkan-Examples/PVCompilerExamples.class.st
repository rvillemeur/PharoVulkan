"
Examples of what the compiler sees and makes: the nested loop node of the tiled matmul, the structured control flow recognised in the loop kernel, and the compiled tiled matmul module.

None of these touches a driver. They are the examples to open when the question is what the compiler decided rather than what the device computed, and the recogniser example in particular is the readable form of the pattern match the structurer depends on.
"
Class {
	#name : 'PVCompilerExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Compiler',
	#package : 'PharoVulkan-Examples',
	#tag : 'Compiler'
}

{ #category : 'examples' }
PVCompilerExamples class >> compilerOfTheClampKernel [
	"One click: the compiler that turned the clamp kernel into SPIR-V, every stage of its decode
	 already run. Open the Pipeline tab to read the stages in order, the target that emitted and
	 how much each stage left behind."

	<sampleInstance>
	| compiler |
	compiler := PVKernelCompiler new.
	compiler method: (PVKernelExamples >> #clampNegatives:data:out:).
	compiler compile.
	^ compiler
]

{ #category : 'examples' }
PVCompilerExamples class >> inferencerOfTheClampKernel [
	"One click: the inferencer that typed the registers of the clamp kernel, seeded from the
	 kernel's declared parameters. Open the Types tab to read the type of every register it
	 reached."

	<sampleInstance>
	| method annotation registerOps inferencer |
	method := PVKernelExamples >> #clampNegatives:data:out:.
	annotation := PVTypeAnnotation fromMethod: method.
	registerOps := PVStackSimulator
		               simulate: (PVBytecodeDecoder decode: method)
		               paramCount: annotation params size.
	inferencer := PVTypeInferencer new annotation: annotation.
	inferencer inferAll: registerOps selectorTable: PVSelectorTable standard.
	^ inferencer
]

{ #category : 'examples' }
PVCompilerExamples class >> mappingOfTheSubgroupSum [
"One click: the mapping the standard dispatch table holds for subgroupSum sent to an f32.
 Its Emitting tab says which method of PVSPIRVEmitter emits it and whether that method is
 one the mapping has to hand its own result type to, which is the dispatch the emitter no
 longer spells out branch by branch."

<sampleInstance>
^ PVSelectorTable standard at: #subgroupSum receiverType: #f32
]

{ #category : 'examples' }
PVCompilerExamples class >> nestedLoopOfTheTiledMatmul [
	"One click: the node the recogniser builds for the tiled matmul written in Pharo
	 source, the kernel this shape was added for. The Blocks tab shows which bytecode block
	 took each role."

	<sampleInstance>
	| blocks |
	blocks := PVCFGBuilder buildBytecodeBlocks:
		          (PVBytecodeDecoder decode:
			           (PVKernelExamples >> #tiledMatmulF32:a:b:out:tileA:tileB:)).
	^ PVStructuredCFGRecognizer recognizeFrom: blocks
]

{ #category : 'examples' }
PVCompilerExamples class >> recogniserOnLoopKernel [
	"A recogniser loaded with the control-flow graph of a kernel that holds one loop,
	 the shape PVLoopNode represents. Inspect it and open the Recognition tab to see
	 which blocks the answered node accounts for."

	<sampleInstance>
	| bytecodes |
	bytecodes := PVBytecodeDecoder decode: (PVKernelExamples >> #accumulateUpTo:).
	^ PVStructuredCFGRecognizer new initialize: (PVCFGBuilder buildBytecodeBlocks: bytecodes)
]

{ #category : 'examples' }
PVCompilerExamples class >> selectionOfAClampKernel [
	"One click: the node the recogniser builds for an ifTrue:ifFalse: kernel, the one shape
	 every target emits. Open the Targets tab beside nestedLoopOfTheTiledMatmul, whose shape
	 only the compute path emits."

	<sampleInstance>
	| blocks |
	blocks := PVCFGBuilder buildBytecodeBlocks:
		          (PVBytecodeDecoder decode: (PVKernelExamples >> #clampNegatives:data:out:)).
	^ PVStructuredCFGRecognizer recognizeFrom: blocks
]

{ #category : 'examples' }
PVCompilerExamples class >> simulationOfAClampConditionBlock [
	"One click: what PVBlockSimulator reaches at the end of the condition block of the clamp
	 kernel. The Parts tab names the five parts PVSPIRVEmitter reads from it."

	<sampleInstance>
	| node |
	node := self selectionOfAClampKernel.
	^ PVBlockSimulator new
		  simulateBlock: node condBlock
		  initialTempDefs: Dictionary new
		  startingNextReg: 1
]

{ #category : 'examples' }
PVCompilerExamples class >> standardSelectorTable [
	"One click: the dispatch table the compiler builds for every kernel it decodes. Open the
	 Dispatch tab to read every send the DSL maps, the SPIR-V operation it becomes and the type
	 of its result."

	<sampleInstance>
	^ PVSelectorTable standard
]

{ #category : 'examples' }
PVCompilerExamples class >> tiledMatmulModule [
	"One click: the hand-built module, with its bytes already built. The Module tab reads
	 the shared tiles, the barriers and the loops back out of those bytes, and says what
	 spirv-val makes of them."

	<sampleInstance>
	| kernel |
	kernel := PVTiledMatmulKernel new.
	kernel spirv.
	^ kernel
]
