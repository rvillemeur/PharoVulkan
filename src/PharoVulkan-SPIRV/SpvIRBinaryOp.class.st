"
Binary op IR node (OpFAdd, OpSDiv, etc.). opcode is a raw Integer from SpvOpcode.
"
Class {
	#name : 'SpvIRBinaryOp',
	#superclass : 'SpvIRNode',
	#instVars : [
		'opcode',
		'left',
		'right'
	],
	#category : 'PharoVulkan-SPIRV-IR',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'IR'
}

{ #category : 'instance creation' }
SpvIRBinaryOp class >> opcode: op left: lNode right: rNode type: aType [
	^ self new opcode: op; left: lNode; right: rNode; type: aType; yourself
]

{ #category : 'emitting' }
SpvIRBinaryOp >> emitInto: blk idMap: map module: m [
	blk addInstruction: (SpvInstruction
		opcode: opcode
		resultType: type id
		resultId: id
		operands: (Array with: (map at: left) with: (map at: right)))
]

{ #category : 'accessing' }
SpvIRBinaryOp >> left [ ^ left
]

{ #category : 'accessing' }
SpvIRBinaryOp >> left: l [ left := l
]

{ #category : 'accessing' }
SpvIRBinaryOp >> opcode [ ^ opcode
]

{ #category : 'accessing' }
SpvIRBinaryOp >> opcode: op [ opcode := op
]

{ #category : 'accessing' }
SpvIRBinaryOp >> right [ ^ right
]

{ #category : 'accessing' }
SpvIRBinaryOp >> right: r [ right := r
]
