"
One decoded Sista bytecode instruction. Stores the opcode symbol, operands, stack effect (delta), and source PC. Produced by PVBytecodeDecoder; consumed by PVStackSimulator and PVCFGBuilder.
"
Class {
	#name : 'PVBytecodeOp',
	#superclass : 'Object',
	#instVars : [
		'pc',
		'opcode',
		'operands'
	],
	#category : 'PharoVulkan-Compiler-Bytecode',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Bytecode'
}

{ #category : 'instance creation' }
PVBytecodeOp class >> pc: p opcode: op operands: args [
	^ self new pc: p; opcode: op; operands: args; yourself
]

{ #category : 'accessing' }
PVBytecodeOp >> opcode [
^ opcode
]

{ #category : 'accessing' }
PVBytecodeOp >> opcode: aSymbol [
	opcode := aSymbol
]

{ #category : 'accessing' }
PVBytecodeOp >> operands [
^ operands
]

{ #category : 'accessing' }
PVBytecodeOp >> operands: anArray [
	operands := anArray
]

{ #category : 'accessing' }
PVBytecodeOp >> pc [
^ pc
]

{ #category : 'accessing' }
PVBytecodeOp >> pc: anInteger [
	pc := anInteger
]

{ #category : 'printing' }
PVBytecodeOp >> printOn: aStream [
	aStream nextPutAll: 'PVBytecodeOp('.
	aStream print: pc.
	aStream nextPutAll: ' '.
	aStream nextPutAll: opcode.
	aStream nextPutAll: ')'
]
