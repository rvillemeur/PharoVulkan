"
Abstract base for SPIR-V type declarations. Each concrete subclass knows its
deduplication key and how to encode itself as an OpType* instruction.
Key methods: id, key (abstract), instruction (abstract), encodeInto:.
"
Class {
	#name : 'SpvType',
	#superclass : 'Object',
	#instVars : [
		'id',
		'module'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'accessing' }
SpvType >> id [     ^ id
]

{ #category : 'accessing' }
SpvType >> id: x [  id := x
]

{ #category : 'abstract' }
SpvType >> instruction [ ^ self subclassResponsibility
]

{ #category : 'abstract' }
SpvType >> key [

	^ self subclassResponsibility
]

{ #category : 'accessing' }
SpvType >> module [ ^ module
]

{ #category : 'accessing' }
SpvType >> module: m [  module := m
]
