"
Structured CFG node representing an ifTrue:ifFalse: selection. Holds the condition block, true branch, false branch, and merge block. Produced by PVStructuredCFGRecognizer; consumed by PVSPIRVEmitter to emit OpSelectionMerge.
"
Class {
	#name : 'PVSelectionNode',
	#superclass : 'PVStructuredNode',
	#instVars : [
		'condBlock',
		'trueBlocks',
		'falseBlocks',
		'mergeBlock'
	],
	#category : 'PharoVulkan-Compiler-Graph',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Graph'
}

{ #category : 'accessing' }
PVSelectionNode >> condBlock [
^ condBlock
]

{ #category : 'accessing' }
PVSelectionNode >> condBlock: b [
	condBlock := b
]

{ #category : 'accessing' }
PVSelectionNode >> coveredBlocks [
	"Every bytecode block this node accounts for. The recogniser compares this against
	 the whole block list, so a node is never used to describe a graph that has more in
	 it than the node can emit."

	^ ({ condBlock } , trueBlocks , falseBlocks , { mergeBlock }) reject: [ :each |
		  each isNil ]
]

{ #category : 'emitting' }
PVSelectionNode >> emitComputeKernelWith: aCompiler [
	"The compute emitters infer their own types, because the per-block simulations number
	 registers differently from the whole-method one aCompiler typeMap came from."

	^ PVSPIRVEmitter
		  compileComputeKernelSelection: self
		  annotation: aCompiler annotation
		  selectorTable: aCompiler selectorTable
]

{ #category : 'emitting' }
PVSelectionNode >> emitKernelWith: aCompiler [
	^ PVSPIRVEmitter
		  compileSelection: self
		  annotation: aCompiler annotation
		  typeMap: aCompiler typeMap
		  selectorTable: aCompiler selectorTable
]

{ #category : 'emitting' }
PVSelectionNode >> emitShaderWith: aCompiler executionModel: anExecutionModel [
	"The one shape a vertex or fragment shader may have beyond straight-line code."

	^ PVSPIRVEmitter
		  compileShaderKernelSelection: self
		  annotation: aCompiler annotation
		  typeMap: aCompiler typeMap
		  selectorTable: aCompiler selectorTable
		  executionModel: anExecutionModel
]

{ #category : 'accessing' }
PVSelectionNode >> falseBlocks [
^ falseBlocks
]

{ #category : 'accessing' }
PVSelectionNode >> falseBlocks: b [
	falseBlocks := b
]

{ #category : 'accessing' }
PVSelectionNode >> mergeBlock [
^ mergeBlock
]

{ #category : 'accessing' }
PVSelectionNode >> mergeBlock: b [
	mergeBlock := b
]

{ #category : 'simulating' }
PVSelectionNode >> simulationsWith: ann selectorTable: st [
	"Simulate my four blocks with one shared register numbering, and infer the types over
	 that numbering. The phi register is the first register no block defined, and its type
	 is the type of the value the arms produce, which the merge block then consumes."

	| condSim trueSim falseSim mergeSim phiReg inference typeMap |
	condSim := PVBlockSimulator new
		           simulateBlock: self condBlock
		           initialTempDefs: ann paramTempDefs
		           startingNextReg: ann params size + 1.
	trueSim := PVBlockSimulator new
		           simulateBlock: self trueBlocks first
		           initialTempDefs: condSim tempDefs
		           startingNextReg: condSim nextReg.
	falseSim := PVBlockSimulator new
		            simulateBlock: self falseBlocks first
		            initialTempDefs: condSim tempDefs
		            startingNextReg: trueSim nextReg.
	phiReg := falseSim nextReg.
	mergeSim := PVBlockSimulator new
		            simulateBlock: self mergeBlock
		            initialTempDefs: condSim tempDefs
		            startingNextReg: phiReg + 1
		            initialStack: (condSim mergeStackWithPhiReg: phiReg).
	inference := PVBlockSimulation
		             typesOver: { condSim. trueSim. falseSim }
		             annotation: ann
		             selectorTable: st.
	typeMap := inference second.
	typeMap
		at: phiReg
		put: (typeMap at: trueSim resultReg ifAbsent: [ typeMap at: falseSim resultReg ]).
	inference first inferAll: mergeSim regOps selectorTable: st.
	^ Dictionary newFrom: {
			  (#cond -> condSim).
			  (#true -> trueSim).
			  (#false -> falseSim).
			  (#merge -> mergeSim).
			  (#phiReg -> phiReg).
			  (#typeMap -> typeMap) }
]

{ #category : 'accessing' }
PVSelectionNode >> trueBlocks [
^ trueBlocks
]

{ #category : 'accessing' }
PVSelectionNode >> trueBlocks: b [
	trueBlocks := b
]
