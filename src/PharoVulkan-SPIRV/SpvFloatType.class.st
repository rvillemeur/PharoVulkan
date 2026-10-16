"
SPIR-V floating-point type. width is 16/32/64.
"
Class {
	#name : 'SpvFloatType',
	#superclass : 'SpvType',
	#instVars : [
		'width'
	],
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'encoding' }
SpvFloatType >> instruction [
    ^ SpvInstruction
        opcode: SpvOpcode opTypeFloat
        resultType: nil
        resultId: id
        operands: { width }
]

{ #category : 'abstract' }
SpvFloatType >> key [ ^ Array with: #float with: width
]

{ #category : 'accessing' }
SpvFloatType >> width [          ^ width
]

{ #category : 'accessing' }
SpvFloatType >> width: w [       width := w
]
