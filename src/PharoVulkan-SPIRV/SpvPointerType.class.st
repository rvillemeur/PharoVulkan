"
SPIR-V pointer type. storageClass is a SpvStorageClass integer.
"
Class {
	#name : 'SpvPointerType',
	#superclass : 'SpvType',
	#instVars : [
		'storageClass',
		'baseType'
	],
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'accessing' }
SpvPointerType >> baseType: t [     baseType := t
]

{ #category : 'encoding' }
SpvPointerType >> instruction [
    ^ SpvInstruction
        opcode: SpvOpcode opTypePointer
        resultType: nil
        resultId: id
        operands: { storageClass. baseType id }
]

{ #category : 'accessing' }
SpvPointerType >> key [ ^ Array with: #pointer with: storageClass with: baseType id
]

{ #category : 'accessing' }
SpvPointerType >> storageClass: s [ storageClass := s
]
