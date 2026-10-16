"
Describes one SPIR-V instruction from spirv.core.grammar.json.
opname is a String, opcode is an Integer.
operands is an Array of SpvOperandDescriptor.
capabilities is an Array of String.
"
Class {
	#name : 'SpvInstructionDescriptor',
	#superclass : 'Object',
	#instVars : [
		'opname',
		'opcode',
		'operands',
		'capabilities'
	],
	#category : 'PharoVulkan-Generator-SPIRV',
	#package : 'PharoVulkan-Generator',
	#tag : 'SPIRV'
}

{ #category : 'accessing' }
SpvInstructionDescriptor >> capabilities [
    ^ capabilities
]

{ #category : 'accessing' }
SpvInstructionDescriptor >> capabilities: aValue [
    capabilities := aValue
]

{ #category : 'accessing' }
SpvInstructionDescriptor >> opcode [
    ^ opcode
]

{ #category : 'accessing' }
SpvInstructionDescriptor >> opcode: aValue [
    opcode := aValue
]

{ #category : 'accessing' }
SpvInstructionDescriptor >> operands [
    ^ operands
]

{ #category : 'accessing' }
SpvInstructionDescriptor >> operands: aValue [
    operands := aValue
]

{ #category : 'accessing' }
SpvInstructionDescriptor >> opname [
    ^ opname
]

{ #category : 'accessing' }
SpvInstructionDescriptor >> opname: aValue [
    opname := aValue
]
