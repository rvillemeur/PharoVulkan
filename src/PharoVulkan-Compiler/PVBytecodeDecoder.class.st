"
Decodes Sista bytecode from a CompiledMethod into a flat list of PVBytecodeOp records, each with opcode, operands, stack effect, and PC. Stage 2 of the compiler pipeline.
"
Class {
	#name : 'PVBytecodeDecoder',
	#superclass : 'InstructionClient',
	#instVars : [
		'ops',
		'currentPc',
		'startPc'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Pipeline'
}

{ #category : 'decoding' }
PVBytecodeDecoder class >> decode: aCompiledMethod [
	| client stream |
	client := self new.
	stream := InstructionStream on: aCompiledMethod.
	client currentPc: stream pc.
	[ stream atEnd ] whileFalse: [
		stream interpretNextInstructionFor: client ].
	^ client ops asArray
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> blockReturnConstant: aValue [ ops add: (PVBytecodeOp pc: startPc opcode: #returnConst operands: { aValue } stackEffect: 0)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> blockReturnTop [ ops add: (PVBytecodeOp pc: startPc opcode: #returnTop operands: #() stackEffect: -1)
]

{ #category : 'accessing' }
PVBytecodeDecoder >> currentPc: anInteger [
	currentPc := anInteger
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> doDup [ ops add: (PVBytecodeOp pc: startPc opcode: #dup operands: #() stackEffect: 1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> doPop [
	ops add: (PVBytecodeOp pc: startPc opcode: #pop operands: #() stackEffect: -1)
]

{ #category : 'initialization' }
PVBytecodeDecoder >> initialize [
	super initialize .
	ops := OrderedCollection new.
	currentPc := 0.
	startPc := 0
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> jump: offset [
	ops add: (PVBytecodeOp pc: startPc opcode: #jump
		operands: { currentPc + offset }
		stackEffect: 0)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> jump: offset if: cond [
	ops add: (PVBytecodeOp pc: startPc opcode: #jumpIf
		operands: { currentPc + offset. cond }
		stackEffect: -1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> methodReturnConstant: aValue [ ops add: (PVBytecodeOp pc: startPc opcode: #returnConst operands: { aValue } stackEffect: 0)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> methodReturnReceiver [
	ops add: (PVBytecodeOp pc: startPc opcode: #returnSelf operands: #() stackEffect: 0)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> methodReturnTop [
	ops add: (PVBytecodeOp pc: startPc opcode: #returnTop operands: #() stackEffect: -1)
]

{ #category : 'accessing' }
PVBytecodeDecoder >> ops [
^ ops
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> pc: n [
	startPc := currentPc.
	currentPc := n
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> popIntoReceiverVariable: anIndex [ ops add: (PVBytecodeOp pc: startPc opcode: #popInstVar operands: { anIndex } stackEffect: -1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> popIntoTemporaryVariable: anIndex [
	ops add: (PVBytecodeOp pc: startPc opcode: #popTemp operands: { anIndex } stackEffect: -1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> pushConstant: aValue [
	ops add: (PVBytecodeOp pc: startPc opcode: #pushConst operands: { aValue } stackEffect: 1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> pushReceiver [
	ops add: (PVBytecodeOp pc: startPc opcode: #pushSelf operands: #() stackEffect: 1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> pushReceiverVariable: anIndex [ ops add: (PVBytecodeOp pc: startPc opcode: #pushInstVar operands: { anIndex } stackEffect: 1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> pushTemporaryVariable: anIndex [
	ops add: (PVBytecodeOp pc: startPc opcode: #pushTemp operands: { anIndex } stackEffect: 1)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> send: selector super: isSuper numArgs: numArgs [
	ops add: (PVBytecodeOp pc: startPc opcode: #send
		operands: { selector. isSuper. numArgs }
		stackEffect: 1 - numArgs)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> storeIntoReceiverVariable: anIndex [ ops add: (PVBytecodeOp pc: startPc opcode: #storeInstVar operands: { anIndex } stackEffect: 0)
]

{ #category : 'instruction client' }
PVBytecodeDecoder >> storeIntoTemporaryVariable: anIndex [
	ops add: (PVBytecodeOp pc: startPc opcode: #storeTemp operands: { anIndex } stackEffect: 0)
]
