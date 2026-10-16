"
IR-level basic block. nodes are non-terminator SpvIRNodes; terminator is the branch/return.
"
Class {
	#name : 'SpvIRBlock',
	#superclass : 'Object',
	#instVars : [
		'id',
		'nodes',
		'terminator'
	],
	#category : 'PharoVulkan-SPIRV-IR',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'IR'
}

{ #category : 'building' }
SpvIRBlock >> add: aNode [
	nodes add: aNode.
	^ aNode
]

{ #category : 'accessing' }
SpvIRBlock >> id [ ^ id
]

{ #category : 'accessing' }
SpvIRBlock >> id: n [ id := n
]

{ #category : 'initialization' }
SpvIRBlock >> initialize [

	super initialize.
	nodes := OrderedCollection new
]

{ #category : 'testing' }
SpvIRBlock >> isTerminated [ ^ terminator notNil
]

{ #category : 'accessing' }
SpvIRBlock >> nodes [ ^ nodes
]

{ #category : 'building' }
SpvIRBlock >> terminate: aNode [
	terminator := aNode.
	^ aNode
]

{ #category : 'accessing' }
SpvIRBlock >> terminator [ ^ terminator
]
