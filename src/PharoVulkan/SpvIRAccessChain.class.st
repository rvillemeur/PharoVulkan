"
OpAccessChain — computes element pointer from base + index nodes.
"
Class {
	#name : 'SpvIRAccessChain',
	#superclass : 'SpvIRNode',
	#instVars : [
		'base',
		'indices'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'instance creation' }
SpvIRAccessChain class >> base: baseNode indices: idxNodes type: aType [
	^ self new base: baseNode; indices: idxNodes; type: aType; yourself
]

{ #category : 'accessing' }
SpvIRAccessChain >> base [ ^ base
]

{ #category : 'accessing' }
SpvIRAccessChain >> base: b [ base := b
]

{ #category : 'emitting' }
SpvIRAccessChain >> emitInto: blk idMap: map module: m [
	| ops |
	ops := OrderedCollection with: (map at: base).
	indices do: [:idx | ops add: (map at: idx)].
	blk addInstruction: (SpvInstruction
		opcode: SpvOpcode opAccessChain
		resultType: type id
		resultId: id
		operands: ops asArray)
]

{ #category : 'accessing' }
SpvIRAccessChain >> indices [ ^ indices
]

{ #category : 'accessing' }
SpvIRAccessChain >> indices: i [ indices := i
]
