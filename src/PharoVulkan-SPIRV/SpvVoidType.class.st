"
SPIR-V void type. Singleton within a module (deduped by SpvTypeRegistry).
"
Class {
	#name : 'SpvVoidType',
	#superclass : 'SpvType',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'encoding' }
SpvVoidType >> instruction [
    ^ SpvInstruction opcode: SpvOpcode opTypeVoid resultType: nil resultId: id operands: #()
]

{ #category : 'accessing' }
SpvVoidType >> key [ ^ #void
]
