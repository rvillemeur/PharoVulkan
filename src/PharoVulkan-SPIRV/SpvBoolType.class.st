"
SPIR-V boolean type.
"
Class {
	#name : 'SpvBoolType',
	#superclass : 'SpvType',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'encoding' }
SpvBoolType >> instruction [
    ^ SpvInstruction opcode: SpvOpcode opTypeBool resultType: nil resultId: id operands: #()
]

{ #category : 'accessing' }
SpvBoolType >> key [ ^ #bool
]
