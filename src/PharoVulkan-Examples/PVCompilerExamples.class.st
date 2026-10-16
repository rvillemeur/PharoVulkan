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
