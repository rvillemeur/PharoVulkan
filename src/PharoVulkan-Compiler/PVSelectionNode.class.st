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
	#package : 'PharoVulkan-Compiler'
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
