"
A basic block in the compiler register IR. Holds a sequence of PVRegisterOp instructions with a single entry and one or two successors (fall-through or conditional branch). Built by PVCFGBuilder.
"
Class {
	#name : 'PVBasicBlock',
	#superclass : 'Object',
	#instVars : [
		'id',
		'ops',
		'successors',
		'predecessors'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'accessing' }
PVBasicBlock >> id [
^ id
]

{ #category : 'accessing' }
PVBasicBlock >> id: anInteger [
	id := anInteger
]

{ #category : 'accessing' }
PVBasicBlock >> ops [
^ ops
]

{ #category : 'accessing' }
PVBasicBlock >> ops: aCollection [
	ops := aCollection
]

{ #category : 'accessing' }
PVBasicBlock >> predecessors [
^ predecessors
]

{ #category : 'accessing' }
PVBasicBlock >> predecessors: aCollection [
	predecessors := aCollection
]

{ #category : 'accessing' }
PVBasicBlock >> successors [
^ successors
]

{ #category : 'accessing' }
PVBasicBlock >> successors: aCollection [
	successors := aCollection
]
