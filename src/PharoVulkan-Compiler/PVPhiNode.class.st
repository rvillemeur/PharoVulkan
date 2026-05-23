Class {
	#name : 'PVPhiNode',
	#superclass : 'Object',
	#instVars : [
		'id',
		'type',
		'block',
		'operands'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'accessing' }
PVPhiNode >> block [
^ block
]

{ #category : 'accessing' }
PVPhiNode >> block: aBlock [
	block := aBlock
]

{ #category : 'accessing' }
PVPhiNode >> id [
^ id
]

{ #category : 'accessing' }
PVPhiNode >> id: anInteger [
	id := anInteger
]

{ #category : 'accessing' }
PVPhiNode >> operands [
^ operands
]

{ #category : 'accessing' }
PVPhiNode >> operands: aCollection [
	operands := aCollection
]

{ #category : 'accessing' }
PVPhiNode >> type [
^ type
]

{ #category : 'accessing' }
PVPhiNode >> type: aType [
	type := aType
]
