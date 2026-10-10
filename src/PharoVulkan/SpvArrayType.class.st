"
SPIR-V fixed-size array type, the sized neighbour of SpvRuntimeArrayType. A shared memory tile needs one of these, because a Workgroup variable has to state how much memory it occupies.

Its length is an id of a constant rather than a literal, so the module declares the length like any other constant and the serialiser has to emit that constant before this type. Key methods: elementType, length, instruction.
"
Class {
	#name : 'SpvArrayType',
	#superclass : 'SpvType',
	#instVars : [
		'elementType',
		'length'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'accessing' }
SpvArrayType >> elementType [
	^ elementType
]

{ #category : 'accessing' }
SpvArrayType >> elementType: aType [
	elementType := aType
]

{ #category : 'encoding' }
SpvArrayType >> instruction [
	"The length operand is the id of an unsigned constant holding it, which the module's
	 constant pool declares. Asking the pool here keeps the two from disagreeing, and the
	 pool deduplicates, so a second array of the same length reuses the same constant."

	^ SpvInstruction
		  opcode: SpvOpcode opTypeArray
		  resultType: nil
		  resultId: id
		  operands: {
				  elementType id.
				  (module constantPool constantUInt32: length) }
]

{ #category : 'abstract' }
SpvArrayType >> key [
	^ Array with: #array with: elementType id with: length
]

{ #category : 'accessing' }
SpvArrayType >> length [
	^ length
]

{ #category : 'accessing' }
SpvArrayType >> length: anInteger [
	length := anInteger
]
