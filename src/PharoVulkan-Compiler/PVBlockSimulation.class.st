"
I am what PVBlockSimulator answers: the state a PVStackSimulator reached at the end of one bytecode block, frozen, with each part named.
My five parts are what the next block needs. `regOps` is the register operations the block performed, which the emitter turns into SPIR-V instructions. `tempDefs` is the temporary-to-register map as the block left it, and becomes the next block's `initialTempDefs:`. `resultReg` is the register holding the value left on the simulated stack, nil when the block left none; the emitter reads it as the condition of a selection, as the value an arm produces, and as a key into the type map. `nextReg` is the first register no block has defined, and becomes the next block's `startingNextReg:` and, in a selection, the phi register. `stack` is the simulated stack as the block left it, which a loop's exit block resumes from.
I also answer what is a pure function of those parts, which the emitter used to compute for itself: `loopPhisWithLatch:` the phis a loop header joins, `nestedOuterPhisWithInnerMerge:innerPhis:` the outer phis of a nested loop, `mergeStackWithPhiReg:` the stack a selection's merge block resumes from, and, on my class side, `typesOver:annotation:selectorTable:` the type map inferred over a sequence of simulations.
I am frozen on purpose: `regOps` is an Array and `stack` a copy, because the loop path reads the preheader's stack after the header and the latch have been simulated. Build me through PVBlockSimulator, never by hand.
"
Class {
	#name : 'PVBlockSimulation',
	#superclass : 'Object',
	#instVars : [
		'regOps',
		'tempDefs',
		'resultReg',
		'nextReg',
		'stack'
	],
	#category : 'PharoVulkan-Compiler-Registers',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Registers'
}

{ #category : 'instance creation' }
PVBlockSimulation class >> ofSimulator: aStackSimulator [
	"Freeze what the simulator reached: the ops as an Array and the stack as a copy, since a
	 later block may run before an earlier simulation's stack is read."

	^ self new setFromSimulator: aStackSimulator
]

{ #category : 'inferring' }
PVBlockSimulation class >> typesOver: sims annotation: ann selectorTable: st [
	"One PVTypeInferencer accumulates into a single typeMap across the simulations, so a
	 register defined in one block keeps its type in the next. Answer the inferencer as
	 well, because a caller may have to seed a phi type and then infer one block more."

	| inferencer typeMap |
	inferencer := PVTypeInferencer new initialize annotation: ann.
	typeMap := nil.
	sims do: [ :each | typeMap := inferencer inferAll: each regOps selectorTable: st ].
	^ { inferencer. typeMap }
]

{ #category : 'inspector' }
PVBlockSimulation >> inspectorParts: aBuilder [
	"The five parts PVSPIRVEmitter reads, each asked of its own accessor, so the tab cannot
	 name a part the emitter does not get. The ops and the stack print their size, because the
	 register list of a real kernel block does not fit a cell."

	<inspectorPresentationOrder: 10 title: 'Parts'>
	^ PVFactRow
		  tableOf: {
				  (PVFactRow name: 'regOps' value: self regOps size printString , ' ops').
				  (PVFactRow name: 'tempDefs' value: self tempDefs size printString , ' temps').
				  (PVFactRow name: 'resultReg' value: self resultReg).
				  (PVFactRow name: 'nextReg' value: self nextReg).
				  (PVFactRow name: 'stack' value: self stack size printString , ' deep') }
		  nameColumn: 'Part'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'phis' }
PVBlockSimulation >> loopPhisWithLatch: latchSim [
	"A loop-carried variable is one the latch leaves in a different register than this
	 simulation, the preheader's, did; that pair is exactly what the header phi joins. A
	 variable both blocks leave in the same register is loop-invariant and needs no phi."

	| indices initRegs latchRegs |
	indices := OrderedCollection new.
	initRegs := Dictionary new.
	latchRegs := Dictionary new.
	self tempDefs keysAndValuesDo: [ :k :preReg |
		| latchReg |
		latchReg := latchSim tempDefs at: k ifAbsent: [ preReg ].
		latchReg = preReg ifFalse: [
			indices add: k.
			initRegs at: k put: preReg.
			latchRegs at: k put: latchReg ] ].
	^ Dictionary newFrom: {
		  #indices -> indices.
		  #init -> initRegs.
		  #latch -> latchRegs }
]

{ #category : 'phis' }
PVBlockSimulation >> mergeStackWithPhiReg: phiReg [
	"What the merge block consumes is the value the two arms produce, so the phi register
	 sits on top of its stack. Below it is whatever this simulation, the condition block's,
	 pushed before the selection, less the condition itself: the simulator never executes
	 the jumpIf that pops it."

	| mergeStack |
	mergeStack := self stack asOrderedCollection.
	mergeStack isEmpty ifFalse: [ mergeStack removeLast ].
	mergeStack addLast: phiReg.
	^ mergeStack
]

{ #category : 'phis' }
PVBlockSimulation >> nestedOuterPhisWithInnerMerge: innerMergeSim innerPhis: innerPhis [
	"A variable the inner loop carries is carried by the outer loop as well, even though the
	 inner merge block leaves it in the register the outer body was entered with: inside the
	 inner loop that register points at the inner phi, so the outer phi's latch operand
	 resolves to it. Comparing registers alone misses that variable, and in a tiled kernel
	 it is the accumulator. A variable the inner loop declares, on the other hand, does not
	 exist before the outer loop and is carried by the inner loop only."

	| phis |
	phis := self loopPhisWithLatch: innerMergeSim.
	(innerPhis at: #indices) do: [ :k |
		(((phis at: #indices) includes: k) not and: [
			 self tempDefs includesKey: k ]) ifTrue: [
			(phis at: #indices) add: k.
			(phis at: #init) at: k put: (self tempDefs at: k).
			(phis at: #latch)
				at: k
				put: (innerMergeSim tempDefs at: k ifAbsent: [
						 self tempDefs at: k ]) ] ].
	^ phis
]

{ #category : 'accessing' }
PVBlockSimulation >> nextReg [
	^ nextReg
]

{ #category : 'accessing' }
PVBlockSimulation >> regOps [
	^ regOps
]

{ #category : 'accessing' }
PVBlockSimulation >> resultReg [
	"The register holding the value the block left on the simulated stack, nil when it left none."

	^ resultReg
]

{ #category : 'private' }
PVBlockSimulation >> setFromSimulator: aStackSimulator [
	"The copies are taken here rather than in the accessors, so what the simulator does next
	 cannot change a simulation already answered."

	regOps := aStackSimulator regOps asArray.
	tempDefs := aStackSimulator tempDefs.
	resultReg := aStackSimulator stack isEmpty
		             ifFalse: [ aStackSimulator stack last ].
	nextReg := aStackSimulator nextReg.
	stack := aStackSimulator stack copy
]

{ #category : 'accessing' }
PVBlockSimulation >> stack [
	^ stack
]

{ #category : 'accessing' }
PVBlockSimulation >> tempDefs [
	^ tempDefs
]
