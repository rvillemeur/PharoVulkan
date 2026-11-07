"
SPIR-V struct type. memberTypes is an Array of SpvType.
"
Class {
	#name : 'SpvStructType',
	#superclass : 'SpvType',
	#instVars : [
		'memberTypes'
	],
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'encoding' }
SpvStructType >> instruction [
    ^ SpvInstruction
        opcode: SpvOpcode opTypeStruct
        resultType: nil
        resultId: id
        operands: (memberTypes collect: [:t | t id]) asArray
]

{ #category : 'accessing' }
SpvStructType >> key [ ^ Array with: #struct with: (memberTypes collect: [:t | t id])
]

{ #category : 'accessing' }
SpvStructType >> memberTypes: a [  memberTypes := a
]
