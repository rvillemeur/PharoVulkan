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

{ #category : 'accessing' }
PVSelectionNode >> trueBlocks [
^ trueBlocks
]

{ #category : 'accessing' }
PVSelectionNode >> trueBlocks: b [
	trueBlocks := b
]
