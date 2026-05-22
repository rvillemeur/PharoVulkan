"
A SPIR-V module-scope variable (OpVariable in global scope).
Used for built-in inputs (GlobalInvocationId), storage buffer bindings, etc.
Key methods: id, type, storageClass, instruction.
"
Class {
	#name : 'SpvGlobalVariable',
	#superclass : 'Object',
	#instVars : [
		'id',
		'type',
		'storageClass',
		'initializer'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'instance creation' }
SpvGlobalVariable class >> on: aModule type: aPointerType storageClass: sc [
    ^ self new
        id: aModule newId;
        type: aPointerType;
        storageClass: sc;
        yourself
]

{ #category : 'accessing' }
SpvGlobalVariable >> id [            ^ id
]

{ #category : 'accessing' }
SpvGlobalVariable >> id: x [         id := x
]

{ #category : 'encoding' }
SpvGlobalVariable >> instruction [
    | ops |
    ops := OrderedCollection with: storageClass.
    initializer ifNotNil: [:init | ops add: init].
    ^ SpvInstruction
        opcode: SpvOpcode opVariable
        resultType: type id
        resultId: id
        operands: ops asArray
]

{ #category : 'accessing' }
SpvGlobalVariable >> storageClass [  ^ storageClass
]

{ #category : 'accessing' }
SpvGlobalVariable >> storageClass: s [ storageClass := s
]

{ #category : 'accessing' }
SpvGlobalVariable >> type [          ^ type
]

{ #category : 'accessing' }
SpvGlobalVariable >> type: t [       type := t
]
