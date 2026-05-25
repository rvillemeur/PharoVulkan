"
OpBranch — unconditional branch to a target SpvIRBlock.
"
Class {
	#name : 'SpvIRBranch',
	#superclass : 'SpvIRNode',
	#instVars : [
		'target'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'instance creation' }
SpvIRBranch class >> target: aBlock [
	^ self new target: aBlock; yourself
]

{ #category : 'emitting' }
SpvIRBranch >> emitInto: blk idMap: map module: m [
	blk terminate: (SpvInstruction
		opcode: SpvOpcode opBranch
		resultType: nil resultId: nil operands: (Array with: target id))
]

{ #category : 'testing' }
SpvIRBranch >> hasResult [ ^ false
]

{ #category : 'accessing' }
SpvIRBranch >> target [ ^ target
]

{ #category : 'accessing' }
SpvIRBranch >> target: t [ target := t
]
