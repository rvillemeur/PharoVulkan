"
OpReturn — void function return terminator.
"
Class {
	#name : 'SpvIRReturn',
	#superclass : 'SpvIRNode',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'emitting' }
SpvIRReturn >> emitInto: blk idMap: map module: m [
	blk terminate: (SpvInstruction
		opcode: SpvOpcode opReturn
		resultType: nil resultId: nil operands: #())
]

{ #category : 'testing' }
SpvIRReturn >> hasResult [ ^ false
]
