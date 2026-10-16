"
IR-level function. Owns parameters and an ordered list of SpvIRBlocks.
"
Class {
	#name : 'SpvIRFunction',
	#superclass : 'Object',
	#instVars : [
		'name',
		'returnType',
		'parameterTypes',
		'parameters',
		'blocks'
	],
	#category : 'PharoVulkan-SPIRV-IR',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'IR'
}

{ #category : 'instance creation' }
SpvIRFunction class >> name: aString returnType: aType [
	^ (self new)
		name: aString;
		returnType: aType;
		yourself
]

{ #category : 'building' }
SpvIRFunction >> addBlock [
	| b |
	b := SpvIRBlock new initialize.
	blocks add: b.
	^ b
]

{ #category : 'building' }
SpvIRFunction >> addParameterType: aSpvType [
	| p |
	p := SpvIRParameter new type: aSpvType; yourself.
	parameterTypes add: aSpvType.
	parameters add: p.
	^ p
]

{ #category : 'accessing' }
SpvIRFunction >> blocks [ ^ blocks
]

{ #category : 'initialization' }
SpvIRFunction >> initialize [

	super initialize.
	parameterTypes := OrderedCollection new.
	parameters := OrderedCollection new.
	blocks := OrderedCollection new
]

{ #category : 'accessing' }
SpvIRFunction >> name [ ^ name
]

{ #category : 'accessing' }
SpvIRFunction >> name: s [ name := s
]

{ #category : 'accessing' }
SpvIRFunction >> parameterTypes [ ^ parameterTypes
]

{ #category : 'accessing' }
SpvIRFunction >> parameters [ ^ parameters
]

{ #category : 'accessing' }
SpvIRFunction >> returnType [ ^ returnType
]

{ #category : 'accessing' }
SpvIRFunction >> returnType: t [ returnType := t
]
