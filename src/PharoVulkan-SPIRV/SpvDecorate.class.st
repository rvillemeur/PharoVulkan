"
A decoration of one id: OpDecorate target, decoration, then the decoration's literals. Built by SpvModule >> addDecoration:decoration:literals:. Key methods: target:decoration:literals: (class-side), instruction.
"
Class {
	#name : 'SpvDecorate',
	#superclass : 'SpvAnnotation',
	#category : 'PharoVulkan-SPIRV-Builder',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Builder'
}

{ #category : 'emitting' }
SpvDecorate >> opcode [
	^ SpvOpcode opDecorate
]

{ #category : 'emitting' }
SpvDecorate >> operands [
	^ {
		  target.
		  decoration } , literals
]
