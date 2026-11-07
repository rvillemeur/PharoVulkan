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
		'storageClass'
	],
	#category : 'PharoVulkan-SPIRV-Builder',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Builder'
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
	"The operand list is just the storage class: a global variable of this builder never has an
	 initializer, so nothing can extend it."

	^ SpvInstruction
		  opcode: SpvOpcode opVariable
		  resultType: type id
		  resultId: id
		  operands: { storageClass }
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
