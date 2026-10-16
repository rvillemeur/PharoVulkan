"
Simulates the Sista stack machine symbolically to convert stack-based bytecode ops into register IR (PVRegisterOp). Assigns virtual register ids to each stack slot. Stage 3 of the pipeline.
"
Class {
	#name : 'PVStackSimulator',
	#superclass : 'Object',
	#instVars : [
		'stack',
		'nextReg',
		'tempDefs',
		'regOps',
		'handlers'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Pipeline'
}

{ #category : 'simulating' }
PVStackSimulator class >> simulate: aBytecodeOpArray [
	^ self new simulate: aBytecodeOpArray
]

{ #category : 'simulating' }
PVStackSimulator class >> simulate: aBytecodeOpArray paramCount: n [
^ self new simulate: aBytecodeOpArray paramCount: n
]

{ #category : 'initialization' }
PVStackSimulator >> initialize [
super initialize.
stack := OrderedCollection new.
nextReg := 0.
tempDefs := Dictionary new.
regOps := OrderedCollection new.
self initializeHandlers
]

{ #category : 'initialization' }
PVStackSimulator >> initializeHandlers [
handlers := Dictionary new.
handlers at: #dup put: [:op | stack addLast: stack last].
handlers at: #pushTemp put: [:op | | r | r := tempDefs at: op operands first ifAbsent: [self newReg]. stack addLast: r].
handlers at: #popTemp put: [:op | | r | r := stack removeLast. tempDefs at: op operands first put: r. regOps add: (PVRegisterOp pc: op pc opcode: #move result: r inputs: {r} literal: nil)].
handlers at: #storeTemp put: [:op | tempDefs at: op operands first put: stack last].
handlers at: #pushInstVar put: [:op | | r | r := self newReg. regOps add: (PVRegisterOp pc: op pc opcode: #instVar result: r inputs: #() literal: op operands first). stack addLast: r].
handlers at: #storeInstVar put: [:op | regOps add: (PVRegisterOp pc: op pc opcode: #storeInstVar result: nil inputs: {stack last} literal: op operands first)].
handlers at: #popInstVar put: [:op | | r | r := stack removeLast. regOps add: (PVRegisterOp pc: op pc opcode: #storeInstVar result: nil inputs: {r} literal: op operands first)].
handlers at: #pushConst put: [:op | | r | r := self newReg. regOps add: (PVRegisterOp pc: op pc opcode: #const result: r inputs: #() literal: op operands first). stack addLast: r].
handlers at: #returnConst put: [:op | | r | r := self newReg. regOps add: (PVRegisterOp pc: op pc opcode: #const result: r inputs: #() literal: op operands first). regOps add: (PVRegisterOp pc: op pc opcode: #return result: nil inputs: {r} literal: nil)].
handlers at: #pushSelf put: [:op | | r | r := self newReg. regOps add: (PVRegisterOp pc: op pc opcode: #self result: r inputs: #() literal: nil). stack addLast: r].
handlers at: #send put: [:op | | numArgs sel argRegs recvReg r ins | sel := op operands first. numArgs := op operands third. argRegs := (1 to: numArgs) collect: [:_ | stack removeLast]. recvReg := stack removeLast. r := self newReg. ins := {recvReg} , argRegs reversed asArray. regOps add: (PVRegisterOp pc: op pc opcode: #send result: r inputs: ins literal: sel). stack addLast: r].
handlers at: #pop put: [:op | stack removeLast].
handlers at: #returnTop put: [:op | regOps add: (PVRegisterOp pc: op pc opcode: #return result: nil inputs: {stack last} literal: nil)].
handlers at: #returnSelf put: [:op | regOps add: (PVRegisterOp pc: op pc opcode: #returnSelf result: nil inputs: #() literal: nil)]
]

{ #category : 'private' }
PVStackSimulator >> newReg [
	nextReg := nextReg + 1.
	^ nextReg
]

{ #category : 'accessing' }
PVStackSimulator >> nextReg [
^ nextReg
]

{ #category : 'accessing' }
PVStackSimulator >> nextReg: n [
	nextReg := n
]

{ #category : 'accessing' }
PVStackSimulator >> regOps [
^ regOps
]

{ #category : 'simulating' }
PVStackSimulator >> simulate: aBytecodeOpArray [
	aBytecodeOpArray do: [ :op | self simulateOp: op ].
	^ regOps asArray
]

{ #category : 'simulating' }
PVStackSimulator >> simulate: aBytecodeOpArray paramCount: n [
0 to: n - 1 do: [ :i | tempDefs at: i put: i + 1 ].
nextReg := n.
aBytecodeOpArray do: [ :op | self simulateOp: op ].
^ regOps asArray
]

{ #category : 'simulating' }
PVStackSimulator >> simulateOp: op [
(handlers at: op opcode ifAbsent: [nil]) ifNotNil: [:blk | blk value: op]
]

{ #category : 'accessing' }
PVStackSimulator >> stack [
^ stack
]

{ #category : 'accessing' }
PVStackSimulator >> tempDefs [
^ tempDefs
]
