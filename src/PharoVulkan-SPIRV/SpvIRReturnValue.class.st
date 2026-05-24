"
OpReturnValue — returns a value from a function.
"
Class {
	#name : 'SpvIRReturnValue',
	#superclass : 'SpvIRNode',
	#instVars : [
		'value'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'instance creation' }
SpvIRReturnValue class >> value: vNode [
	^ self new value: vNode; yourself
]

{ #category : 'emitting' }
SpvIRReturnValue >> emitInto: blk idMap: map module: m [
	blk terminate: (SpvInstruction
		opcode: SpvOpcode opReturnValue
		resultType: nil resultId: nil operands: (Array with: (map at: value)))
]

{ #category : 'testing' }
SpvIRReturnValue >> hasResult [ ^ false
]

{ #category : 'evaluating' }
SpvIRReturnValue >> value [ ^ value
]

{ #category : 'accessing' }
SpvIRReturnValue >> value: v [ value := v
]
