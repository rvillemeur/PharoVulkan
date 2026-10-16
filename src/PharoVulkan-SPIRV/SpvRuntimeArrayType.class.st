"
SPIR-V runtime array type (unsized, used for storage buffers).
"
Class {
	#name : 'SpvRuntimeArrayType',
	#superclass : 'SpvType',
	#instVars : [
		'elementType'
	],
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'accessing' }
SpvRuntimeArrayType >> elementType [     ^ elementType
]

{ #category : 'accessing' }
SpvRuntimeArrayType >> elementType: t [  elementType := t
]

{ #category : 'encoding' }
SpvRuntimeArrayType >> instruction [
    ^ SpvInstruction
        opcode: SpvOpcode opTypeRuntimeArray
        resultType: nil
        resultId: id
        operands: { elementType id }
]

{ #category : 'abstract' }
SpvRuntimeArrayType >> key [ ^ Array with: #runtimeArray with: elementType id
]
