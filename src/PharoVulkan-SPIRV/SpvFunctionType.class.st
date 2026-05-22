"
SPIR-V function type. returnType and paramTypes are SpvType objects.
"
Class {
	#name : 'SpvFunctionType',
	#superclass : 'SpvType',
	#instVars : [
		'returnType',
		'paramTypes'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'encoding' }
SpvFunctionType >> instruction [
    | ops |
    ops := OrderedCollection with: returnType id.
    paramTypes do: [:t | ops add: t id].
    ^ SpvInstruction
        opcode: SpvOpcode opTypeFunction
        resultType: nil
        resultId: id
        operands: ops asArray
]

{ #category : 'accessing' }
SpvFunctionType >> key [
    ^ Array with: #function with: returnType id with: (paramTypes collect: [:t | t id])
]

{ #category : 'accessing' }
SpvFunctionType >> paramTypes [      ^ paramTypes
]

{ #category : 'accessing' }
SpvFunctionType >> paramTypes: a [   paramTypes := a
]

{ #category : 'accessing' }
SpvFunctionType >> returnType [      ^ returnType
]

{ #category : 'accessing' }
SpvFunctionType >> returnType: t [   returnType := t
]
