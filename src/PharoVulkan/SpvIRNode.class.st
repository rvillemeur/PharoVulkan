"
Abstract base for typed IR nodes. id assigned by SpvModuleEmitter pass 1. hasResult = false for void instructions (store, return).
"
Class {
	#name : 'SpvIRNode',
	#superclass : 'Object',
	#instVars : [
		'type',
		'id'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'instance creation' }
SpvIRNode class >> withType: aType [
	^ self new type: aType; yourself
]

{ #category : 'emitting' }
SpvIRNode >> emitInto: anSpvBlock idMap: aMap module: aModule [ self subclassResponsibility
]

{ #category : 'testing' }
SpvIRNode >> hasResult [ ^ true
]

{ #category : 'accessing' }
SpvIRNode >> id [ ^ id
]

{ #category : 'accessing' }
SpvIRNode >> id: n [ id := n
]

{ #category : 'accessing' }
SpvIRNode >> type [ ^ type
]

{ #category : 'accessing' }
SpvIRNode >> type: t [ type := t
]
