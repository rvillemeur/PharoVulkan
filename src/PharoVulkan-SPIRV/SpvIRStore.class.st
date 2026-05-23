"
OpStore — stores a value to a pointer. No result id.
"
Class {
	#name : 'SpvIRStore',
	#superclass : 'SpvIRNode',
	#instVars : [
		'pointer',
		'value'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'instance creation' }
SpvIRStore class >> pointer: pNode value: vNode [
	^ self new pointer: pNode; value: vNode; yourself
]

{ #category : 'emitting' }
SpvIRStore >> emitInto: blk idMap: map module: m [
	blk addInstruction: (SpvInstruction
		opcode: SpvOpcode opStore
		resultType: nil
		resultId: nil
		operands: (Array with: (map at: pointer) with: (map at: value)))
]

{ #category : 'testing' }
SpvIRStore >> hasResult [ ^ false
]

{ #category : 'accessing' }
SpvIRStore >> pointer [ ^ pointer
]

{ #category : 'accessing' }
SpvIRStore >> pointer: p [ pointer := p
]

{ #category : 'accessing' }
SpvIRStore >> value [ ^ value
]

{ #category : 'accessing' }
SpvIRStore >> value: v [ value := v
]
