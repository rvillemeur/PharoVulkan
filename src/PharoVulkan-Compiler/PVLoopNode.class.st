"
Structured CFG node representing a whileTrue: loop. Holds the header block, body blocks, and merge block. Produced by PVStructuredCFGRecognizer; consumed by PVSPIRVEmitter to emit OpLoopMerge.
"
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
