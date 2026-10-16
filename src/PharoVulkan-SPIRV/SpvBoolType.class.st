"
SPIR-V boolean type.
"
Class {
	#name : 'SpvBoolType',
	#superclass : 'SpvType',
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'encoding' }
SpvBoolType >> instruction [
    ^ SpvInstruction opcode: SpvOpcode opTypeBool resultType: nil resultId: id operands: #()
]

{ #category : 'accessing' }
SpvBoolType >> key [ ^ #bool
]
