"
Container for the compiler CFG: an ordered collection of PVBasicBlock nodes with wired successor/predecessor edges. Produced by PVCFGBuilder after register-IR construction.
"
Class {
	#name : 'PVControlFlowGraph',
	#superclass : 'Object',
	#instVars : [
		'entry',
		'blocks'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
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
