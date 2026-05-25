"
SPIR-V integer type. width is 8/16/32/64. signed is true or false.
"
Class {
	#name : 'SpvIntType',
	#superclass : 'SpvType',
	#instVars : [
		'width',
		'signed'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'encoding' }
SpvIntType >> instruction [
    ^ SpvInstruction
        opcode: SpvOpcode opTypeInt
        resultType: nil
        resultId: id
        operands: { width. (signed ifTrue: [1] ifFalse: [0]) }
]

{ #category : 'abstract' }
SpvIntType >> key [ ^ Array with: #int with: width with: signed
]

{ #category : 'accessing' }
SpvIntType >> signed [         ^ signed
]

{ #category : 'accessing' }
SpvIntType >> signed: s [      signed := s
]

{ #category : 'accessing' }
SpvIntType >> width [          ^ width
]

{ #category : 'accessing' }
SpvIntType >> width: w [       width := w
]
