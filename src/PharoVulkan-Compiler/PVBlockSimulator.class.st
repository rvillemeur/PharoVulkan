"
Simulates a single bytecode block in isolation during SSA construction. Executes PVRegisterOp instructions symbolically, returning a record of register definitions and the stack top. Used by PVSPIRVEmitter.
"
Class {
	#name : 'PVBlockSimulator',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler-Registers',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Registers'
}

{ #category : 'simulating' }
PVBlockSimulator >> simulateBlock: aBlock initialTempDefs: tempDefs startingNextReg: startReg [
	| sim |
	sim := PVStackSimulator new initialize.
	sim nextReg: startReg.
	tempDefs keysAndValuesDo: [ :k :v | sim tempDefs at: k put: v ].
	aBlock ops do: [ :op |
		(#(#jump #jumpIf #returnTop #returnSelf) includes: op opcode) ifFalse: [
			sim simulateOp: op ] ].
	^ PVBlockSimulation ofSimulator: sim
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
	stackList do: [ :r | sim stack addLast: r ].
	aBlock ops do: [ :op |
		(#(#jump #jumpIf #returnTop #returnSelf) includes: op opcode) ifFalse: [
			sim simulateOp: op ] ].
	^ PVBlockSimulation ofSimulator: sim
]
