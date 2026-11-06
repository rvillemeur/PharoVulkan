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
