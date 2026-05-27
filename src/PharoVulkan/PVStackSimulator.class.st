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
		'regOps'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan',
	#tag : 'Compiler-Pipeline'
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
super initialize .
	stack := OrderedCollection new.
	nextReg := 0.
	tempDefs := Dictionary new.
	regOps := OrderedCollection new
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
| r ins |
op opcode = #dup ifTrue: [
    stack addLast: stack last.
    ^ self ].
op opcode = #pushTemp ifTrue: [
    r := tempDefs at: (op operands first) ifAbsent: [ self newReg ].
    stack addLast: r.
    ^ self ].
op opcode = #popTemp ifTrue: [
    r := stack removeLast.
    tempDefs at: (op operands first) put: r.
    regOps add: (PVRegisterOp pc: op pc opcode: #move result: r inputs: { r } literal: nil).
    ^ self ].
op opcode = #storeTemp ifTrue: [
    r := stack last.
    tempDefs at: (op operands first) put: r.
    ^ self ].
op opcode = #pushInstVar ifTrue: [
    r := self newReg.
    regOps add: (PVRegisterOp pc: op pc opcode: #instVar result: r inputs: #() literal: op operands first).
    stack addLast: r.
    ^ self ].
op opcode = #storeInstVar ifTrue: [
    r := stack last.
    regOps add: (PVRegisterOp pc: op pc opcode: #storeInstVar result: nil inputs: { r } literal: op operands first).
    ^ self ].
op opcode = #popInstVar ifTrue: [
    r := stack removeLast.
    regOps add: (PVRegisterOp pc: op pc opcode: #storeInstVar result: nil inputs: { r } literal: op operands first).
    ^ self ].
op opcode = #pushConst ifTrue: [
    r := self newReg.
    regOps add: (PVRegisterOp pc: op pc opcode: #const result: r inputs: #() literal: op operands first).
    stack addLast: r.
    ^ self ].
op opcode = #returnConst ifTrue: [
    r := self newReg.
    regOps add: (PVRegisterOp pc: op pc opcode: #const result: r inputs: #() literal: op operands first).
    regOps add: (PVRegisterOp pc: op pc opcode: #return result: nil inputs: { r } literal: nil).
    ^ self ].
op opcode = #pushSelf ifTrue: [
    r := self newReg.
    regOps add: (PVRegisterOp pc: op pc opcode: #self result: r inputs: #() literal: nil).
    stack addLast: r.
    ^ self ].
op opcode = #send ifTrue: [
    | numArgs sel argRegs recvReg |
    sel := op operands first.
    numArgs := op operands third.
    argRegs := (1 to: numArgs) collect: [ :_ | stack removeLast ].
    recvReg := stack removeLast.
    r := self newReg.
    ins := { recvReg } , argRegs reversed asArray.
    regOps add: (PVRegisterOp pc: op pc opcode: #send result: r inputs: ins literal: sel).
    stack addLast: r.
    ^ self ].
op opcode = #pop ifTrue: [
    stack removeLast.
    ^ self ].
op opcode = #returnTop ifTrue: [
    r := stack last.
    regOps add: (PVRegisterOp pc: op pc opcode: #return result: nil inputs: { r } literal: nil).
    ^ self ].
op opcode = #returnSelf ifTrue: [
    regOps add: (PVRegisterOp pc: op pc opcode: #returnSelf result: nil inputs: #() literal: nil).
    ^ self ]
]

{ #category : 'accessing' }
PVStackSimulator >> stack [
^ stack
]

{ #category : 'accessing' }
PVStackSimulator >> tempDefs [
^ tempDefs
]
