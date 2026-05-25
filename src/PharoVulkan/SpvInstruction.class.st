"
One encoded SPIR-V instruction: opcode, optional result type id, optional result id, and operands.
All ids and operands are Integers (32-bit words). Knows how to encode itself into a word stream.
Key methods: opcode:resultType:resultId:operands:, wordCount, encodeInto:.
"
Class {
	#name : 'SpvInstruction',
	#superclass : 'Object',
	#instVars : [
		'opcode',
		'resultType',
		'resultId',
		'operands'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'instance creation' }
SpvInstruction class >> opcode: op operands: ops [
    ^ self opcode: op resultType: nil resultId: nil operands: ops
]

{ #category : 'instance creation' }
SpvInstruction class >> opcode: op resultType: rt resultId: rid operands: ops [
    "Primary factory. Pass nil for resultType or resultId when not applicable."
    ^ self new
        opcode: op;
        resultType: rt;
        resultId: rid;
        operands: ops;
        yourself
]

{ #category : 'encoding' }
SpvInstruction >> encodeInto: aWordStream [
    "Emit this instruction as 32-bit words. First word encodes word count and opcode."
    aWordStream nextPut: ((self wordCount bitShift: 16) bitOr: opcode).
    resultType ifNotNil: [ aWordStream nextPut: resultType ].
    resultId   ifNotNil: [ aWordStream nextPut: resultId ].
    operands do: [ :w | aWordStream nextPut: w ]
]

{ #category : 'accessing' }
SpvInstruction >> opcode [          ^ opcode
]

{ #category : 'accessing' }
SpvInstruction >> opcode: x [       opcode := x
]

{ #category : 'accessing' }
SpvInstruction >> operands [        ^ operands
]

{ #category : 'accessing' }
SpvInstruction >> operands: x [     operands := x
]

{ #category : 'printing' }
SpvInstruction >> printOn: aStream [
    aStream
        nextPutAll: 'SpvInstruction(op=';
        print: opcode;
        nextPut: $)
]

{ #category : 'accessing' }
SpvInstruction >> resultId [        ^ resultId
]

{ #category : 'accessing' }
SpvInstruction >> resultId: x [     resultId := x
]

{ #category : 'accessing' }
SpvInstruction >> resultType [      ^ resultType
]

{ #category : 'accessing' }
SpvInstruction >> resultType: x [   resultType := x
]

{ #category : 'encoding' }
SpvInstruction >> wordCount [
    "Total words: 1 (opcode word) + resultType (if present) + resultId (if present) + operands."
    | count |
    count := 1.
    resultType ifNotNil: [ count := count + 1 ].
    resultId   ifNotNil: [ count := count + 1 ].
    count := count + operands size.
    ^ count
]
