"
SPIR-V array type node. Represents OpTypeArray with a fixed element count. Registered in SpvTypeRegistry; emitted as an OpTypeArray instruction with a constant length operand.
"
Class {
	#name : 'SpvArrayType',
	#superclass : 'SpvType',
	#instVars : [
		'elementType',
		'lengthId'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'as yet unclassified' }
SpvArrayType >> instruction [
	^ self shouldBeImplemented
]

{ #category : 'as yet unclassified' }
SpvArrayType >> key [
	^ self shouldBeImplemented
]
