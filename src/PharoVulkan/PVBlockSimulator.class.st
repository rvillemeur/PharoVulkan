"
Simulates a single bytecode block in isolation during SSA construction. Executes PVRegisterOp instructions symbolically, returning a record of register definitions and the stack top. Used by PVSPIRVEmitter.
"
Class {
	#name : 'PVBlockSimulator',
	#superclass : 'Object',
	#instVars : [
		'annotation',
		'selectorTable'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'simulating' }
PVBlockSimulator class >> simulate: aBlock initialTempDefs: defs annotation: ann selectorTable: st [
	^ self new annotation: ann; selectorTable: st; simulateBlock: aBlock initialTempDefs: defs
]

{ #category : 'accessing' }
PVBlockSimulator >> annotation: ann [
	annotation := ann
]

{ #category : 'accessing' }
PVBlockSimulator >> selectorTable: st [
	selectorTable := st
]

{ #category : 'simulating' }
PVBlockSimulator >> simulateBlock: aBlock initialTempDefs: tempDefs [
	| sim term |
	sim := PVStackSimulator new initialize.
	tempDefs keysAndValuesDo: [ :k :v | sim tempDefs at: k put: v ].
	aBlock ops do: [ :op |
		(#(#jump #jumpIf #returnTop #returnSelf) includes: op opcode) ifFalse: [
			sim simulateOp: op ] ].
	"For jumpIf: condition is top of stack before jump"
	term := aBlock terminator.
	(term notNil and: [ term opcode = #returnTop ]) ifTrue: [
		sim simulateOp: term ].
	^ { sim regOps asArray.
	    sim tempDefs.
	    (sim stack isEmpty ifFalse: [ sim stack last ]).
	    sim stack copy }
]

{ #category : 'simulating' }
PVBlockSimulator >> simulateBlock: aBlock initialTempDefs: tempDefs startingNextReg: startReg [
	| sim |
	sim := PVStackSimulator new initialize.
	sim nextReg: startReg.
	tempDefs keysAndValuesDo: [ :k :v | sim tempDefs at: k put: v ].
	aBlock ops do: [ :op |
		(#(#jump #jumpIf #returnTop #returnSelf) includes: op opcode) ifFalse: [
			sim simulateOp: op ] ].
	^ { sim regOps asArray.
	    sim tempDefs.
	    (sim stack isEmpty ifFalse: [ sim stack last ]).
	    sim nextReg.
	    sim stack copy }
]

{ #category : 'simulating' }
PVBlockSimulator >> simulateBlock: aBlock initialTempDefs: tempDefs startingNextReg: startReg initialStack: stackList [
	"Like simulateBlock:initialTempDefs:startingNextReg: but pre-seeds the stack.
	 Needed for exit blocks that inherit stack residue from the loop preheader
	 (e.g. to:do: leaves the start value on stack via storeTemp, exit block pops it)."
	| sim |
	sim := PVStackSimulator new initialize.
	sim nextReg: startReg.
	tempDefs keysAndValuesDo: [ :k :v | sim tempDefs at: k put: v ].
	stackList do: [:r | sim stack addLast: r].
	aBlock ops do: [ :op |
		(#(#jump #jumpIf #returnTop #returnSelf) includes: op opcode) ifFalse: [
			sim simulateOp: op ] ].
	^ { sim regOps asArray.
	    sim tempDefs.
	    (sim stack isEmpty ifFalse: [ sim stack last ]).
	    sim nextReg.
	    sim stack copy }
]
