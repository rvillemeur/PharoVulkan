"
Structured CFG node representing a whileTrue: loop. Holds the header block, body blocks, and merge block. Produced by PVStructuredCFGRecognizer; consumed by PVSPIRVEmitter to emit OpLoopMerge.
"
Class {
	#name : 'PVLoopNode',
	#superclass : 'PVStructuredNode',
	#instVars : [
		'preheaderBlock',
		'headerBlock',
		'bodyBlocks',
		'exitBlock'
	],
	#category : 'PharoVulkan-Compiler-Graph',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Graph'
}

{ #category : 'accessing' }
PVLoopNode >> bodyBlocks [
^ bodyBlocks
]

{ #category : 'accessing' }
PVLoopNode >> bodyBlocks: b [
	bodyBlocks := b
]

{ #category : 'accessing' }
PVLoopNode >> coveredBlocks [
	"Every bytecode block this node accounts for. See PVSelectionNode >> coveredBlocks."

	^ ({ preheaderBlock. headerBlock } , bodyBlocks , { exitBlock }) reject: [ :each |
		  each isNil ]
]

{ #category : 'emitting' }
PVLoopNode >> emitComputeKernelWith: aCompiler [
	"The compute emitters infer their own types; see PVSelectionNode >> emitComputeKernelWith:."

	^ PVSPIRVEmitter
		  compileComputeKernelLoop: self
		  annotation: aCompiler annotation
		  selectorTable: aCompiler selectorTable
]

{ #category : 'emitting' }
PVLoopNode >> emitKernelWith: aCompiler [
	^ PVSPIRVEmitter
		  compileLoop: self
		  annotation: aCompiler annotation
		  typeMap: aCompiler typeMap
		  selectorTable: aCompiler selectorTable
]

{ #category : 'accessing' }
PVLoopNode >> exitBlock [
^ exitBlock
]

{ #category : 'accessing' }
PVLoopNode >> exitBlock: b [
	exitBlock := b
]

{ #category : 'accessing' }
PVLoopNode >> headerBlock [
^ headerBlock
]

{ #category : 'accessing' }
PVLoopNode >> headerBlock: b [
	headerBlock := b
]

{ #category : 'accessing' }
PVLoopNode >> preheaderBlock [
^ preheaderBlock
]

{ #category : 'accessing' }
PVLoopNode >> preheaderBlock: b [
	preheaderBlock := b
]

{ #category : 'simulating' }
PVLoopNode >> simulationsWith: ann selectorTable: st [
	"Simulate my four blocks with one shared register numbering, and infer the types over
	 that numbering. The exit block inherits the preheader's stack residue, because the
	 preheader may leave a value on the stack that the code after the loop pops."

	| preheaderSim headerSim latchSim exitSim |
	preheaderSim := PVBlockSimulator new
		                simulateBlock: self preheaderBlock
		                initialTempDefs: ann paramTempDefs
		                startingNextReg: ann params size + 1.
	headerSim := PVBlockSimulator new
		             simulateBlock: self headerBlock
		             initialTempDefs: preheaderSim tempDefs
		             startingNextReg: preheaderSim nextReg.
	latchSim := PVBlockSimulator new
		            simulateBlock: self bodyBlocks first
		            initialTempDefs: preheaderSim tempDefs
		            startingNextReg: headerSim nextReg.
	exitSim := PVBlockSimulator new
		           simulateBlock: self exitBlock
		           initialTempDefs: preheaderSim tempDefs
		           startingNextReg: latchSim nextReg
		           initialStack: preheaderSim stack.
	^ Dictionary newFrom: {
			  (#preheader -> preheaderSim).
			  (#header -> headerSim).
			  (#latch -> latchSim).
			  (#exit -> exitSim).
			  (#typeMap -> (PVBlockSimulation
				    typesOver: {
						    preheaderSim.
						    headerSim.
						    latchSim.
						    exitSim }
				    annotation: ann
				    selectorTable: st) second) }
]
