"
Structured CFG node representing an ifTrue:ifFalse: selection. Holds the condition block, true branch, false branch, and merge block. Produced by PVStructuredCFGRecognizer; consumed by PVSPIRVEmitter to emit OpSelectionMerge.
"
Class {
	#name : 'PVSelectionNode',
	#superclass : 'Object',
	#instVars : [
		'condBlock',
		'trueBlocks',
		'falseBlocks',
		'mergeBlock'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
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
