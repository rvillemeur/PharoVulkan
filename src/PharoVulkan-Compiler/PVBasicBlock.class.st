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
	#package : 'PharoVulkan-Compiler'
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
