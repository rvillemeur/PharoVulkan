"
Emits a SPIR-V module from the typed SSA IR. Handles straight-line code, ifTrue:ifFalse: (compileSelection:), and whileTrue: (compileLoop:). Stage 8 of the compiler pipeline. Entry point: emitModule:.
"
Class {
	#name : 'PVSPIRVEmitter',
	#superclass : 'SpvModuleEmitter',
	#instVars : [
		'annotation',
		'regMap',
		'outputVarIds',
		'isVoidMain'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan',
	#tag : 'Compiler-Pipeline'
}

{ #category : 'constants' }
PVSPIRVEmitter class >> bufferMemberIndex [
	"A kernel buffer struct holds exactly one member: the runtime array."
	^ 0
]

{ #category : 'constants' }
PVSPIRVEmitter class >> bufferMemberOffset [
	^ 0
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileComputeKernel: regOps annotation: ann typeMap: typeMap selectorTable: st [
	"A straight-line compute kernel: one basic block between the interface prologue and
	 OpReturn. Kernels holding control flow go through compileComputeKernelLoop: or
	 compileComputeKernelSelection:."

	| em mod spvFunc blk interfaces |
	em := self new.
	em annotation: ann.
	mod := em module.
	mod addCapability: 1.
	mod setAddressingModel: 0 memoryModel: 1.
	interfaces := em emitComputeInterfaces.
	spvFunc := em newComputeMainFunction.
	blk := spvFunc addBlock.
	regOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: blk ].
	blk isTerminated ifFalse: [ blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()) ].
	^ em finishComputeMain: spvFunc interfaces: interfaces
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileComputeKernelLoop: loopNode annotation: ann selectorTable: st [
	"A compute entry point whose body is one whileTrue:. Unlike the other compile methods
	 this one takes no typeMap: the types have to be inferred over the register numbering
	 the per-block simulations produce, which is not the numbering the whole-method
	 simulation produces. Passing the whole-method map in was what made a compute kernel
	 with a selection raise No mapping for at:put:."

	| em interfaces sims phis |
	em := self new.
	em annotation: ann.
	em module addCapability: 1.
	em module setAddressingModel: 0 memoryModel: 1.
	interfaces := em emitComputeInterfaces.
	sims := self computeLoopSimulations: loopNode annotation: ann selectorTable: st.
	phis := self loopPhisFrom: (sims at: #preheader) latch: (sims at: #latch).
	^ em
		  finishComputeMain: (em emitComputeLoopFrom: sims phis: phis selectorTable: st)
		  interfaces: interfaces
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileComputeKernelSelection: selNode annotation: ann selectorTable: st [
	"A compute entry point whose body is one ifTrue:ifFalse:. Takes no typeMap for the
	 reason given in compileComputeKernelLoop:."

	| em interfaces sims |
	em := self new.
	em annotation: ann.
	em module addCapability: 1.
	em module setAddressingModel: 0 memoryModel: 1.
	interfaces := em emitComputeInterfaces.
	sims := self computeSelectionSimulations: selNode annotation: ann selectorTable: st.
	^ em
		  finishComputeMain: (em emitComputeSelectionFrom: sims selectorTable: st)
		  interfaces: interfaces
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileFragmentShader: regOps annotation: ann typeMap: typeMap selectorTable: st [
    ^ self compileShaderKernel: regOps annotation: ann typeMap: typeMap selectorTable: st
        executionModel: SpvExecutionModel fragment
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileKernel: regOps typeMap: typeMap annotation: ann selectorTable: st name: funcName [
	| em |
	em := self new.
	em annotation: ann.
	em module addCapability: 1.    "Shader"
	em module setAddressingModel: 0 memoryModel: 1.    "Logical GLSL450"
	em emitKernelFunction: regOps typeMap: typeMap selectorTable: st name: funcName.
	^ em module serialize
]

{ #category : 'compilation' }
PVSPIRVEmitter class >> compileLoop: loopNode annotation: ann typeMap: typeMap selectorTable: st [
	| em mod paramTempDefs preheaderSim headerSim latchSim exitSim phiVarIndices preInitRegs latchResultRegs phiInitSpvIds phiLatchSpvIds phiSpvIds funcType paramTypes retType spvFunc preBlk hdrBlk latchBlk exitBlk condSpvId retSpvId phiType |
	em := self new.
	em annotation: ann.
	mod := em module.
	mod addCapability: 1.
	mod setAddressingModel: 0 memoryModel: 1.
	paramTempDefs := Dictionary new.
	ann params doWithIndex: [ :p :i |
		| pId |
		pId := mod newId.
		em regMap at: i put: pId.
		paramTempDefs at: i - 1 put: i.
		typeMap at: i put: p type ].
	preheaderSim := PVBlockSimulator new simulateBlock: loopNode preheaderBlock initialTempDefs: paramTempDefs startingNextReg: ann params size + 1.
	headerSim := PVBlockSimulator new simulateBlock: loopNode headerBlock initialTempDefs: preheaderSim second startingNextReg: preheaderSim fourth.
	latchSim := PVBlockSimulator new simulateBlock: loopNode bodyBlocks first initialTempDefs: preheaderSim second startingNextReg: headerSim fourth.
	exitSim := PVBlockSimulator new simulateBlock: loopNode exitBlock initialTempDefs: preheaderSim second startingNextReg: latchSim fourth initialStack: (preheaderSim at: 5).
	phiVarIndices := OrderedCollection new.
	preInitRegs := Dictionary new.
	latchResultRegs := Dictionary new.
	preheaderSim second keysAndValuesDo: [ :k :preReg |
		| latchReg |
		latchReg := latchSim second at: k ifAbsent: [ preReg ].
		latchReg ~= preReg ifTrue: [
			phiVarIndices add: k.
			preInitRegs at: k put: preReg.
			latchResultRegs at: k put: latchReg ] ].
	phiVarIndices do: [ :k | typeMap at: (preInitRegs at: k) put: ann params first type ].
	retType := em spvTypeFor: ann params first type.
	paramTypes := ann params collect: [ :p | em spvTypeFor: p type ].
	funcType := mod typeRegistry functionType: retType paramTypes: paramTypes asArray.
	spvFunc := SpvFunction new id: mod newId; returnType: retType; functionType: funcType; module: mod; initialize; yourself.
	ann params doWithIndex: [ :p :i |
		spvFunc parameters add: (SpvInstruction opcode: SpvOpcode opFunctionParameter resultType: (em spvTypeFor: p type) id resultId: (em regMap at: i) operands: #()) ].
	preBlk := spvFunc addBlock.
	hdrBlk := spvFunc addBlock.
	latchBlk := spvFunc addBlock.
	exitBlk := spvFunc addBlock.
	em emitRegOps: preheaderSim first typeMap: typeMap selectorTable: st block: preBlk.
	phiInitSpvIds := Dictionary new.
	phiVarIndices do: [ :k | phiInitSpvIds at: k put: (em spvIdFor: (preInitRegs at: k)) ].
	preBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { hdrBlk id }).
	phiSpvIds := Dictionary new.
	phiVarIndices do: [ :k |
		| phiId |
		phiId := mod newId.
		phiSpvIds at: k put: phiId.
		em regMap at: (preInitRegs at: k) put: phiId ].
	em emitRegOps: headerSim first typeMap: typeMap selectorTable: st block: hdrBlk.
	condSpvId := em spvIdFor: headerSim third.
	hdrBlk addInstruction: (SpvInstruction opcode: SpvOpcode opLoopMerge resultType: nil resultId: nil operands: { exitBlk id. latchBlk id. 0 }).
	hdrBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional resultType: nil resultId: nil operands: { condSpvId. latchBlk id. exitBlk id }).
	em emitRegOps: latchSim first typeMap: typeMap selectorTable: st block: latchBlk.
	phiLatchSpvIds := Dictionary new.
	phiVarIndices do: [ :k | phiLatchSpvIds at: k put: (em spvIdFor: (latchResultRegs at: k)) ].
	latchBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { hdrBlk id }).
	phiType := em spvTypeFor: ann params first type.
	phiVarIndices do: [ :k |
		hdrBlk prependInstruction: (SpvInstruction opcode: SpvOpcode opPhi resultType: phiType id resultId: (phiSpvIds at: k) operands: { (phiInitSpvIds at: k). preBlk id. (phiLatchSpvIds at: k). latchBlk id }) ].
	em emitRegOps: exitSim first typeMap: typeMap selectorTable: st block: exitBlk.
	retSpvId := em spvIdFor: exitSim third.
	exitBlk terminate: (SpvInstruction opcode: SpvOpcode opReturnValue resultType: nil resultId: nil operands: { retSpvId }).
	mod addFunction: spvFunc.
	^ mod serialize
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileSelection: selNode annotation: ann typeMap: typeMap selectorTable: st [
	| em mod paramTempDefs condSim condRegOps condNextReg condReg condRegMapSave trueSim trueRegOps trueResultReg trueResultSpvId falseSim falseRegOps falseResultSpvId funcType paramTypes retType spvFunc entryBlk trueBlkSpv falseBlkSpv mergeBlkSpv condSpvId phiId phiType |
	em := self new initialize.
	em annotation: ann.
	mod := em module.
	mod addCapability: 1.
	mod setAddressingModel: 0 memoryModel: 1.
	paramTempDefs := Dictionary new.
	ann params doWithIndex: [ :p :i |
		| pId pType |
		pType := em spvTypeFor: p type.
		pId := mod newId.
		em regMap at: i put: pId.
		paramTempDefs at: i - 1 put: i.
		typeMap at: i put: p type ].
	condSim := PVBlockSimulator new simulateBlock: selNode condBlock
		initialTempDefs: paramTempDefs startingNextReg: ann params size.
	condRegOps := condSim first.
	condNextReg := condSim fourth.
	condReg := condSim third.
	trueSim := PVBlockSimulator new simulateBlock: selNode trueBlocks first
		initialTempDefs: condSim second startingNextReg: condNextReg.
	trueRegOps := trueSim first.
	falseSim := PVBlockSimulator new simulateBlock: selNode falseBlocks first
		initialTempDefs: condSim second startingNextReg: condNextReg.
	falseRegOps := falseSim first.
	retType := em spvTypeFor: ann params first type.
	paramTypes := ann params collect: [ :p | em spvTypeFor: p type ].
	funcType := mod typeRegistry functionType: retType paramTypes: paramTypes asArray.
	spvFunc := SpvFunction new id: mod newId; returnType: retType; functionType: funcType; module: mod; initialize; yourself.
	ann params doWithIndex: [ :p :i |
		spvFunc parameters add: (SpvInstruction opcode: SpvOpcode opFunctionParameter
			resultType: (em spvTypeFor: p type) id resultId: (em regMap at: i) operands: #()) ].
	entryBlk := spvFunc addBlock.
	trueBlkSpv := spvFunc addBlock.
	falseBlkSpv := spvFunc addBlock.
	mergeBlkSpv := spvFunc addBlock.
	em emitRegOps: condRegOps typeMap: typeMap selectorTable: st block: entryBlk.
	condSpvId := em spvIdFor: condReg.
	entryBlk addInstruction: (SpvInstruction opcode: SpvOpcode opSelectionMerge
		resultType: nil resultId: nil operands: { mergeBlkSpv id. 0 }).
	entryBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional
		resultType: nil resultId: nil operands: { condSpvId. trueBlkSpv id. falseBlkSpv id }).
	condRegMapSave := em regMap copy.
	em emitRegOps: trueRegOps typeMap: typeMap selectorTable: st block: trueBlkSpv.
	trueResultReg := trueSim third.
	trueResultSpvId := em spvIdFor: trueResultReg.
	trueBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeBlkSpv id }).
	em regMap: condRegMapSave copy.
	em emitRegOps: falseRegOps typeMap: typeMap selectorTable: st block: falseBlkSpv.
	falseResultSpvId := em spvIdFor: falseSim third.
	falseBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeBlkSpv id }).
	phiType := typeMap at: (trueSim third) ifAbsent: [ ann params first type ].
	phiId := mod newId.
	mergeBlkSpv addInstruction: (SpvInstruction opcode: SpvOpcode opPhi
		resultType: (em spvTypeFor: phiType) id resultId: phiId
		operands: { trueResultSpvId. trueBlkSpv id. falseResultSpvId. falseBlkSpv id }).
	mergeBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opReturnValue
		resultType: nil resultId: nil operands: { phiId }).
	mod addFunction: spvFunc.
	^ mod serialize
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileShaderKernel: regOps annotation: ann typeMap: typeMap selectorTable: st executionModel: execModel [
	| em mod voidT voidFnT spvFunc blk interfaces location |
	em := self new.
	em annotation: ann.
	mod := em module.
	mod addCapability: 1.
	mod setAddressingModel: 0 memoryModel: 1.
	interfaces := OrderedCollection new.
	location := 0.
	ann params doWithIndex: [ :p :i |
		| pType pPtrT gVar |
		pType := em spvTypeFor: p type.
		pPtrT := mod typeRegistry pointerType: SpvStorageClass input type: pType.
		gVar := SpvGlobalVariable new id: mod newId; type: pPtrT; storageClass: SpvStorageClass input; yourself.
		mod addGlobalVariable: gVar.
		interfaces add: gVar.
		mod addDecoration: gVar id decoration: SpvDecoration location literals: { location }.
		location := location + 1.
		em regMap at: i put: gVar id ].
	ann outputs do: [ :o |
		| oType oPtrT oVar |
		oType := em spvTypeFor: o type.
		oPtrT := mod typeRegistry pointerType: SpvStorageClass output type: oType.
		oVar := SpvGlobalVariable new id: mod newId; type: oPtrT; storageClass: SpvStorageClass output; yourself.
		mod addGlobalVariable: oVar.
		interfaces add: oVar.
		o builtIn notNil
			ifTrue: [ mod addDecoration: oVar id decoration: SpvDecoration builtIn literals: { SpvBuiltIn perform: o builtIn } ]
			ifFalse: [ mod addDecoration: oVar id decoration: SpvDecoration location literals: { o location } ].
		em outputVarIds add: oVar id ].
	voidT := mod typeRegistry voidType.
	voidFnT := mod typeRegistry functionType: voidT paramTypes: #().
	spvFunc := SpvFunction new id: mod newId; returnType: voidT; functionType: voidFnT; module: mod; initialize; yourself.
	blk := spvFunc addBlock.
	em isVoidMain: true.
	ann params doWithIndex: [ :p :i |
		| pType loadId |
		pType := em spvTypeFor: p type.
		loadId := mod newId.
		blk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad resultType: pType id resultId: loadId operands: { em regMap at: i }).
		em regMap at: i put: loadId ].
	regOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: blk ].
	blk isTerminated ifFalse: [ blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()) ].
	mod addFunction: spvFunc.
	mod addEntryPoint: spvFunc executionModel: execModel name: 'main' interfaces: interfaces asArray.
	execModel = SpvExecutionModel fragment ifTrue: [
		mod addExecutionMode: spvFunc mode: SpvExecutionMode originUpperLeft literals: #() ].
	^ mod serialize
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileShaderKernelSelection: selNode annotation: ann typeMap: typeMap selectorTable: st executionModel: execModel [
	| em mod voidT voidFnT spvFunc entryBlk interfaces location paramTempDefs condSim condRegOps condTempDefs condReg condNextReg trueSim trueRegOps falseSim falseRegOps trueSpvBlk falseSpvBlk mergeSpvBlk condSpvId condRegMapSave |
	em := self new.
	em annotation: ann.
	mod := em module.
	mod addCapability: 1.
	mod setAddressingModel: 0 memoryModel: 1.
	interfaces := OrderedCollection new.
	location := 0.
	paramTempDefs := Dictionary new.
	ann params doWithIndex: [ :p :i |
		| pType pPtrT gVar |
		pType := em spvTypeFor: p type.
		pPtrT := mod typeRegistry pointerType: SpvStorageClass input type: pType.
		gVar := SpvGlobalVariable new id: mod newId; type: pPtrT; storageClass: SpvStorageClass input; yourself.
		mod addGlobalVariable: gVar.
		interfaces add: gVar.
		mod addDecoration: gVar id decoration: SpvDecoration location literals: { location }.
		location := location + 1.
		em regMap at: i put: gVar id.
		paramTempDefs at: i - 1 put: i ].
	ann outputs do: [ :o |
		| oType oPtrT oVar |
		oType := em spvTypeFor: o type.
		oPtrT := mod typeRegistry pointerType: SpvStorageClass output type: oType.
		oVar := SpvGlobalVariable new id: mod newId; type: oPtrT; storageClass: SpvStorageClass output; yourself.
		mod addGlobalVariable: oVar.
		interfaces add: oVar.
		o builtIn notNil
			ifTrue: [ mod addDecoration: oVar id decoration: SpvDecoration builtIn literals: { SpvBuiltIn perform: o builtIn } ]
			ifFalse: [ mod addDecoration: oVar id decoration: SpvDecoration location literals: { o location } ].
		em outputVarIds add: oVar id ].
	voidT := mod typeRegistry voidType.
	voidFnT := mod typeRegistry functionType: voidT paramTypes: #().
	spvFunc := SpvFunction new id: mod newId; returnType: voidT; functionType: voidFnT; module: mod; initialize; yourself.
	entryBlk := spvFunc addBlock.
	em isVoidMain: true.
	ann params doWithIndex: [ :p :i |
		| pType loadId |
		pType := em spvTypeFor: p type.
		loadId := mod newId.
		entryBlk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad resultType: pType id resultId: loadId operands: { em regMap at: i }).
		em regMap at: i put: loadId ].
	condSim := PVBlockSimulator new simulateBlock: selNode condBlock initialTempDefs: paramTempDefs startingNextReg: ann params size.
	condRegOps := condSim first.
	condTempDefs := condSim second.
	condReg := condSim third.
	condNextReg := condSim fourth.
	condRegOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: entryBlk ].
	condSpvId := em spvIdFor: condReg.
	trueSpvBlk := spvFunc addBlock.
	falseSpvBlk := spvFunc addBlock.
	mergeSpvBlk := spvFunc addBlock.
	entryBlk addInstruction: (SpvInstruction opcode: SpvOpcode opSelectionMerge resultType: nil resultId: nil operands: { mergeSpvBlk id. 0 }).
	entryBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional resultType: nil resultId: nil operands: { condSpvId. trueSpvBlk id. falseSpvBlk id }).
	trueSim := PVBlockSimulator new simulateBlock: selNode trueBlocks first initialTempDefs: condTempDefs startingNextReg: condNextReg.
	trueRegOps := trueSim first.
	condRegMapSave := em regMap copy.
	trueRegOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: trueSpvBlk ].
	trueSpvBlk isTerminated ifFalse: [ trueSpvBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeSpvBlk id }) ].
	em regMap: condRegMapSave copy.
	falseSim := PVBlockSimulator new simulateBlock: selNode falseBlocks first initialTempDefs: condTempDefs startingNextReg: condNextReg.
	falseRegOps := falseSim first.
	falseRegOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: falseSpvBlk ].
	falseSpvBlk isTerminated ifFalse: [ falseSpvBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeSpvBlk id }) ].
	mergeSpvBlk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()).
	mod addFunction: spvFunc.
	mod addEntryPoint: spvFunc executionModel: execModel name: 'main' interfaces: interfaces asArray.
	execModel = SpvExecutionModel fragment ifTrue: [
		mod addExecutionMode: spvFunc mode: SpvExecutionMode originUpperLeft literals: #() ].
	^ mod serialize
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileVertexShader: regOps annotation: ann typeMap: typeMap selectorTable: st [
    ^ self compileShaderKernel: regOps annotation: ann typeMap: typeMap selectorTable: st
        executionModel: SpvExecutionModel vertex
]

{ #category : 'constants' }
PVSPIRVEmitter class >> computeDescriptorSet [
	"PVComputeKernel allocates one descriptor set, so every buffer lives in set 0."
	^ 0
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> computeLoopSimulations: loopNode annotation: ann selectorTable: st [
	"Simulate the four blocks of a compute loop with one shared register numbering, and
	 infer the types over that numbering. The exit block inherits the preheader's stack
	 residue, because the preheader may leave a value on the stack that the code after
	 the loop pops."

	| preheaderSim headerSim latchSim exitSim |
	preheaderSim := PVBlockSimulator new simulateBlock: loopNode preheaderBlock initialTempDefs: (self paramTempDefsFor: ann) startingNextReg: ann params size + 1.
	headerSim := PVBlockSimulator new simulateBlock: loopNode headerBlock initialTempDefs: preheaderSim second startingNextReg: preheaderSim fourth.
	latchSim := PVBlockSimulator new simulateBlock: loopNode bodyBlocks first initialTempDefs: preheaderSim second startingNextReg: headerSim fourth.
	exitSim := PVBlockSimulator new simulateBlock: loopNode exitBlock initialTempDefs: preheaderSim second startingNextReg: latchSim fourth initialStack: (preheaderSim at: 5).
	^ Dictionary newFrom: {
		  #preheader -> preheaderSim.
		  #header -> headerSim.
		  #latch -> latchSim.
		  #exit -> exitSim.
		  #typeMap -> (self inferTypesOver: { preheaderSim. headerSim. latchSim. exitSim } annotation: ann selectorTable: st) second }
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> computeSelectionSimulations: selNode annotation: ann selectorTable: st [
	"Simulate the four blocks of a compute selection with one shared register numbering,
	 and infer the types over that numbering. The phi register is the first register no
	 block defined, and its type is the type of the value the arms produce, which the
	 merge block then consumes."

	| condSim trueSim falseSim mergeSim phiReg inference typeMap |
	condSim := PVBlockSimulator new simulateBlock: selNode condBlock initialTempDefs: (self paramTempDefsFor: ann) startingNextReg: ann params size + 1.
	trueSim := PVBlockSimulator new simulateBlock: selNode trueBlocks first initialTempDefs: condSim second startingNextReg: condSim fourth.
	falseSim := PVBlockSimulator new simulateBlock: selNode falseBlocks first initialTempDefs: condSim second startingNextReg: trueSim fourth.
	phiReg := falseSim fourth.
	mergeSim := PVBlockSimulator new simulateBlock: selNode mergeBlock initialTempDefs: condSim second startingNextReg: phiReg + 1 initialStack: (self selectionMergeStackFrom: condSim phiReg: phiReg).
	inference := self inferTypesOver: { condSim. trueSim. falseSim } annotation: ann selectorTable: st.
	typeMap := inference second.
	typeMap at: phiReg put: (typeMap at: trueSim third ifAbsent: [ typeMap at: falseSim third ]).
	inference first inferAll: mergeSim first selectorTable: st.
	^ Dictionary newFrom: {
		  #cond -> condSim.
		  #true -> trueSim.
		  #false -> falseSim.
		  #merge -> mergeSim.
		  #phiReg -> phiReg.
		  #typeMap -> typeMap }
]

{ #category : 'constants' }
PVSPIRVEmitter class >> defaultLocalSize [
	"The local size every compute entry point declares. One dimension of 64 matches the
	 group size PVComputeTest dispatches with; a kernel that wants another shape has to
	 carry it in its annotation, which this phase does not add."

	^ #( 64 1 1 )
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> emitSelectionKernel: selNode annotation: ann selectorTable: st typeMap: typeMap module: aModule [
	| em paramTypes spvFunc entryBlk trueBlkSpv falseBlkSpv mergeBlkSpv condReg trueReg falseReg condSpvId phiId phiType retType funcType condSimResult condTempDefs |
	em := self new initialize.
	em annotation: ann.
	aModule addCapability: 1.
	aModule setAddressingModel: 0 memoryModel: 1.
	"Seed regMap and typeMap with param SpvIds"
	ann params doWithIndex: [ :p :i |
		| pId pType |
		pType := em spvTypeFor: p type.
		pId := aModule newId.
		em regMap at: i put: pId.
		typeMap at: i put: p type ].
	"Simulate condition block"
	condSimResult := PVBlockSimulator simulate: selNode condBlock
		initialTempDefs: em regMap annotation: ann selectorTable: st.
	condTempDefs := condSimResult second.
	condReg := condSimResult third.
	"Infer result type of condReg ops"
	(condSimResult first) do: [ :op |
		(#(#return #returnSelf #self #pop) includes: op opcode) ifFalse: [
			op result ifNotNil: [ :r |
				| mapping recv |
				op opcode = #send ifTrue: [
					recv := typeMap at: op inputs first ifAbsent: [ nil ].
					recv ifNotNil: [
						mapping := selectorTable at: op literal receiverType: recv ifAbsent: [ nil ].
						mapping ifNil: [ mapping := (PVSelectorTable standard) at: op literal receiverType: recv ].
						mapping ifNotNil: [ typeMap at: r put: mapping resultTypeSymbol ] ] ].
				op opcode = #const ifTrue: [
					typeMap at: r put: (op literal isFloat ifTrue: [ #f32 ] ifFalse: [ #i32 ]) ] ] ] ].
	"Build function with retType=f32/i32 (inferred from param type)"
	retType := em spvTypeFor: (ann params first type).
	paramTypes := ann params collect: [ :p | em spvTypeFor: p type ].
	funcType := aModule typeRegistry functionType: retType paramTypes: paramTypes asArray.
	spvFunc := SpvFunction new id: aModule newId; returnType: retType; functionType: funcType; module: aModule; initialize; yourself.
	"Add OpFunctionParameter for each param"
	ann params doWithIndex: [ :p :i |
		spvFunc parameters add: (SpvInstruction opcode: SpvOpcode opFunctionParameter
			resultType: (em spvTypeFor: p type) id resultId: (em regMap at: i) operands: #()) ].
	"Build SpvBlocks"
	entryBlk := spvFunc addBlock.
	trueBlkSpv := spvFunc addBlock.
	falseBlkSpv := spvFunc addBlock.
	mergeBlkSpv := spvFunc addBlock.
	"Emit cond block ops into entry"
	(condSimResult first) do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: (PVSelectorTable standard) block: entryBlk ].
	condSpvId := em spvIdFor: condReg.
	entryBlk addInstruction: (SpvInstruction opcode: SpvOpcode opSelectionMerge
		resultType: nil resultId: nil operands: { mergeBlkSpv id. 0 }).
	entryBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional
		resultType: nil resultId: nil operands: { condSpvId. trueBlkSpv id. falseBlkSpv id }).
	"True branch"
	trueReg := em emitBytecodeBlock: selNode trueBlocks first initialTempDefs: condTempDefs typeMap: typeMap selectorTable: (PVSelectorTable standard) block: trueBlkSpv.
	trueBlkSpv isTerminated ifFalse: [ trueBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeBlkSpv id }) ].
	"False branch"
	falseReg := em emitBytecodeBlock: selNode falseBlocks first initialTempDefs: condTempDefs typeMap: typeMap selectorTable: (PVSelectorTable standard) block: falseBlkSpv.
	falseBlkSpv isTerminated ifFalse: [ falseBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeBlkSpv id }) ].
	"Merge: OpPhi + return"
	phiType := typeMap at: trueReg ifAbsent: [ typeMap at: falseReg ifAbsent: [ ann params first type ] ].
	phiId := aModule newId.
	mergeBlkSpv addInstruction: (SpvInstruction opcode: SpvOpcode opPhi
		resultType: (em spvTypeFor: phiType) id resultId: phiId
		operands: { em spvIdFor: trueReg. trueBlkSpv id. em spvIdFor: falseReg. falseBlkSpv id }).
	mergeBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opReturnValue
		resultType: nil resultId: nil operands: { phiId }).
	aModule addFunction: spvFunc.
	^ aModule serialize
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> inferTypesOver: sims annotation: ann selectorTable: st [
	"One PVTypeInferencer accumulates into a single typeMap across the blocks, so a
	 register defined in one block keeps its type in the next. Answer the inferencer as
	 well, because a caller may have to seed a phi type and then infer one block more."

	| inferencer typeMap |
	inferencer := PVTypeInferencer new initialize annotation: ann.
	typeMap := nil.
	sims do: [ :each | typeMap := inferencer inferAll: each first selectorTable: st ].
	^ { inferencer. typeMap }
]

{ #category : 'constants' }
PVSPIRVEmitter class >> loopControlNone [
	"OpLoopMerge takes a loop control mask; the compiler requests no unrolling hints."
	^ 0
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> loopPhisFrom: preheaderSim latch: latchSim [
	"A loop-carried variable is one the latch leaves in a different register than the
	 preheader did; that pair is exactly what the header phi joins. A variable both
	 blocks leave in the same register is loop-invariant and needs no phi."

	| indices initRegs latchRegs |
	indices := OrderedCollection new.
	initRegs := Dictionary new.
	latchRegs := Dictionary new.
	preheaderSim second keysAndValuesDo: [ :k :preReg |
		| latchReg |
		latchReg := latchSim second at: k ifAbsent: [ preReg ].
		latchReg = preReg ifFalse: [
			indices add: k.
			initRegs at: k put: preReg.
			latchRegs at: k put: latchReg ] ].
	^ Dictionary newFrom: {
		  #indices -> indices.
		  #init -> initRegs.
		  #latch -> latchRegs }
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> paramTempDefsFor: ann [
	"The kernel's parameters occupy the first registers, in declaration order; temp 0 is
	 the first parameter because a kernel method has no receiver on the GPU."

	| defs |
	defs := Dictionary new.
	ann params doWithIndex: [ :p :i | defs at: i - 1 put: i ].
	^ defs
]

{ #category : 'constants' }
PVSPIRVEmitter class >> selectionControlNone [
	"OpSelectionMerge takes a selection control mask; the compiler requests no flattening
	 hints."
	^ 0
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> selectionMergeStackFrom: condSim phiReg: phiReg [
	"What the merge block consumes is the value the two arms produce, so the phi register
	 sits on top of its stack. Below it is whatever the condition block pushed before the
	 selection, less the condition itself: the simulator never executes the jumpIf that
	 pops it."

	| stack |
	stack := (condSim at: 5) asOrderedCollection.
	stack isEmpty ifFalse: [ stack removeLast ].
	stack addLast: phiReg.
	^ stack
]

{ #category : 'constants' }
PVSPIRVEmitter class >> storageBufferArrayStride [
	"Both element types a kernel buffer may hold, f32 and i32, are four bytes wide."
	^ 4
]

{ #category : 'accessing' }
PVSPIRVEmitter >> annotation [
^ annotation
]

{ #category : 'accessing' }
PVSPIRVEmitter >> annotation: ann [
	annotation := ann
]

{ #category : 'emit' }
PVSPIRVEmitter >> broadcastScalar: reg toVecType: vecTypeSymbol block: blk [
	| count vecType scalarId broadcastId |
	count := (#(#vec2 #vec3 #vec4) indexOf: vecTypeSymbol) + 1.
	vecType := self spvTypeFor: vecTypeSymbol.
	scalarId := self spvIdFor: reg.
	broadcastId := module newId.
	blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeConstruct
		resultType: vecType id resultId: broadcastId
		operands: (Array new: count withAll: scalarId)).
	^ broadcastId
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> emitBufferLoad: op typeMap: typeMap block: blk [
| bufVarId idxId recvType elemType ptrType elemPtrId loadId u32Zero |
bufVarId := self spvIdFor: op inputs first.
idxId := self spvIdFor: op inputs second.
recvType := typeMap at: op inputs first.
elemType := recvType = #bufferOf_i32
    ifTrue: [ module typeRegistry intType: 32 signed: true ]
    ifFalse: [ module typeRegistry floatType: 32 ].
ptrType := module typeRegistry pointerType: 12 type: elemType.
u32Zero := module constantPool constantUInt32: 0.
elemPtrId := module newId.
blk addInstruction: (SpvInstruction
    opcode: SpvOpcode opAccessChain
    resultType: ptrType id
    resultId: elemPtrId
    operands: { bufVarId. u32Zero. idxId }).
loadId := module newId.
regMap at: op result put: loadId.
blk addInstruction: (SpvInstruction
    opcode: SpvOpcode opLoad
    resultType: elemType id
    resultId: loadId
    operands: { elemPtrId })
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> emitBufferStore: op typeMap: typeMap block: blk [
| bufVarId idxId valId recvType elemType ptrType elemPtrId u32Zero |
bufVarId := self spvIdFor: op inputs first.
idxId := self spvIdFor: op inputs second.
valId := self spvIdFor: op inputs third.
recvType := typeMap at: op inputs first.
elemType := recvType = #bufferOf_i32
    ifTrue: [ module typeRegistry intType: 32 signed: true ]
    ifFalse: [ module typeRegistry floatType: 32 ].
ptrType := module typeRegistry pointerType: 12 type: elemType.
u32Zero := module constantPool constantUInt32: 0.
elemPtrId := module newId.
blk addInstruction: (SpvInstruction
    opcode: SpvOpcode opAccessChain
    resultType: ptrType id
    resultId: elemPtrId
    operands: { bufVarId. u32Zero. idxId }).
blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore operands: { elemPtrId. valId }).
regMap at: op result put: elemPtrId
]

{ #category : 'emitting structured' }
PVSPIRVEmitter >> emitBytecodeBlock: blk initialTempDefs: initDefs typeMap: typeMap selectorTable: st block: spvBlk [
	| simResult regOps finalDefs resultReg |
	simResult := PVBlockSimulator simulate: blk initialTempDefs: initDefs annotation: annotation selectorTable: st.
	regOps := simResult first.
	finalDefs := simResult second.
	resultReg := simResult third.
	regOps do: [ :op | self emitRegOp: op typeMap: typeMap selectorTable: st block: spvBlk ].
	"Seed regMap with newly defined temps for downstream blocks"
	finalDefs keysAndValuesDo: [ :tempIdx :absReg |
		(regMap includesKey: absReg) ifFalse: [ regMap at: absReg put: absReg ] ].
	^ resultReg
]

{ #category : 'emitting structured' }
PVSPIRVEmitter >> emitBytecodeBlock: blk typeMap: typeMap selectorTable: st block: spvBlk [
	| lastResultReg |
	lastResultReg := nil.
	blk ops do: [ :op |
		(#(#jump #jumpIf #returnTop #returnSelf) includes: op opcode) ifFalse: [
			"Stack ops: simulate and emit"
			| simResult |
			simResult := PVBlockSimulator simulate: blk initialTempDefs: regMap annotation: annotation selectorTable: st.
			"Emit regOps from simResult"
			(simResult first) do: [ :regOp |
				self emitRegOp: regOp typeMap: typeMap selectorTable: st block: spvBlk ].
			"Update regMap from simulation"
			(simResult second) keysAndValuesDo: [ :k :v | regMap at: k put: v ].
			lastResultReg := simResult third.
			^ lastResultReg ] ].
	^ lastResultReg
]

{ #category : 'emit' }
PVSPIRVEmitter >> emitCompositeConstruct: op typeMap: typeMap block: blk [
    | mapping resultType resultTypeId resultId |
    mapping := (PVSelectorTable standard) at: op literal receiverType: (typeMap at: op inputs first).
    resultType := self spvTypeFor: mapping resultTypeSymbol.
    resultTypeId := resultType id.
    resultId := module newId.
    regMap at: op result put: resultId.
    blk addInstruction: (SpvInstruction
        opcode: SpvOpcode opCompositeConstruct
        resultType: resultTypeId
        resultId: resultId
        operands: (op inputs collect: [:r | self spvIdFor: r]))
]

{ #category : 'emit' }
PVSPIRVEmitter >> emitCompositeConstruct: op typeMap: typeMap selectorTable: st block: blk [
    | mapping resultType resultTypeId resultId |
    mapping := st at: op literal receiverType: (typeMap at: op inputs first).
    resultType := self spvTypeFor: mapping resultTypeSymbol.
    resultTypeId := resultType id.
    resultId := module newId.
    regMap at: op result put: resultId.
    blk addInstruction: (SpvInstruction
        opcode: SpvOpcode opCompositeConstruct
        resultType: resultTypeId
        resultId: resultId
        operands: (op inputs collect: [:r | self spvIdFor: r]))
]

{ #category : 'emitting' }
PVSPIRVEmitter >> emitComputeInterfaces [
	"Create the interface variables of a compute entry point from the annotation: the
	 WorkItem parameter becomes the GlobalInvocationId built-in, and every buffer
	 parameter becomes a storage buffer at descriptor set 0 on the next binding. Answer
	 them in declaration order, which is the order the entry point lists them and the
	 order PVComputeKernel binds buffers in. Shared by the three compute entry points,
	 which differ only in what sits between this prologue and OpReturn."

	| interfaces decoratedRtas binding |
	interfaces := OrderedCollection new.
	decoratedRtas := Set new.
	binding := 0.
	annotation params doWithIndex: [ :p :i |
		p type = #workItem
			ifTrue: [ interfaces add: (self emitWorkItemInputForParam: i) ]
			ifFalse: [
				interfaces add: (self
						 emitStorageBufferParam: p
						 at: i
						 binding: binding
						 decoratedArrays: decoratedRtas).
				binding := binding + 1 ] ].
	^ interfaces
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitComputeLoopFrom: sims phis: phis selectorTable: st [
	"Build the four blocks of a compute loop and answer the function holding them. The
	 context dictionary carries what every step needs — the simulations, the phi pairs and
	 the four blocks — because the steps have to agree on all of it."

	| spvFunc ctx |
	spvFunc := self newComputeMainFunction.
	ctx := Dictionary newFrom: {
			       (#sims -> sims).
			       (#phis -> phis).
			       (#selectorTable -> st).
			       (#preBlock -> spvFunc addBlock).
			       (#headerBlock -> spvFunc addBlock).
			       (#latchBlock -> spvFunc addBlock).
			       (#exitBlock -> spvFunc addBlock) }.
	self emitLoopPreheaderIn: ctx.
	self emitLoopHeaderIn: ctx.
	self emitLoopLatchIn: ctx.
	self prependLoopPhisIn: ctx.
	self emitLoopExitIn: ctx.
	^ spvFunc
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitComputeSelectionFrom: sims selectorTable: st [
	"Build the four blocks of a compute selection and answer the function holding them."

	| spvFunc ctx |
	spvFunc := self newComputeMainFunction.
	ctx := Dictionary newFrom: {
			       (#sims -> sims).
			       (#selectorTable -> st).
			       (#entryBlock -> spvFunc addBlock).
			       (#trueBlock -> spvFunc addBlock).
			       (#falseBlock -> spvFunc addBlock).
			       (#mergeBlock -> spvFunc addBlock) }.
	self emitSelectionConditionIn: ctx.
	self emitSelectionArmsIn: ctx.
	self emitSelectionMergeIn: ctx.
	^ spvFunc
]

{ #category : 'emit' }
PVSPIRVEmitter >> emitExtInst: glslOp op: op typeMap: typeMap block: blk [
    | mapping resultType resultTypeId resultId setId |
    mapping := (PVSelectorTable standard) at: op literal receiverType: (typeMap at: op inputs first).
    resultType := self spvTypeFor: mapping resultTypeSymbol.
    resultTypeId := resultType id.
    resultId := module newId.
    setId := self ensureGlslExtInstSet.
    regMap at: op result put: resultId.
    blk addInstruction: (SpvInstruction
        opcode: SpvOpcode opExtInst
        resultType: resultTypeId
        resultId: resultId
        operands: ({ setId. glslOp } , (op inputs collect: [:r | self spvIdFor: r])))
]

{ #category : 'private' }
PVSPIRVEmitter >> emitExtInst: glslOp op: op typeMap: typeMap selectorTable: st block: blk [
	| mapping resultType resultTypeId resultId setId operandIds |
	mapping := st at: op literal receiverType: (typeMap at: op inputs first).
	resultType := self spvTypeFor: mapping resultTypeSymbol.
	resultTypeId := resultType id.
	resultId := module newId.
	setId := self ensureGlslExtInstSet.
	regMap at: op result put: resultId.
	operandIds := op inputs collect: [:r |
		| inputType |
		inputType := typeMap at: r ifAbsent: [nil].
		(inputType notNil
			and: [inputType ~= mapping resultTypeSymbol
			and: [#(#vec2 #vec3 #vec4) includes: mapping resultTypeSymbol]])
			ifTrue: [self broadcastScalar: r toVecType: mapping resultTypeSymbol block: blk]
			ifFalse: [self spvIdFor: r]].
	blk addInstruction: (SpvInstruction
		opcode: SpvOpcode opExtInst
		resultType: resultTypeId
		resultId: resultId
		operands: ({ setId. glslOp } , operandIds))
]

{ #category : 'emitting' }
PVSPIRVEmitter >> emitKernelFunction: regOps typeMap: typeMap selectorTable: st name: funcName [
	| paramTypes retTypeSymbol retType funcType spvFunc blk |
	"Determine return type from the return op"
	retTypeSymbol := #void.
	regOps do: [ :op |
		op opcode = #return ifTrue: [
			retTypeSymbol := typeMap at: op inputs first ifAbsent: [ #void ] ] ].
	retType := self spvTypeFor: retTypeSymbol.
	"Param types from annotation"
	paramTypes := annotation params collect: [ :p | self spvTypeFor: p type ].
	funcType := module typeRegistry functionType: retType paramTypes: paramTypes asArray.
	"Create function"
	spvFunc := SpvFunction new
		id: module newId;
		returnType: retType;
		functionType: funcType;
		module: module;
		initialize;
		yourself.
	"Emit parameters — seed regMap with param SpvIds (reg 1..n)"
	annotation params doWithIndex: [ :p :i |
		| pId pInstr |
			pId := module newId.
		pInstr := SpvInstruction
			opcode: SpvOpcode opFunctionParameter
			resultType: (self spvTypeFor: p type) id
			resultId: pId
			operands: #().
		spvFunc parameters add: pInstr.
		regMap at: i put: pId ].
	"Single block for straight-line methods"
	blk := spvFunc addBlock.
	"Emit each register op"
	regOps do: [ :op |
		self emitRegOp: op typeMap: typeMap selectorTable: st block: blk ].
	"If block not terminated (e.g. void return), add OpReturn"
	blk isTerminated ifFalse: [
		blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()) ].
	module addFunction: spvFunc.
	^ spvFunc
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitLoopExitIn: ctx [
	"The exit block carries the work after the loop, which for a compute kernel is the
	 store through the output buffer, then returns."

	| sims blk |
	sims := ctx at: #sims.
	blk := ctx at: #exitBlock.
	self
		emitRegOps: (sims at: #exit) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	blk isTerminated ifFalse: [
		blk terminate:
			(SpvInstruction opcode: SpvOpcode opReturn operands: #( )) ]
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitLoopHeaderIn: ctx [
	"The header holds the test. OpLoopMerge names the exit block and the continue target,
	 and must come immediately before the branch that leaves the block."

	| sims blk |
	sims := ctx at: #sims.
	blk := ctx at: #headerBlock.
	self
		emitRegOps: (sims at: #header) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	blk
		addInstruction: (SpvInstruction
				 opcode: SpvOpcode opLoopMerge
				 resultType: nil
				 resultId: nil
				 operands: {
						 (ctx at: #exitBlock) id.
						 (ctx at: #latchBlock) id.
						 self class loopControlNone });
		terminate: (SpvInstruction
				 opcode: SpvOpcode opBranchConditional
				 resultType: nil
				 resultId: nil
				 operands: {
						 (self spvIdFor: (sims at: #header) third).
						 (ctx at: #latchBlock) id.
						 (ctx at: #exitBlock) id })
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitLoopLatchIn: ctx [
	"The body is also the continue target: it ends with the back edge to the header, and
	 the registers it leaves the loop-carried variables in become the latch side of the
	 phis."

	| sims phis blk |
	sims := ctx at: #sims.
	phis := ctx at: #phis.
	blk := ctx at: #latchBlock.
	self
		emitRegOps: (sims at: #latch) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	ctx
		at: #phiLatch
		put: ((phis at: #indices) collect: [ :k |
				 self spvIdFor: ((phis at: #latch) at: k) ]).
	blk terminate: (SpvInstruction
			 opcode: SpvOpcode opBranch
			 resultType: nil
			 resultId: nil
			 operands: { (ctx at: #headerBlock) id })
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitLoopPreheaderIn: ctx [
	"The preheader runs once, before the loop. Its last act is to name the phi results:
	 the phi stands for the variable inside the loop, so the register the preheader left
	 the initial value in must point at the phi before the header and the latch are
	 emitted."

	| sims phis blk |
	sims := ctx at: #sims.
	phis := ctx at: #phis.
	blk := ctx at: #preBlock.
	self
		emitRegOps: (sims at: #preheader) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	ctx
		at: #phiInit
		put: ((phis at: #indices) collect: [ :k |
				 self spvIdFor: ((phis at: #init) at: k) ]).
	ctx at: #phiResult put: ((phis at: #indices) collect: [ :k | module newId ]).
	(phis at: #indices) doWithIndex: [ :k :n |
		regMap at: ((phis at: #init) at: k) put: ((ctx at: #phiResult) at: n) ].
	blk terminate: (SpvInstruction
			 opcode: SpvOpcode opBranch
			 resultType: nil
			 resultId: nil
			 operands: { (ctx at: #headerBlock) id })
]

{ #category : 'emit' }
PVSPIRVEmitter >> emitRegOp: op typeMap: typeMap selectorTable: st block: blk [
    | opc |
    op opcode = #const ifTrue: [
        | constId |
        constId := op literal isFloat
            ifTrue: [ module constantPool constantFloat32: op literal asFloat ]
            ifFalse: [ module constantPool constantInt32: op literal ].
        regMap at: op result put: constId.
        ^ self ].
    op opcode = #move ifTrue: [
        regMap at: op result put: (self spvIdFor: op inputs first).
        ^ self ].
    op opcode = #self ifTrue: [ ^ self ].
    op opcode = #storeInstVar ifTrue: [
        blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore operands:
            { outputVarIds at: op literal + 1. self spvIdFor: op inputs first }).
        ^ self ].
    op opcode = #send ifTrue: [
        | mapping resultTypeId resultId |
        mapping := st at: op literal receiverType: (typeMap at: op inputs first).
        mapping ifNil: [ PVTypeError signal: 'No mapping for ' , op literal ].
        mapping spirvOp = #bufferLoad       ifTrue: [ self emitBufferLoad: op typeMap: typeMap block: blk. ^ self ].
        mapping spirvOp = #bufferStore      ifTrue: [ self emitBufferStore: op typeMap: typeMap block: blk. ^ self ].
        mapping spirvOp = #workItemX        ifTrue: [ self emitWorkItemComponent: 0 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemY        ifTrue: [ self emitWorkItemComponent: 1 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemZ        ifTrue: [ self emitWorkItemComponent: 2 op: op block: blk. ^ self ].
        mapping spirvOp = #compositeConstruct ifTrue: [ self emitCompositeConstruct: op typeMap: typeMap selectorTable: st block: blk. ^ self ].
        mapping spirvOp = #vecExtractX      ifTrue: [ self emitVecExtract: 0 op: op block: blk. ^ self ].
        mapping spirvOp = #vecExtractY      ifTrue: [ self emitVecExtract: 1 op: op block: blk. ^ self ].
        mapping spirvOp = #vecExtractZ      ifTrue: [ self emitVecExtract: 2 op: op block: blk. ^ self ].
        mapping spirvOp = #vecExtractW      ifTrue: [ self emitVecExtract: 3 op: op block: blk. ^ self ].
        mapping spirvOp = #glslNormalize    ifTrue: [ self emitExtInst: GlslStd450 normalize  op: op typeMap: typeMap selectorTable: st block: blk. ^ self ].
        mapping spirvOp = #glslLength       ifTrue: [ self emitExtInst: GlslStd450 length     op: op typeMap: typeMap selectorTable: st block: blk. ^ self ].
        mapping spirvOp = #glslFMix         ifTrue: [ self emitExtInst: GlslStd450 fMix       op: op typeMap: typeMap selectorTable: st block: blk. ^ self ].
        mapping spirvOp = #glslFClamp       ifTrue: [ self emitExtInst: GlslStd450 fClamp     op: op typeMap: typeMap selectorTable: st block: blk. ^ self ].
        mapping spirvOp = #glslSqrt         ifTrue: [ self emitExtInst: GlslStd450 sqrt       op: op typeMap: typeMap selectorTable: st block: blk. ^ self ].
        opc := self opcodeFor: mapping spirvOp.
        resultTypeId := (self spvTypeFor: mapping resultTypeSymbol) id.
        resultId := module newId.
        regMap at: op result put: resultId.
        blk addInstruction: (SpvInstruction opcode: opc resultType: resultTypeId resultId: resultId
            operands: (op inputs collect: [:r | self spvIdFor: r])).
        ^ self ].
    op opcode = #return ifTrue: [
        isVoidMain
            ifTrue: [
                outputVarIds isEmpty ifFalse: [
                    blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore operands:
                        { outputVarIds first. self spvIdFor: op inputs first }) ].
                blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()) ]
            ifFalse: [
                blk terminate: (SpvInstruction opcode: SpvOpcode opReturnValue resultType: nil resultId: nil
                    operands: { self spvIdFor: op inputs first }) ].
        ^ self ].
    op opcode = #returnSelf ifFalse: [ ^ self ].
    blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #())
]

{ #category : 'emitting structured' }
PVSPIRVEmitter >> emitRegOps: regOpList typeMap: typeMap selectorTable: st block: spvBlk [
	regOpList do: [ :op |
		(#(#return #returnSelf) includes: op opcode) ifFalse: [
			self emitRegOp: op typeMap: typeMap selectorTable: st block: spvBlk ] ]
]

{ #category : 'emitting structured' }
PVSPIRVEmitter >> emitSelection: selNode typeMap: typeMap selectorTable: st function: spvFunc condReg: condReg [
	| trueBlk falseBlk mergeBlk trueSpvBlk falseSpvBlk mergeSpvBlk condId trueVal falseVal phiId phiType condSpvBlk |
	trueBlk := selNode trueBlocks first.
	falseBlk := selNode falseBlocks first.
	mergeBlk := selNode mergeBlock.
	trueSpvBlk := spvFunc addBlock.
	falseSpvBlk := spvFunc addBlock.
	mergeSpvBlk := spvFunc addBlock.
	condId := self spvIdFor: condReg.
	"Terminate cond block with OpSelectionMerge + OpBranchConditional"
	condSpvBlk := spvFunc blocks at: spvFunc blocks size - 3.
	condSpvBlk addInstruction: (SpvInstruction opcode: SpvOpcode opSelectionMerge
		resultType: nil resultId: nil operands: { mergeSpvBlk id. 0 }).
	condSpvBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional
		resultType: nil resultId: nil operands: { condId. trueSpvBlk id. falseSpvBlk id }).
	trueVal := self emitBytecodeBlock: trueBlk typeMap: typeMap selectorTable: st block: trueSpvBlk.
	trueSpvBlk isTerminated ifFalse: [
		trueSpvBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch
			resultType: nil resultId: nil operands: { mergeSpvBlk id }) ].
	falseVal := self emitBytecodeBlock: falseBlk typeMap: typeMap selectorTable: st block: falseSpvBlk.
	falseSpvBlk isTerminated ifFalse: [
		falseSpvBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch
			resultType: nil resultId: nil operands: { mergeSpvBlk id }) ].
	(trueVal notNil and: [ falseVal notNil ]) ifTrue: [
		phiType := typeMap at: trueVal ifAbsent: [ nil ].
		phiType ifNotNil: [
			phiId := module newId.
			mergeSpvBlk addInstruction: (SpvInstruction opcode: SpvOpcode opPhi
				resultType: (self spvTypeFor: phiType) id
				resultId: phiId
				operands: { trueVal. trueSpvBlk id. falseVal. falseSpvBlk id }).
			^ phiId ] ].
	^ nil
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitSelectionArm: armKey into: blockKey in: ctx [
	"One arm of the selection: its own work, then the branch to the merge block. The id of
	 the value it produces is kept under armKey for the merge phi."

	| sims blk |
	sims := ctx at: #sims.
	blk := ctx at: blockKey.
	self
		emitRegOps: (sims at: armKey) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	ctx at: armKey put: (self spvIdFor: (sims at: armKey) third).
	blk terminate: (SpvInstruction
			 opcode: SpvOpcode opBranch
			 resultType: nil
			 resultId: nil
			 operands: { (ctx at: #mergeBlock) id })
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitSelectionArm: armKey into: blockKey valueKey: valueKey in: ctx [
	"One arm of the selection: its own work, then the branch to the merge block. The id of
	 the value it produces is kept under valueKey for the merge phi."

	| sims blk |
	sims := ctx at: #sims.
	blk := ctx at: blockKey.
	self
		emitRegOps: (sims at: armKey) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	ctx at: valueKey put: (self spvIdFor: (sims at: armKey) third).
	blk terminate: (SpvInstruction
			 opcode: SpvOpcode opBranch
			 resultType: nil
			 resultId: nil
			 operands: { (ctx at: #mergeBlock) id })
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitSelectionArmsIn: ctx [
	"Each arm starts from the register map as the condition block left it: the arms are
	 alternatives, so a register one arm defines must not be visible to the other."

	| condRegMap |
	condRegMap := regMap copy.
	self
		emitSelectionArm: #true
		into: #trueBlock
		valueKey: #trueValue
		in: ctx.
	regMap := condRegMap copy.
	self
		emitSelectionArm: #false
		into: #falseBlock
		valueKey: #falseValue
		in: ctx
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitSelectionConditionIn: ctx [
	"The entry block computes the condition. OpSelectionMerge names the block the two arms
	 rejoin at, and must come immediately before the conditional branch."

	| sims blk |
	sims := ctx at: #sims.
	blk := ctx at: #entryBlock.
	self
		emitRegOps: (sims at: #cond) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	blk
		addInstruction: (SpvInstruction
				 opcode: SpvOpcode opSelectionMerge
				 resultType: nil
				 resultId: nil
				 operands: {
						 (ctx at: #mergeBlock) id.
						 self class selectionControlNone });
		terminate: (SpvInstruction
				 opcode: SpvOpcode opBranchConditional
				 resultType: nil
				 resultId: nil
				 operands: {
						 (self spvIdFor: (sims at: #cond) third).
						 (ctx at: #trueBlock) id.
						 (ctx at: #falseBlock) id })
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitSelectionMergeIn: ctx [
	"The merge block joins the two arms in a phi and then carries the kernel's own work —
	 the store that writes the chosen value. compileSelection: never had to emit that
	 block's ops, because a value-returning function only returns the phi."

	| sims blk phiReg phiId |
	sims := ctx at: #sims.
	blk := ctx at: #mergeBlock.
	phiReg := sims at: #phiReg.
	phiId := module newId.
	regMap at: phiReg put: phiId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opPhi
			 resultType: (self spvTypeFor: ((sims at: #typeMap) at: phiReg)) id
			 resultId: phiId
			 operands: {
					 (ctx at: #trueValue).
					 (ctx at: #trueBlock) id.
					 (ctx at: #falseValue).
					 (ctx at: #falseBlock) id }).
	self
		emitRegOps: (sims at: #merge) first
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	blk isTerminated ifFalse: [
		blk terminate:
			(SpvInstruction opcode: SpvOpcode opReturn operands: #( )) ]
]

{ #category : 'emitting' }
PVSPIRVEmitter >> emitStorageBufferParam: aParam at: paramIndex binding: binding decoratedArrays: decoratedRtas [
	"A buffer parameter becomes a Block-decorated struct holding one runtime array. The
	 type registry hands back the same runtime array for two parameters of the same
	 element type, and a type may carry each decoration once only, hence decoratedRtas."

	| elemType rtaT structT pStructT bVar |
	elemType := aParam type = #bufferOf_i32
		            ifTrue: [ module typeRegistry intType: 32 signed: true ]
		            ifFalse: [ module typeRegistry floatType: 32 ].
	rtaT := module typeRegistry runtimeArrayType: elemType.
	structT := module typeRegistry structType: { rtaT }.
	pStructT := module typeRegistry
		            pointerType: SpvStorageClass storageBuffer
		            type: structT.
	(decoratedRtas includes: rtaT id) ifFalse: [
		module
			addDecoration: rtaT id
			decoration: SpvDecoration arrayStride
			literals: { self class storageBufferArrayStride }.
		module
			addDecoration: structT id
			decoration: SpvDecoration block
			literals: #( ).
		module
			addMemberDecoration: structT id
			member: self class bufferMemberIndex
			decoration: SpvDecoration offset
			literals: { self class bufferMemberOffset }.
		decoratedRtas add: rtaT id ].
	bVar := SpvGlobalVariable new
		        id: module newId;
		        type: pStructT;
		        storageClass: SpvStorageClass storageBuffer;
		        yourself.
	module addGlobalVariable: bVar.
	regMap at: paramIndex put: bVar id.
	module
		addDecoration: bVar id
		decoration: SpvDecoration descriptorSet
		literals: { self class computeDescriptorSet }.
	module
		addDecoration: bVar id
		decoration: SpvDecoration binding
		literals: { binding }.
	^ bVar
]

{ #category : 'emit' }
PVSPIRVEmitter >> emitVecExtract: index op: op block: blk [
    | resultTypeId resultId |
    resultTypeId := (self spvTypeFor: #f32) id.
    resultId := module newId.
    regMap at: op result put: resultId.
    blk addInstruction: (SpvInstruction
        opcode: SpvOpcode opCompositeExtract
        resultType: resultTypeId
        resultId: resultId
        operands: { (self spvIdFor: op inputs first). index })
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> emitWorkItemComponent: compIdx op: op block: blk [
| varId u32T v3u32T loadId resultId |
varId := self spvIdFor: op inputs first.
u32T := module typeRegistry intType: 32 signed: false.
v3u32T := module typeRegistry vectorType: u32T count: 3.
loadId := module newId.
blk addInstruction: (SpvInstruction
    opcode: SpvOpcode opLoad
    resultType: v3u32T id
    resultId: loadId
    operands: { varId }).
resultId := module newId.
regMap at: op result put: resultId.
blk addInstruction: (SpvInstruction
    opcode: SpvOpcode opCompositeExtract
    resultType: u32T id
    resultId: resultId
    operands: { loadId. compIdx })
]

{ #category : 'emitting' }
PVSPIRVEmitter >> emitWorkItemInputForParam: paramIndex [
	"The WorkItem parameter is not a buffer: it reads the GlobalInvocationId built-in, a
	 three-component unsigned vector in the Input storage class."

	| u32T v3u32T pV3u32InT gVar |
	u32T := module typeRegistry intType: 32 signed: false.
	v3u32T := module typeRegistry vectorType: u32T count: 3.
	pV3u32InT := module typeRegistry
		             pointerType: SpvStorageClass input
		             type: v3u32T.
	gVar := SpvGlobalVariable new
		        id: module newId;
		        type: pV3u32InT;
		        storageClass: SpvStorageClass input;
		        yourself.
	module addGlobalVariable: gVar.
	regMap at: paramIndex put: gVar id.
	module
		addDecoration: gVar id
		decoration: SpvDecoration builtIn
		literals: { SpvBuiltIn globalInvocationId }.
	^ gVar
]

{ #category : 'private' }
PVSPIRVEmitter >> ensureGlslExtInstSet [
    "Import GLSL.std.450 once; return its result id."
    ^ module importExtInstSet: GlslStd450 instSetName
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> finishComputeMain: spvFunc interfaces: interfaces [
	"Register the entry point and its local size. Answer the serialised module."

	module addFunction: spvFunc.
	module addEntryPoint: spvFunc executionModel: SpvExecutionModel glCompute name: 'main' interfaces: interfaces asArray.
	module addExecutionMode: spvFunc mode: SpvExecutionMode localSize literals: self class defaultLocalSize.
	^ module serialize
]

{ #category : 'initialization' }
PVSPIRVEmitter >> initialize [
    super initialize.
    regMap := Dictionary new.
    outputVarIds := OrderedCollection new.
    isVoidMain := false
]

{ #category : 'accessing' }
PVSPIRVEmitter >> isVoidMain [ ^ isVoidMain
]

{ #category : 'accessing' }
PVSPIRVEmitter >> isVoidMain: x [ isVoidMain := x
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> newComputeMainFunction [
	"A void main() with no parameters, the shape every compute entry point has. The
	 kernel's parameters are interface variables, not function parameters."

	| voidT voidFnT |
	voidT := module typeRegistry voidType.
	voidFnT := module typeRegistry functionType: voidT paramTypes: #().
	^ SpvFunction new
		  id: module newId;
		  returnType: voidT;
		  functionType: voidFnT;
		  module: module;
		  initialize;
		  yourself
]

{ #category : 'type mapping' }
PVSPIRVEmitter >> opcodeFor: spirvOpSymbol [
	^ SpvOpcode perform: spirvOpSymbol asString uncapitalized asSymbol
]

{ #category : 'accessing' }
PVSPIRVEmitter >> outputVarIds [ ^ outputVarIds
]

{ #category : 'accessing' }
PVSPIRVEmitter >> outputVarIds: x [ outputVarIds := x
]

{ #category : 'compiling' }
PVSPIRVEmitter >> prependLoopPhisIn: ctx [
	"A phi must be the first instruction of its block, and both its incoming ids are only
	 known once the preheader and the latch are emitted, so the phis go in last and go in
	 at the front."

	| phis typeMap hdr |
	phis := ctx at: #phis.
	typeMap := (ctx at: #sims) at: #typeMap.
	hdr := ctx at: #headerBlock.
	(phis at: #indices) doWithIndex: [ :k :n |
		| phiType |
		phiType := typeMap
			           at: ((phis at: #latch) at: k)
			           ifAbsent: [ typeMap at: ((phis at: #init) at: k) ].
		hdr prependInstruction: (SpvInstruction
				 opcode: SpvOpcode opPhi
				 resultType: (self spvTypeFor: phiType) id
				 resultId: ((ctx at: #phiResult) at: n)
				 operands: {
						 ((ctx at: #phiInit) at: n).
						 (ctx at: #preBlock) id.
						 ((ctx at: #phiLatch) at: n).
						 (ctx at: #latchBlock) id }) ]
]

{ #category : 'accessing' }
PVSPIRVEmitter >> regMap [
^ regMap
]

{ #category : 'accessing' }
PVSPIRVEmitter >> regMap: d [
	regMap := d
]

{ #category : 'private' }
PVSPIRVEmitter >> spvIdFor: regId [
	^ regMap at: regId ifAbsent: [ PVTypeError signal: 'No SpvId for register: ' , regId printString ]
]

{ #category : 'private' }
PVSPIRVEmitter >> spvTypeFor: typeSymbol [
    typeSymbol = #f32  ifTrue: [ ^ module typeRegistry floatType: 32 ].
    typeSymbol = #i32  ifTrue: [ ^ module typeRegistry intType: 32 signed: true ].
    typeSymbol = #u32  ifTrue: [ ^ module typeRegistry intType: 32 signed: false ].
    typeSymbol = #bool ifTrue: [ ^ module typeRegistry boolType ].
    typeSymbol = #void ifTrue: [ ^ module typeRegistry voidType ].
    typeSymbol = #vec2 ifTrue: [ ^ module typeRegistry vectorType: (module typeRegistry floatType: 32) count: 2 ].
    typeSymbol = #vec3 ifTrue: [ ^ module typeRegistry vectorType: (module typeRegistry floatType: 32) count: 3 ].
    typeSymbol = #vec4 ifTrue: [ ^ module typeRegistry vectorType: (module typeRegistry floatType: 32) count: 4 ].
    typeSymbol = #bvec3 ifTrue: [ ^ module typeRegistry vectorType: module typeRegistry boolType count: 3 ].
    typeSymbol = #mat4 ifTrue: [
        | vec4T | vec4T := module typeRegistry vectorType: (module typeRegistry floatType: 32) count: 4.
        ^ module typeRegistry matrixType: vec4T columns: 4 ].
    PVTypeError signal: 'Unknown type: ' , typeSymbol
]
