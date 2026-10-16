"
Wraps a global variable id for use as an IR operand. Not emitted inside a block.
"
Class {
	#name : 'SpvIRGlobalRef',
	#superclass : 'SpvIRNode',
	#instVars : [
		'globalId'
	],
	#category : 'PharoVulkan-SPIRV-IR',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'IR'
}

{ #category : 'instance creation' }
SpvIRGlobalRef class >> id: anInt type: aType [
	^ self new globalId: anInt; type: aType; yourself
]

{ #category : 'emitting' }
SpvIRGlobalRef >> emitInto: blk idMap: map module: m [
]

{ #category : 'accessing' }
SpvIRGlobalRef >> globalId [ ^ globalId
]

{ #category : 'accessing' }
SpvIRGlobalRef >> globalId: n [ globalId := n
]

{ #category : 'accessing' }
SpvIRGlobalRef >> id [ ^ globalId
]
