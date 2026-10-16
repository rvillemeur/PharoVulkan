"
A SPIR-V basic block. Owns an ordered list of non-terminator instructions plus
exactly one terminator. Every block must be terminated before the function is serialized.
Key methods: addInstruction:, terminate:, isTerminated.
"
Class {
	#name : 'SpvBlock',
	#superclass : 'Object',
	#instVars : [
		'id',
		'function',
		'instructions',
		'terminator'
	],
	#category : 'PharoVulkan-SPIRV-Builder',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Builder'
}

{ #category : 'building' }
SpvBlock >> addInstruction: anInstruction [
    "Append a non-terminator instruction. Raises if block is already terminated."
    self isTerminated ifTrue: [ Error signal: 'Block already terminated' ].
    instructions add: anInstruction
]

{ #category : 'accessing' }
SpvBlock >> function [      ^ function
]

{ #category : 'accessing' }
SpvBlock >> function: f [   function := f
]

{ #category : 'accessing' }
SpvBlock >> id [            ^ id
]

{ #category : 'accessing' }
SpvBlock >> id: x [         id := x
]

{ #category : 'initialization' }
SpvBlock >> initialize [

	super initialize.
	instructions := OrderedCollection new
]

{ #category : 'accessing' }
SpvBlock >> instructions [  ^ instructions
]

{ #category : 'testing' }
SpvBlock >> isTerminated [  ^ terminator notNil
]

{ #category : 'building' }
SpvBlock >> prependInstruction: anInstruction [
	instructions addFirst: anInstruction
]

{ #category : 'building' }
SpvBlock >> terminate: anInstruction [
    "Set the terminator. Raises if block is already terminated."
    self isTerminated ifTrue: [ Error signal: 'Block already has a terminator' ].
    terminator := anInstruction
]

{ #category : 'accessing' }
SpvBlock >> terminator [    ^ terminator
]
