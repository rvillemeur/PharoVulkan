"
Describes one operand of a SPIR-V instruction from the grammar.
kind is a String (e.g. 'IdResultType').
quantifier is #required, #optional, or #variadic.
"
Class {
	#name : 'SpvOperandDescriptor',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'name',
		'quantifier'
	],
	#category : 'PharoVulkan-Generator',
	#package : 'PharoVulkan',
	#tag : 'Generator'
}

{ #category : 'accessing' }
SpvOperandDescriptor >> kind [
    ^ kind
]

{ #category : 'accessing' }
SpvOperandDescriptor >> kind: aValue [
    kind := aValue
]

{ #category : 'accessing' }
SpvOperandDescriptor >> name [
    ^ name
]

{ #category : 'accessing' }
SpvOperandDescriptor >> name: aValue [
    name := aValue
]

{ #category : 'accessing' }
SpvOperandDescriptor >> quantifier [
    ^ quantifier
]

{ #category : 'accessing' }
SpvOperandDescriptor >> quantifier: aValue [
    quantifier := aValue
]
