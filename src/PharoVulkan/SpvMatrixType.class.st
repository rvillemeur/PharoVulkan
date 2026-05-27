Class {
	#name : 'SpvMatrixType',
	#superclass : 'SpvType',
	#instVars : [
		'columnType',
		'columns'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'accessing' }
SpvMatrixType >> columnType [ ^ columnType
]

{ #category : 'accessing' }
SpvMatrixType >> columnType: x [ columnType := x
]

{ #category : 'accessing' }
SpvMatrixType >> columns [ ^ columns
]

{ #category : 'accessing' }
SpvMatrixType >> columns: x [ columns := x
]

{ #category : 'emitting' }
SpvMatrixType >> instruction [
    ^ SpvInstruction
        opcode: SpvOpcode opTypeMatrix
        resultType: nil
        resultId: id
        operands: { columnType id. columns }
]

{ #category : 'accessing' }
SpvMatrixType >> key [ ^ Array with: #matrix with: columnType id with: columns
]
