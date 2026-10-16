"
OpReturn — void function return terminator.
"
Class {
	#name : 'SpvIRReturn',
	#superclass : 'SpvIRNode',
	#category : 'PharoVulkan-SPIRV-IR',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'IR'
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
