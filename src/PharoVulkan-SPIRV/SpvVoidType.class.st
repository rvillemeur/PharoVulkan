"
SPIR-V void type. Singleton within a module (deduped by SpvTypeRegistry).
"
Class {
	#name : 'SpvVoidType',
	#superclass : 'SpvType',
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'encoding' }
SpvVoidType >> instruction [
    ^ SpvInstruction opcode: SpvOpcode opTypeVoid resultType: nil resultId: id operands: #()
]

{ #category : 'abstract' }
SpvVoidType >> key [ ^ #void
]
