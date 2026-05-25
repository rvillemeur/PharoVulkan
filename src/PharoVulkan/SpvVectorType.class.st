"
SPIR-V vector type (e.g. vec3f = float32 x 3).
"
Class {
	#name : 'SpvVectorType',
	#superclass : 'SpvType',
	#instVars : [
		'componentType',
		'count'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'accessing' }
SpvVectorType >> componentType [   ^ componentType
]

{ #category : 'accessing' }
SpvVectorType >> componentType: t [ componentType := t
]

{ #category : 'accessing' }
SpvVectorType >> count [           ^ count
]

{ #category : 'accessing' }
SpvVectorType >> count: n [        count := n
]

{ #category : 'encoding' }
SpvVectorType >> instruction [
    ^ SpvInstruction
        opcode: SpvOpcode opTypeVector
        resultType: nil
        resultId: id
        operands: { componentType id. count }
]

{ #category : 'abstract' }
SpvVectorType >> key [ ^ Array with: #vector with: componentType id with: count
]
