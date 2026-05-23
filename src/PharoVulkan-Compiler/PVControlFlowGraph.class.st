Class {
	#name : 'PVControlFlowGraph',
	#superclass : 'Object',
	#instVars : [
		'entry',
		'blocks'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'accessing' }
PVControlFlowGraph >> blocks [
^ blocks
]

{ #category : 'accessing' }
PVControlFlowGraph >> blocks: aCollection [
	blocks := aCollection
]

{ #category : 'accessing' }
PVControlFlowGraph >> entry [
^ entry
]

{ #category : 'accessing' }
PVControlFlowGraph >> entry: aBlock [
	entry := aBlock
]
