Class {
	#name : 'PVLoopNode',
	#superclass : 'Object',
	#instVars : [
		'preheaderBlock',
		'headerBlock',
		'bodyBlocks',
		'exitBlock'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
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
