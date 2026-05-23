"
OpLoad — loads a value from a pointer-typed IR node.
"
Class {
	#name : 'SpvIRLoad',
	#superclass : 'SpvIRNode',
	#instVars : [
		'pointer'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'instance creation' }
SpvIRLoad class >> pointer: aNode type: aType [
	^ self new pointer: aNode; type: aType; yourself
]

{ #category : 'emitting' }
SpvIRLoad >> emitInto: blk idMap: map module: m [
	blk addInstruction: (SpvInstruction
		opcode: SpvOpcode opLoad
		resultType: type id
		resultId: id
		operands: (Array with: (map at: pointer)))
]

{ #category : 'accessing' }
SpvIRLoad >> pointer [ ^ pointer
]

{ #category : 'accessing' }
SpvIRLoad >> pointer: p [ pointer := p
]
