"
I am what PVBlockSimulator answers: the state a PVStackSimulator reached at the end of one bytecode block, frozen, with each part named.

My five parts are what the next block needs. `regOps` is the register operations the block performed, which the emitter turns into SPIR-V instructions. `tempDefs` is the temporary-to-register map as the block left it, and becomes the next block's `initialTempDefs:`. `resultReg` is the register holding the value left on the simulated stack, nil when the block left none; the emitter reads it as the condition of a selection, as the value an arm produces, and as a key into the type map. `nextReg` is the first register no block has defined, and becomes the next block's `startingNextReg:` and, in a selection, the phi register. `stack` is the simulated stack as the block left it, which a loop's exit block resumes from.

I am frozen on purpose: `regOps` is an Array and `stack` a copy, because the loop path reads the preheader's stack after the header and the latch have been simulated. Build me through PVBlockSimulator, never by hand; I answer my parts and nothing else.
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
