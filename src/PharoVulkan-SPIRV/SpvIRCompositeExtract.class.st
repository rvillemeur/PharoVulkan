"
OpCompositeExtract — extracts a component. indices are literal Integers.
"
Class {
	#name : 'SpvIRCompositeExtract',
	#superclass : 'SpvIRNode',
	#instVars : [
		'composite',
		'indices'
	],
	#category : 'PharoVulkan-SPIRV-IR',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'IR'
}

{ #category : 'instance creation' }
SpvIRCompositeExtract class >> composite: cNode indices: idxInts type: aType [
	^ self new composite: cNode; indices: idxInts; type: aType; yourself
]

{ #category : 'accessing' }
SpvIRCompositeExtract >> composite [ ^ composite
]

{ #category : 'accessing' }
SpvIRCompositeExtract >> composite: c [ composite := c
]

{ #category : 'emitting' }
SpvIRCompositeExtract >> emitInto: blk idMap: map module: m [
	| ops |
	ops := OrderedCollection with: (map at: composite).
	indices do: [:i | ops add: i].
	blk addInstruction: (SpvInstruction
		opcode: SpvOpcode opCompositeExtract
		resultType: type id
		resultId: id
		operands: ops asArray)
]

{ #category : 'accessing' }
SpvIRCompositeExtract >> indices [ ^ indices
]

{ #category : 'accessing' }
SpvIRCompositeExtract >> indices: i [ indices := i
]
