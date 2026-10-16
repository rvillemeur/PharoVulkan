"
SSA phi node. Holds a result register id and a list of (value, predecessor-block) pairs. Prepended to a block's instruction list by PVSSAConstructor and consumed by PVSPIRVEmitter to emit OpPhi.
"
Class {
	#name : 'PVPhiNode',
	#superclass : 'Object',
	#instVars : [
		'id',
		'type',
		'block',
		'operands'
	],
	#category : 'PharoVulkan-Compiler-SSA',
	#package : 'PharoVulkan-Compiler',
	#tag : 'SSA'
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
