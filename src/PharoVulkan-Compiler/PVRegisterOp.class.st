"
One instruction in the register IR. Stores an opcode symbol, input register ids, output register id, and optional literal. Produced by PVStackSimulator from decoded bytecodes.
"
Class {
	#name : 'PVRegisterOp',
	#superclass : 'Object',
	#instVars : [
		'pc',
		'opcode',
		'result',
		'inputs',
		'literal'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'instance creation' }
PVRegisterOp class >> pc: p opcode: op result: r inputs: ins literal: lit [
	^ self new pc: p; opcode: op; result: r; inputs: ins; literal: lit; yourself
]

{ #category : 'accessing' }
PVRegisterOp >> inputs [
^ inputs
]

{ #category : 'accessing' }
PVRegisterOp >> inputs: anArray [
	inputs := anArray
]

{ #category : 'accessing' }
PVRegisterOp >> literal [
^ literal
]

{ #category : 'accessing' }
PVRegisterOp >> literal: anObject [
	literal := anObject
]

{ #category : 'accessing' }
PVRegisterOp >> opcode [
^ opcode
]

{ #category : 'accessing' }
PVRegisterOp >> opcode: aSymbol [
	opcode := aSymbol
]

{ #category : 'accessing' }
PVRegisterOp >> pc [
^ pc
]

{ #category : 'accessing' }
PVRegisterOp >> pc: anInteger [
	pc := anInteger
]

{ #category : 'printing' }
PVRegisterOp >> printOn: aStream [
	aStream nextPutAll: 'PVRegisterOp(r'.
	result ifNotNil: [ aStream print: result ].
	aStream nextPutAll: ' := '.
	aStream nextPutAll: opcode.
	aStream nextPutAll: ')'
]

{ #category : 'accessing' }
PVRegisterOp >> result [
^ result
]

{ #category : 'accessing' }
PVRegisterOp >> result: anInteger [
	result := anInteger
]
