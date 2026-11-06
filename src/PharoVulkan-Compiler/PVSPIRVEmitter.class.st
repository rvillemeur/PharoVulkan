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
		'isVoidMain',
		'demandBuiltIns',
		'sharedVariables'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Pipeline'
}

{ #category : 'constants' }
PVSPIRVEmitter class >> bufferElementTypes [
	"The element type symbol each kernel buffer type holds. One source for the type the
	 emitter declares, the stride it decorates the runtime array with, the capabilities a
	 half buffer needs and the parameter types PVKernelCompiler takes for compute."
	 
	"The three role types hold the same elements as a plain buffer and differ only in
	 which cooperative matrix operand they feed. The role belongs to the type because a
	 cooperative matrix type is fixed to one role in SPIR-V, so a load has to know the
	 role before it knows anything else."

	^ Dictionary newFrom: {
			  (#bufferOf_f32 -> #f32).
			  (#bufferOf_i32 -> #i32).
			  (#bufferOf_f16 -> #f16).
			  (#matrixABufferOf_f16 -> #f16).
			  (#matrixBBufferOf_f16 -> #f16).
			  (#accumulatorBufferOf_f32 -> #f32) }
]

{ #category : 'constants' }
PVSPIRVEmitter class >> bufferMemberIndex [
	"A kernel buffer struct holds exactly one member: the runtime array."
	^ 0
]

{ #category : 'constants' }
PVSPIRVEmitter class >> bufferMemberOffset [
	^ 0
]

{ #category : 'reflecting' }
PVSPIRVEmitter class >> capabilitiesDeclaredFor: aBufferTypeSymbol [
	"The capabilities a buffer of that element type adds to a module, asked by letting a
	 throwaway emitter declare them rather than by repeating the list."

	| em |
	em := self new.
	em declareCapabilitiesFor: aBufferTypeSymbol.
	^ em module capabilities asArray
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
	mod beShaderModule.
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
	em module beShaderModule.
	interfaces := em emitComputeInterfaces.
	sims := self computeLoopSimulations: loopNode annotation: ann selectorTable: st.
	phis := self loopPhisFrom: (sims at: #preheader) latch: (sims at: #latch).
	^ em
		  finishComputeMain: (em emitComputeLoopFrom: sims phis: phis selectorTable: st)
		  interfaces: interfaces
]

{ #category : 'compiling - compute' }
PVSPIRVEmitter class >> compileComputeKernelNestedLoop: nestedNode annotation: ann selectorTable: st [
	"A compute entry point whose body is an outer loop holding an inner loop. Like the
	 single-loop entry point this takes no typeMap: the types have to be inferred over the
	 register numbering the per-block simulations produce."

	| em interfaces sims innerPhis outerPhis |
	em := self new.
	em annotation: ann.
	em module beShaderModule.
	interfaces := em emitComputeInterfaces.
	sims := self
		        computeNestedLoopSimulations: nestedNode
		        annotation: ann
		        selectorTable: st.
	innerPhis := self
		             loopPhisFrom: (sims at: #innerPreheader)
		             latch: (sims at: #innerBody).
	outerPhis := self
		             nestedOuterPhisFrom: (sims at: #preheader)
		             innerMerge: (sims at: #innerMerge)
		             innerPhis: innerPhis.
	^ em
		  finishComputeMain: (em
				   emitComputeNestedLoopFrom: sims
				   outerPhis: outerPhis
				   innerPhis: innerPhis
				   selectorTable: st)
		  interfaces: interfaces
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileComputeKernelSelection: selNode annotation: ann selectorTable: st [
	"A compute entry point whose body is one ifTrue:ifFalse:. Takes no typeMap for the
	 reason given in compileComputeKernelLoop:."

	| em interfaces sims |
	em := self new.
	em annotation: ann.
	em module beShaderModule.
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
	em module beShaderModule.
	em emitKernelFunction: regOps typeMap: typeMap selectorTable: st name: funcName.
	^ em module serialize
]

{ #category : 'compilation' }
PVSPIRVEmitter class >> compileLoop: loopNode annotation: ann typeMap: typeMap selectorTable: st [
	| em mod paramTempDefs preheaderSim headerSim latchSim exitSim phiVarIndices preInitRegs latchResultRegs phiInitSpvIds phiLatchSpvIds phiSpvIds funcType paramTypes retType spvFunc preBlk hdrBlk latchBlk exitBlk condSpvId retSpvId phiType |
	em := self new.
	em annotation: ann.
	mod := em module.
	mod beShaderModule.
	paramTempDefs := Dictionary new.
	ann params doWithIndex: [ :p :i |
		| pId |
		pId := mod newId.
		em regMap at: i put: pId.
		paramTempDefs at: i - 1 put: i.
		typeMap at: i put: p type ].
	preheaderSim := PVBlockSimulator new simulateBlock: loopNode preheaderBlock initialTempDefs: paramTempDefs startingNextReg: ann params size + 1.
	headerSim := PVBlockSimulator new simulateBlock: loopNode headerBlock initialTempDefs: preheaderSim tempDefs startingNextReg: preheaderSim nextReg.
	latchSim := PVBlockSimulator new simulateBlock: loopNode bodyBlocks first initialTempDefs: preheaderSim tempDefs startingNextReg: headerSim nextReg.
	exitSim := PVBlockSimulator new simulateBlock: loopNode exitBlock initialTempDefs: preheaderSim tempDefs startingNextReg: latchSim nextReg initialStack: (preheaderSim stack).
	phiVarIndices := OrderedCollection new.
	preInitRegs := Dictionary new.
	latchResultRegs := Dictionary new.
	preheaderSim tempDefs keysAndValuesDo: [ :k :preReg |
		| latchReg |
		latchReg := latchSim tempDefs at: k ifAbsent: [ preReg ].
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
	em emitRegOps: preheaderSim regOps typeMap: typeMap selectorTable: st block: preBlk.
	phiInitSpvIds := Dictionary new.
	phiVarIndices do: [ :k | phiInitSpvIds at: k put: (em spvIdFor: (preInitRegs at: k)) ].
	preBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { hdrBlk id }).
	phiSpvIds := Dictionary new.
	phiVarIndices do: [ :k |
		| phiId |
		phiId := mod newId.
		phiSpvIds at: k put: phiId.
		em regMap at: (preInitRegs at: k) put: phiId ].
	em emitRegOps: headerSim regOps typeMap: typeMap selectorTable: st block: hdrBlk.
	condSpvId := em spvIdFor: headerSim resultReg.
	hdrBlk addInstruction: (SpvInstruction opcode: SpvOpcode opLoopMerge resultType: nil resultId: nil operands: { exitBlk id. latchBlk id. SpvLoopControl none }).
	hdrBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional resultType: nil resultId: nil operands: { condSpvId. latchBlk id. exitBlk id }).
	em emitRegOps: latchSim regOps typeMap: typeMap selectorTable: st block: latchBlk.
	phiLatchSpvIds := Dictionary new.
	phiVarIndices do: [ :k | phiLatchSpvIds at: k put: (em spvIdFor: (latchResultRegs at: k)) ].
	latchBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { hdrBlk id }).
	phiType := em spvTypeFor: ann params first type.
	phiVarIndices do: [ :k |
		hdrBlk prependInstruction: (SpvInstruction opcode: SpvOpcode opPhi resultType: phiType id resultId: (phiSpvIds at: k) operands: { (phiInitSpvIds at: k). preBlk id. (phiLatchSpvIds at: k). latchBlk id }) ].
	em emitRegOps: exitSim regOps typeMap: typeMap selectorTable: st block: exitBlk.
	retSpvId := em spvIdFor: exitSim resultReg.
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
	mod beShaderModule.
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
	condRegOps := condSim regOps.
	condNextReg := condSim nextReg.
	condReg := condSim resultReg.
	trueSim := PVBlockSimulator new simulateBlock: selNode trueBlocks first
		initialTempDefs: condSim tempDefs startingNextReg: condNextReg.
	trueRegOps := trueSim regOps.
	falseSim := PVBlockSimulator new simulateBlock: selNode falseBlocks first
		initialTempDefs: condSim tempDefs startingNextReg: condNextReg.
	falseRegOps := falseSim regOps.
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
		resultType: nil resultId: nil operands: { mergeBlkSpv id. SpvSelectionControl none }).
	entryBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional
		resultType: nil resultId: nil operands: { condSpvId. trueBlkSpv id. falseBlkSpv id }).
	condRegMapSave := em regMap copy.
	em emitRegOps: trueRegOps typeMap: typeMap selectorTable: st block: trueBlkSpv.
	trueResultReg := trueSim resultReg.
	trueResultSpvId := em spvIdFor: trueResultReg.
	trueBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeBlkSpv id }).
	em regMap: condRegMapSave copy.
	em emitRegOps: falseRegOps typeMap: typeMap selectorTable: st block: falseBlkSpv.
	falseResultSpvId := em spvIdFor: falseSim resultReg.
	falseBlkSpv terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeBlkSpv id }).
	phiType := typeMap at: (trueSim resultReg) ifAbsent: [ ann params first type ].
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
	mod beShaderModule.
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
	mod beShaderModule.
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
	condRegOps := condSim regOps.
	condTempDefs := condSim tempDefs.
	condReg := condSim resultReg.
	condNextReg := condSim nextReg.
	condRegOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: entryBlk ].
	condSpvId := em spvIdFor: condReg.
	trueSpvBlk := spvFunc addBlock.
	falseSpvBlk := spvFunc addBlock.
	mergeSpvBlk := spvFunc addBlock.
	entryBlk addInstruction: (SpvInstruction opcode: SpvOpcode opSelectionMerge resultType: nil resultId: nil operands: { mergeSpvBlk id. SpvSelectionControl none }).
	entryBlk terminate: (SpvInstruction opcode: SpvOpcode opBranchConditional resultType: nil resultId: nil operands: { condSpvId. trueSpvBlk id. falseSpvBlk id }).
	trueSim := PVBlockSimulator new simulateBlock: selNode trueBlocks first initialTempDefs: condTempDefs startingNextReg: condNextReg.
	trueRegOps := trueSim regOps.
	condRegMapSave := em regMap copy.
	trueRegOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: trueSpvBlk ].
	trueSpvBlk isTerminated ifFalse: [ trueSpvBlk terminate: (SpvInstruction opcode: SpvOpcode opBranch resultType: nil resultId: nil operands: { mergeSpvBlk id }) ].
	em regMap: condRegMapSave copy.
	falseSim := PVBlockSimulator new simulateBlock: selNode falseBlocks first initialTempDefs: condTempDefs startingNextReg: condNextReg.
	falseRegOps := falseSim regOps.
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
	headerSim := PVBlockSimulator new simulateBlock: loopNode headerBlock initialTempDefs: preheaderSim tempDefs startingNextReg: preheaderSim nextReg.
	latchSim := PVBlockSimulator new simulateBlock: loopNode bodyBlocks first initialTempDefs: preheaderSim tempDefs startingNextReg: headerSim nextReg.
	exitSim := PVBlockSimulator new simulateBlock: loopNode exitBlock initialTempDefs: preheaderSim tempDefs startingNextReg: latchSim nextReg initialStack: (preheaderSim stack).
	^ Dictionary newFrom: {
		  #preheader -> preheaderSim.
		  #header -> headerSim.
		  #latch -> latchSim.
		  #exit -> exitSim.
		  #typeMap -> (self inferTypesOver: { preheaderSim. headerSim. latchSim. exitSim } annotation: ann selectorTable: st) second }
]

{ #category : 'compiling - compute' }
PVSPIRVEmitter class >> computeNestedLoopSimulations: nestedNode annotation: ann selectorTable: st [
	"Simulate the seven blocks of a nested compute loop with one shared register
	 numbering, and infer the types over that numbering. Every block inside a loop is
	 simulated from the definitions that reach the loop's entry, not from the block before
	 it: the registers the entry left are the ones the emitter redirects onto the phi
	 results. The exit block inherits the preheader's stack residue, because the preheader
	 may leave a value the code after the loop pops."

	| preheaderSim outerHeaderSim innerPreSim innerHeaderSim innerBodySim innerMergeSim exitSim |
	preheaderSim := PVBlockSimulator new
		                simulateBlock: nestedNode preheaderBlock
		                initialTempDefs: (self paramTempDefsFor: ann)
		                startingNextReg: ann params size + 1.
	outerHeaderSim := PVBlockSimulator new
		                  simulateBlock: nestedNode headerBlock
		                  initialTempDefs: preheaderSim tempDefs
		                  startingNextReg: preheaderSim nextReg.
	innerPreSim := PVBlockSimulator new
		               simulateBlock: nestedNode innerPreheaderBlock
		               initialTempDefs: preheaderSim tempDefs
		               startingNextReg: outerHeaderSim nextReg.
	innerHeaderSim := PVBlockSimulator new
		                  simulateBlock: nestedNode innerHeaderBlock
		                  initialTempDefs: innerPreSim tempDefs
		                  startingNextReg: innerPreSim nextReg.
	innerBodySim := PVBlockSimulator new
		                simulateBlock: nestedNode innerBodyBlocks first
		                initialTempDefs: innerPreSim tempDefs
		                startingNextReg: innerHeaderSim nextReg.
	innerMergeSim := PVBlockSimulator new
		                 simulateBlock: nestedNode innerMergeBlock
		                 initialTempDefs: innerPreSim tempDefs
		                 startingNextReg: innerBodySim nextReg.
	exitSim := PVBlockSimulator new
		           simulateBlock: nestedNode exitBlock
		           initialTempDefs: preheaderSim tempDefs
		           startingNextReg: innerMergeSim nextReg
		           initialStack: (preheaderSim stack).
	^ Dictionary newFrom: {
			  (#preheader -> preheaderSim).
			  (#outerHeader -> outerHeaderSim).
			  (#innerPreheader -> innerPreSim).
			  (#innerHeader -> innerHeaderSim).
			  (#innerBody -> innerBodySim).
			  (#innerMerge -> innerMergeSim).
			  (#exit -> exitSim).
			  (#typeMap -> (self
				    inferTypesOver: {
						    preheaderSim.
						    outerHeaderSim.
						    innerPreSim.
						    innerHeaderSim.
						    innerBodySim.
						    innerMergeSim.
						    exitSim }
				    annotation: ann
				    selectorTable: st) second) }
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> computeSelectionSimulations: selNode annotation: ann selectorTable: st [
	"Simulate the four blocks of a compute selection with one shared register numbering,
	 and infer the types over that numbering. The phi register is the first register no
	 block defined, and its type is the type of the value the arms produce, which the
	 merge block then consumes."

	| condSim trueSim falseSim mergeSim phiReg inference typeMap |
	condSim := PVBlockSimulator new simulateBlock: selNode condBlock initialTempDefs: (self paramTempDefsFor: ann) startingNextReg: ann params size + 1.
	trueSim := PVBlockSimulator new simulateBlock: selNode trueBlocks first initialTempDefs: condSim tempDefs startingNextReg: condSim nextReg.
	falseSim := PVBlockSimulator new simulateBlock: selNode falseBlocks first initialTempDefs: condSim tempDefs startingNextReg: trueSim nextReg.
	phiReg := falseSim nextReg.
	mergeSim := PVBlockSimulator new simulateBlock: selNode mergeBlock initialTempDefs: condSim tempDefs startingNextReg: phiReg + 1 initialStack: (self selectionMergeStackFrom: condSim phiReg: phiReg).
	inference := self inferTypesOver: { condSim. trueSim. falseSim } annotation: ann selectorTable: st.
	typeMap := inference second.
	typeMap at: phiReg put: (typeMap at: trueSim resultReg ifAbsent: [ typeMap at: falseSim resultReg ]).
	inference first inferAll: mergeSim regOps selectorTable: st.
	^ Dictionary newFrom: {
		  #cond -> condSim.
		  #true -> trueSim.
		  #false -> falseSim.
		  #merge -> mergeSim.
		  #phiReg -> phiReg.
		  #typeMap -> typeMap }
]

{ #category : 'constants' }
PVSPIRVEmitter class >> cooperativeMatrixCapability [
	"CooperativeMatrixKHR = 6022. Read back out of a module spirv-as assembled, not recalled.
	 It may only be declared where the device has the cooperativeMatrix feature enabled."

	^ 6022
]

{ #category : 'constants' }
PVSPIRVEmitter class >> cooperativeMatrixExtensionName [
	"The SPIR-V extension VK_KHR_cooperative_matrix enables. A module declaring the
	 CooperativeMatrixKHR capability must name it."

	^ 'SPV_KHR_cooperative_matrix'
]

{ #category : 'constants' }
PVSPIRVEmitter class >> cooperativeMatrixLayout [
	"Row major, the orientation every buffer in this project is written in."

	^ SpvCooperativeMatrixType rowMajorLayout
]

{ #category : 'constants' }
PVSPIRVEmitter class >> cooperativeMatrixOrder [
	"A kernel must use one of the M, N, K combinations the device reports, exactly. The shape lives
	 on the SPIR-V type that models it, below both this emitter and the hand-built kernel, so a
	 compiled kernel and a hand-built one cannot disagree."

	^ SpvCooperativeMatrixShape canonicalOrder
]

{ #category : 'constants' }
PVSPIRVEmitter class >> cooperativeMatrixScope [
	^ SpvScope subgroup
]

{ #category : 'constants' }
PVSPIRVEmitter class >> cooperativeMatrixStoreElementIndex [
	"A store writes the matrix at the start of its buffer. A kernel that needs an offset
	 would need a two-argument selector, which the DSL does not have."

	^ 0
]

{ #category : 'constants' }
PVSPIRVEmitter class >> cooperativeMatrixValueTypes [
	"The component type and the operand role of each cooperative matrix value type. A
	 matrix type carries its role as an operand, so A, B and the accumulator are three
	 different types even where two of them share a component type."

	^ Dictionary newFrom: {
			  (#coopMatrixA_f16
			   -> { #f16. SpvCooperativeMatrixType matrixAUse }).
			  (#coopMatrixB_f16
			   -> { #f16. SpvCooperativeMatrixType matrixBUse }).
			  (#coopMatrixAccumulator_f32
			   -> { #f32. SpvCooperativeMatrixType matrixAccumulatorUse }) }
]

{ #category : 'constants' }
PVSPIRVEmitter class >> elementTypeOf: aBufferTypeSymbol [
	"Raises rather than defaulting: a wrong element type emits a module that validates and
	 reads the wrong addresses."

	^ self bufferElementTypes
		  at: aBufferTypeSymbol
		  ifAbsent: [
		  PVTypeError signal: 'Unknown buffer type: ' , aBufferTypeSymbol ]
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> emitSelectionKernel: selNode annotation: ann selectorTable: st typeMap: typeMap module: aModule [
	| em paramTypes spvFunc entryBlk trueBlkSpv falseBlkSpv mergeBlkSpv condReg trueReg falseReg condSpvId phiId phiType retType funcType condSimResult condTempDefs |
	em := self new initialize.
	em annotation: ann.
	aModule beShaderModule.
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
	condTempDefs := condSimResult tempDefs.
	condReg := condSimResult resultReg.
	"Infer result type of condReg ops"
	(condSimResult regOps) do: [ :op |
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
	(condSimResult regOps) do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: (PVSelectorTable standard) block: entryBlk ].
	condSpvId := em spvIdFor: condReg.
	entryBlk addInstruction: (SpvInstruction opcode: SpvOpcode opSelectionMerge
		resultType: nil resultId: nil operands: { mergeBlkSpv id. SpvSelectionControl none }).
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

{ #category : 'constants' }
PVSPIRVEmitter class >> float16Capability [
	"Float16 = 9. Core since SPIR-V 1.3, and the module targets 1.5, so no OpExtension
	 accompanies it."

	^ 9
]

{ #category : 'constants' }
PVSPIRVEmitter class >> gridWidthComponent [
	"x component of the NumWorkgroups vector."

	^ 0

]

{ #category : 'constants' }
PVSPIRVEmitter class >> groupNonUniformArithmeticCapability [
	"GroupNonUniformArithmetic = 63, the neighbour of GroupNonUniformVote 62. The add itself
	 needs it; GroupNonUniform alone only buys the ballot and election instructions."

	^ 63
]

{ #category : 'constants' }
PVSPIRVEmitter class >> groupNonUniformCapability [
	"GroupNonUniform = 61, the capability every OpGroupNonUniform instruction needs. Core
	 since SPIR-V 1.3, and the module targets 1.5, so no OpExtension accompanies it."

	^ 61
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> inferTypesOver: sims annotation: ann selectorTable: st [
	"One PVTypeInferencer accumulates into a single typeMap across the blocks, so a
	 register defined in one block keeps its type in the next. Answer the inferencer as
	 well, because a caller may have to seed a phi type and then infer one block more."

	| inferencer typeMap |
	inferencer := PVTypeInferencer new initialize annotation: ann.
	typeMap := nil.
	sims do: [ :each | typeMap := inferencer inferAll: each regOps selectorTable: st ].
	^ { inferencer. typeMap }
]

{ #category : 'inspector' }
PVSPIRVEmitter class >> inspectorBufferTypes: aBuilder [
	<inspectorPresentationOrder: 10 title: 'Buffer types'>
	"One row per kernel buffer type. Every column asks the method the emitter itself calls,
	 the capabilities by letting an emitter declare them, so the tab cannot drift from what
	 an emitted module carries."

	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Buffer' evaluated: [ :each | each ]);
		  addColumn: (SpStringTableColumn title: 'Element' evaluated: [ :each |
					   self elementTypeOf: each ]);
		  addColumn: (SpStringTableColumn title: 'Stride' evaluated: [ :each |
					   self storageBufferArrayStrideFor: each ]);
		  addColumn:
			  (SpStringTableColumn title: 'Capabilities' evaluated: [ :each |
					   ', ' join:
						   ((self capabilitiesDeclaredFor: each) collect: [ :one |
							    one printString ]) ]);
		  items: self bufferElementTypes keys asSortedCollection asArray;
		  yourself
]

{ #category : 'inspector' }
PVSPIRVEmitter class >> inspectorCooperativeMatrixTypes: aBuilder [
	<inspectorPresentationOrder: 20 title: 'Cooperative matrix types'>
	"One row per cooperative matrix value type. The component type and the shape are
	 asked of the type an emitter actually builds, not restated, so the tab cannot claim
	 a shape the emitted module does not carry. The shape prints its own role, which is
	 what makes three types out of two component types."

	| emitter |
	emitter := self new.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Value type' evaluated: [ :each | each ]);
		  addColumn: (SpStringTableColumn title: 'Component' evaluated: [ :each |
					   (emitter cooperativeMatrixTypeFor: each) componentType key printString ]);
		  addColumn: (SpStringTableColumn title: 'Shape' evaluated: [ :each |
					   (emitter cooperativeMatrixTypeFor: each) shape printString ]);
		  items: self cooperativeMatrixValueTypes keys asSortedCollection asArray;
		  yourself
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
	preheaderSim tempDefs keysAndValuesDo: [ :k :preReg |
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

{ #category : 'compiling - compute' }
PVSPIRVEmitter class >> nestedOuterPhisFrom: preheaderSim innerMerge: innerMergeSim innerPhis: innerPhis [
	"A variable the inner loop carries is carried by the outer loop as well, even though the
	 inner merge block leaves it in the register the outer body was entered with: inside the
	 inner loop that register points at the inner phi, so the outer phi's latch operand
	 resolves to it. Comparing registers alone misses that variable, and in a tiled kernel
	 it is the accumulator. A variable the inner loop declares, on the other hand, does not
	 exist before the outer loop and is carried by the inner loop only."

	| phis |
	phis := self loopPhisFrom: preheaderSim latch: innerMergeSim.
	(innerPhis at: #indices) do: [ :k |
		(((phis at: #indices) includes: k) not and: [
			 preheaderSim tempDefs includesKey: k ]) ifTrue: [
			(phis at: #indices) add: k.
			(phis at: #init) at: k put: (preheaderSim tempDefs at: k).
			(phis at: #latch)
				at: k
				put: (innerMergeSim tempDefs at: k ifAbsent: [
						 preheaderSim tempDefs at: k ]) ] ].
	^ phis
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
PVSPIRVEmitter class >> scalarByteWidths [
	"How many bytes one element of each scalar type occupies in a storage buffer."

	^ Dictionary newFrom: {
			  (#f32 -> 4).
			  (#i32 -> 4).
			  (#f16 -> 2) }
]

{ #category : 'compiling' }
PVSPIRVEmitter class >> selectionMergeStackFrom: condSim phiReg: phiReg [
	"What the merge block consumes is the value the two arms produce, so the phi register
	 sits on top of its stack. Below it is whatever the condition block pushed before the
	 selection, less the condition itself: the simulator never executes the jumpIf that
	 pops it."

	| stack |
	stack := (condSim stack) asOrderedCollection.
	stack isEmpty ifFalse: [ stack removeLast ].
	stack addLast: phiReg.
	^ stack
]

{ #category : 'constants' }
PVSPIRVEmitter class >> sharedElementTypeOf: aSharedTypeSymbol [
	"Raises rather than defaulting: a wrong element type emits a module that validates and
	 reads the wrong addresses."

	^ self sharedElementTypes
		  at: aSharedTypeSymbol
		  ifAbsent: [
		  PVTypeError signal: 'Unknown shared type: ' , aSharedTypeSymbol ]
]

{ #category : 'constants' }
PVSPIRVEmitter class >> sharedElementTypes [
	"The element type symbol each shared array type holds. A shared array is a workgroup
	 tile declared by a <shared:named:count:> pragma, not a buffer: it has no descriptor and
	 the host never binds it. One source for the type the emitter declares, the selector
	 mappings for at: and at:put:, and the parameter types PVKernelCompiler takes for
	 compute."

	^ Dictionary newFrom: {
			  (#sharedOf_f32 -> #f32).
			  (#sharedOf_i32 -> #i32).
			  (#sharedOf_f16 -> #f16) }
]

{ #category : 'constants' }
PVSPIRVEmitter class >> sharedTypeOf: anElementTypeSymbol [
	"The shared array type that holds the element type a <shared:named:count:> pragma
	 names. Raises rather than defaulting, so that a pragma naming an element type the
	 emitter cannot declare is refused at compile time instead of emitting a tile of the
	 wrong element type."

	^ self sharedElementTypes
		  keyAtValue: anElementTypeSymbol
		  ifAbsent: [
		  PVTypeError signal: 'No shared array type for: ' , anElementTypeSymbol ]
]

{ #category : 'constants' }
PVSPIRVEmitter class >> storageBuffer16BitAccessCapability [
	"StorageBuffer16BitAccess = 4433. Float16 alone covers the arithmetic; holding halves
	 in a storage buffer needs this one as well."

	^ 4433
]

{ #category : 'constants' }
PVSPIRVEmitter class >> storageBufferArrayStrideFor: aBufferTypeSymbol [
	"A runtime array declares the byte distance between two elements, which follows the
	 element type: a half is two bytes where a float or an int is four."

	^ self scalarByteWidths at: (self elementTypeOf: aBufferTypeSymbol)
]

{ #category : 'constants' }
PVSPIRVEmitter class >> vulkanMemoryModelCapability [
	"VulkanMemoryModel = 5345. spirv-val refuses a module that declares Shader and
	 CooperativeMatrixKHR without it, so the two travel together."

	^ 5345
]

{ #category : 'accessing' }
PVSPIRVEmitter >> annotation [
^ annotation
]

{ #category : 'accessing' }
PVSPIRVEmitter >> annotation: ann [
	annotation := ann
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> branchTo: aBlock [
	"The unconditional branch a block that falls through to the next one ends with."

	^ SpvInstruction
		  opcode: SpvOpcode opBranch
		  resultType: nil
		  resultId: nil
		  operands: { aBlock id }
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

{ #category : 'private' }
PVSPIRVEmitter >> bufferElementTypeFor: aBufferTypeSymbol [
	"The buffer declaration, every load and every store ask here, because a module whose
	 three answers disagree declares one array and indexes another."

	^ self spvTypeFor: (self class elementTypeOf: aBufferTypeSymbol)
]

{ #category : 'emitting - phis' }
PVSPIRVEmitter >> captureLatchIdsFor: aLoopLevel [
	"The ids the back edge carries, read at the point the last block of the body has been
	 emitted. For the outer level of a nested loop that point is after the inner loop, so
	 the id of a variable the inner loop carries is the inner phi."

	| phis |
	phis := aLoopLevel at: #phis.
	aLoopLevel
		at: #latchIds
		put: ((phis at: #indices) collect: [ :k |
				 self spvIdFor: ((phis at: #latch) at: k) ])
]

{ #category : 'emitting - cooperative matrix' }
PVSPIRVEmitter >> cooperativeMatrixBuilderOn: aBlock [
	"The three cooperative matrix instructions are assembled in SpvBuilder, whose operand
	 order differs from its own selector order for the store. Two producers of that order
	 would drift apart, so this emitter borrows the one that is already tested."

	^ (SpvBuilder on: module)
		  currentBlock: aBlock;
		  yourself
]

{ #category : 'emitting - cooperative matrix' }
PVSPIRVEmitter >> cooperativeMatrixTypeFor: aTypeSymbol [
	"The matrix type a value type symbol names, built from the shape the device reports."

	| description |
	description := self class cooperativeMatrixValueTypes at: aTypeSymbol.
	^ module typeRegistry
		  cooperativeMatrixType: (self spvTypeFor: description first)
		  shape: (SpvCooperativeMatrixShape
				   rows: self class cooperativeMatrixOrder
				   columns: self class cooperativeMatrixOrder
				   scope: self class cooperativeMatrixScope
				   use: description second)
]

{ #category : 'emitting' }
PVSPIRVEmitter >> declareCapabilitiesFor: aBufferTypeSymbol [
	"A half buffer needs Float16 for the arithmetic and StorageBuffer16BitAccess for the
	 array itself. The other element types need nothing beyond Shader."

	(self class elementTypeOf: aBufferTypeSymbol) = #f16 ifFalse: [ ^ self ].
	module addCapability: self class float16Capability.
	module addCapability: self class storageBuffer16BitAccessCapability
]

{ #category : 'emitting - cooperative matrix' }
PVSPIRVEmitter >> declareCooperativeMatrixCapabilities [
	"The capability needs its SPIR-V extension, and spirv-val refuses the capability in a
	 Shader module unless the Vulkan memory model is declared too, which in turn needs the
	 device feature. Declared from the instructions rather than from the module prologue, so
	 a kernel holding no cooperative matrix keeps the GLSL450 memory model."

	module addCapability: self class vulkanMemoryModelCapability.
	module addCapability: self class cooperativeMatrixCapability.
	module addExtension: self class cooperativeMatrixExtensionName.
	module
		setAddressingModel: SpvModule logicalAddressingModel
		memoryModel: SpvModule vulkanMemoryModel
]

{ #category : 'emitting - shared memory' }
PVSPIRVEmitter >> declareSharedCapabilitiesFor: aSharedTypeSymbol [
	"A half tile needs Float16 for the arithmetic. It needs no 16-bit access capability:
	 that one covers storage buffers, and a workgroup tile is not one."

	(self class sharedElementTypeOf: aSharedTypeSymbol) = #f16 ifFalse: [ ^ self ].
	module addCapability: self class float16Capability
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> emitBufferLoad: op typeMap: typeMap block: blk [
| bufVarId idxId recvType elemType ptrType elemPtrId loadId u32Zero |
bufVarId := self spvIdFor: op inputs first.
idxId := self spvIdFor: op inputs second.
recvType := typeMap at: op inputs first.
elemType := self bufferElementTypeFor: recvType.
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
elemType := self bufferElementTypeFor: recvType.
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
	regOps := simResult regOps.
	finalDefs := simResult tempDefs.
	resultReg := simResult resultReg.
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
			(simResult regOps) do: [ :regOp |
				self emitRegOp: regOp typeMap: typeMap selectorTable: st block: spvBlk ].
			"Update regMap from simulation"
			(simResult tempDefs) keysAndValuesDo: [ :k :v | regMap at: k put: v ].
			lastResultReg := simResult resultReg.
			^ lastResultReg ] ].
	^ lastResultReg
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> emitComponent: compIdx ofVariable: varId op: op block: blk [
	"One component of a three-component built-in vector: load the whole vector, then extract.
	 Shared by every built-in read so that the load and the extract cannot disagree about the
	 vector type."

	| loadId resultId u32T |
	u32T := module typeRegistry intType: 32 signed: false.
	loadId := module newId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opLoad
			 resultType: self uvec3Type id
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

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitComputeInterfaces [
	"Create the interface variables of a compute entry point from the annotation: the
	 WorkItem parameter becomes the GlobalInvocationId built-in, a shared parameter becomes
	 a Workgroup tile, and every buffer parameter becomes a storage buffer at descriptor
	 set 0 on the next binding. A tile takes no binding, because the host binds nothing for
	 it. Answer them in declaration order, which is the order the entry point lists them and
	 the order PVComputeKernel binds buffers in. Shared by the three compute entry points,
	 which differ only in what sits between this prologue and OpReturn."

	| interfaces decoratedRtas binding |
	interfaces := OrderedCollection new.
	decoratedRtas := Set new.
	binding := 0.
	annotation params doWithIndex: [ :p :i |
		p type = #workItem
			ifTrue: [ interfaces add: (self emitWorkItemInputForParam: i) ]
			ifFalse: [
				p isShared
					ifTrue: [ interfaces add: (self emitSharedArrayParam: p at: i) ]
					ifFalse: [
						interfaces add: (self
								 emitStorageBufferParam: p
								 at: i
								 binding: binding
								 decoratedArrays: decoratedRtas).
						binding := binding + 1 ] ] ].
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

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitComputeNestedLoopFrom: sims outerPhis: outerPhis innerPhis: innerPhis selectorTable: st [
	"Build the eight blocks of a nested compute loop and answer the function holding them.
	 There is one block more than the graph has, because the outer loop's continue target
	 cannot be the inner loop's merge block."

	| spvFunc ctx |
	spvFunc := self newComputeMainFunction.
	ctx := Dictionary newFrom: {
			       (#sims -> sims).
			       (#outer -> (Dictionary newFrom: { (#phis -> outerPhis) })).
			       (#inner -> (Dictionary newFrom: { (#phis -> innerPhis) })).
			       (#selectorTable -> st).
			       (#preBlock -> spvFunc addBlock).
			       (#outerHeaderBlock -> spvFunc addBlock).
			       (#innerPreBlock -> spvFunc addBlock).
			       (#innerHeaderBlock -> spvFunc addBlock).
			       (#innerBodyBlock -> spvFunc addBlock).
			       (#innerMergeBlock -> spvFunc addBlock).
			       (#outerLatchBlock -> spvFunc addBlock).
			       (#exitBlock -> spvFunc addBlock) }.
	self emitNestedPreheaderIn: ctx.
	self emitNestedOuterHeaderIn: ctx.
	self emitNestedInnerPreheaderIn: ctx.
	self emitNestedInnerHeaderIn: ctx.
	self emitNestedInnerBodyIn: ctx.
	self emitNestedInnerMergeIn: ctx.
	self emitNestedOuterLatchIn: ctx.
	self prependNestedPhisIn: ctx.
	self emitNestedExitIn: ctx.
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

{ #category : 'emitting - cooperative matrix' }
PVSPIRVEmitter >> emitCooperativeMatrixLoad: op resultTypeSymbol: aTypeSymbol typeMap: typeMap block: blk [
	"coopMatLoad: answers the matrix that starts at the element its argument names. The
	 role comes from the buffer's own type, so the load knows which of the three matrix
	 types it is building."

	| pointerId |
	self declareCooperativeMatrixCapabilities.
	pointerId := self
		             pointerInto: (self spvIdFor: op inputs first)
		             ofType: (typeMap at: op inputs first)
		             at: (self spvIdFor: op inputs second)
		             block: blk.
	regMap
		at: op result
		put: ((self cooperativeMatrixBuilderOn: blk)
				 emitCooperativeMatrixLoad: pointerId
				 type: (self cooperativeMatrixTypeFor: aTypeSymbol)
				 layout: self class cooperativeMatrixLayout
				 stride: (module constantPool constantUInt32:
							  self class cooperativeMatrixOrder))
]

{ #category : 'emitting - cooperative matrix' }
PVSPIRVEmitter >> emitCooperativeMatrixMulAdd: op resultTypeSymbol: aTypeSymbol block: blk [
	"coopMatMulAdd: multiplies its receiver by its argument and adds a zero accumulator, so
	 the result is the product alone. The zero is OpConstantNull of the accumulator type:
	 how a matrix is spread over the subgroup is the device's business, so a kernel cannot
	 build a zero matrix out of components."

	| accumulatorType |
	self declareCooperativeMatrixCapabilities.
	accumulatorType := self cooperativeMatrixTypeFor: aTypeSymbol.
	regMap
		at: op result
		put: ((self cooperativeMatrixBuilderOn: blk)
				 emitCooperativeMatrixMulAdd: (self spvIdFor: op inputs first)
				 by: (self spvIdFor: op inputs second)
				 into: (module constantPool constantNullOfType: accumulatorType)
				 type: accumulatorType)
]

{ #category : 'emitting - cooperative matrix' }
PVSPIRVEmitter >> emitCooperativeMatrixStore: op typeMap: typeMap block: blk [
	"coopMatStore: writes its argument into the receiver's buffer, at element zero. The
	 register of the store answers the pointer it wrote through, as the buffer store does."

	| pointerId |
	self declareCooperativeMatrixCapabilities.
	pointerId := self
		             pointerInto: (self spvIdFor: op inputs first)
		             ofType: (typeMap at: op inputs first)
		             at: (module constantPool constantUInt32:
					              self class cooperativeMatrixStoreElementIndex)
		             block: blk.
	(self cooperativeMatrixBuilderOn: blk)
		emitCooperativeMatrixStore: (self spvIdFor: op inputs second)
		at: pointerId
		layout: self class cooperativeMatrixLayout
		stride: (module constantPool constantUInt32: self class cooperativeMatrixOrder).
	regMap at: op result put: pointerId
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
PVSPIRVEmitter >> emitGridWidth: op block: blk [
	"groupCountX times localSizeX. The local size is a literal of this module's execution
	 mode, so the multiplication folds to one OpIMul against a constant."

	| u32T v3u32T loadId groupsX localSizeX resultId |
	u32T := module typeRegistry intType: 32 signed: false.
	v3u32T := module typeRegistry vectorType: u32T count: 3.
	loadId := module newId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opLoad
			 resultType: v3u32T id
			 resultId: loadId
			 operands: { self ensureNumWorkgroupsVariable id }).
	groupsX := module newId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opCompositeExtract
			 resultType: u32T id
			 resultId: groupsX
			 operands: { loadId. self class gridWidthComponent }).
	localSizeX := module constantPool constantUInt32: annotation localSize first.
	resultId := module newId.
	regMap at: op result put: resultId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opIMul
			 resultType: u32T id
			 resultId: resultId
			 operands: { groupsX. localSizeX })
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

{ #category : 'emitting compute' }
PVSPIRVEmitter >> emitLocalInvocationComponent: compIdx op: op block: blk [
	"Reads LocalInvocationId instead of the receiver's variable: the work item parameter is
	 GlobalInvocationId, and asking where an invocation sits inside its workgroup is a
	 question for a different built-in."

	^ self
		  emitComponent: compIdx
		  ofVariable: self ensureLocalInvocationIdVariable id
		  op: op
		  block: blk
]

{ #category : 'compiling' }
PVSPIRVEmitter >> emitLoopExitIn: ctx [
	"The exit block carries the work after the loop, which for a compute kernel is the
	 store through the output buffer, then returns."

	| sims blk |
	sims := ctx at: #sims.
	blk := ctx at: #exitBlock.
	self
		emitRegOps: (sims at: #exit) regOps
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
		emitRegOps: (sims at: #header) regOps
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
						 SpvLoopControl none });
		terminate: (SpvInstruction
				 opcode: SpvOpcode opBranchConditional
				 resultType: nil
				 resultId: nil
				 operands: {
						 (self spvIdFor: (sims at: #header) resultReg).
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
		emitRegOps: (sims at: #latch) regOps
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
		emitRegOps: (sims at: #preheader) regOps
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

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedBlock: aSimKey in: ctx into: aBlockKey [
	"Emit one block of a nested loop: the register ops the simulation of that block
	 produced, into the SPIR-V block the context holds under that key."

	^ self
		  emitRegOps: ((ctx at: #sims) at: aSimKey) regOps
		  typeMap: ((ctx at: #sims) at: #typeMap)
		  selectorTable: (ctx at: #selectorTable)
		  block: (ctx at: aBlockKey)
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedExitIn: ctx [
	"The work after the outer loop, which for a compute kernel is the store through the
	 output buffer. The outer phi results are put back in front of the registers the loop
	 was entered with first: the inner loop redirected the same registers at its own phis,
	 and an inner phi does not dominate this block."

	| blk |
	blk := ctx at: #exitBlock.
	self redirectToPhiResultsFor: (ctx at: #outer).
	self emitNestedBlock: #exit in: ctx into: #exitBlock.
	blk isTerminated ifFalse: [
		blk terminate:
			(SpvInstruction opcode: SpvOpcode opReturn operands: #( )) ]
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedInnerBodyIn: ctx [
	"The inner body is also the inner continue target: it ends with the back edge to the
	 inner header, and the registers it leaves the inner variables in are the latch side of
	 the inner phis."

	self emitNestedBlock: #innerBody in: ctx into: #innerBodyBlock.
	self captureLatchIdsFor: (ctx at: #inner).
	(ctx at: #innerBodyBlock) terminate:
		(self branchTo: (ctx at: #innerHeaderBlock))
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedInnerHeaderIn: ctx [
	"The inner test. The inner loop's continue target is its body, as in a single loop."

	| blk |
	blk := ctx at: #innerHeaderBlock.
	self emitNestedBlock: #innerHeader in: ctx into: #innerHeaderBlock.
	blk
		addInstruction: (SpvInstruction
				 opcode: SpvOpcode opLoopMerge
				 resultType: nil
				 resultId: nil
				 operands: {
						 (ctx at: #innerMergeBlock) id.
						 (ctx at: #innerBodyBlock) id.
						 SpvLoopControl none });
		terminate: (SpvInstruction
				 opcode: SpvOpcode opBranchConditional
				 resultType: nil
				 resultId: nil
				 operands: {
						 (self spvIdFor: ((ctx at: #sims) at: #innerHeader) resultReg).
						 (ctx at: #innerBodyBlock) id.
						 (ctx at: #innerMergeBlock) id })
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedInnerMergeIn: ctx [
	"Where the inner loop leaves to, and the rest of the outer body: in the bytecode this
	 block carries the outer loop's step. The outer latch ids are read here, after the inner
	 loop, so that a variable the inner loop carries is taken from the inner phi."

	self emitNestedBlock: #innerMerge in: ctx into: #innerMergeBlock.
	self captureLatchIdsFor: (ctx at: #outer).
	(ctx at: #innerMergeBlock) terminate:
		(self branchTo: (ctx at: #outerLatchBlock))
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedInnerPreheaderIn: ctx [
	"The outer loop's body up to the inner loop, which is the inner loop's preheader. It
	 names the inner phi results, and from here on the registers the outer body was entered
	 with point at them rather than at the outer phis."

	self emitNestedBlock: #innerPreheader in: ctx into: #innerPreBlock.
	self reservePhiResultsFor: (ctx at: #inner).
	(ctx at: #innerPreBlock) terminate:
		(self branchTo: (ctx at: #innerHeaderBlock))
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedOuterHeaderIn: ctx [
	"The outer test. OpLoopMerge names the block the loop leaves to and the continue
	 target, and must come immediately before the branch that leaves the block."

	| blk |
	blk := ctx at: #outerHeaderBlock.
	self emitNestedBlock: #outerHeader in: ctx into: #outerHeaderBlock.
	blk
		addInstruction: (SpvInstruction
				 opcode: SpvOpcode opLoopMerge
				 resultType: nil
				 resultId: nil
				 operands: {
						 (ctx at: #exitBlock) id.
						 (ctx at: #outerLatchBlock) id.
						 SpvLoopControl none });
		terminate: (SpvInstruction
				 opcode: SpvOpcode opBranchConditional
				 resultType: nil
				 resultId: nil
				 operands: {
						 (self spvIdFor: ((ctx at: #sims) at: #outerHeader) resultReg).
						 (ctx at: #innerPreBlock) id.
						 (ctx at: #exitBlock) id })
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedOuterLatchIn: ctx [
	"The outer loop's continue target holds nothing but the back edge. It exists because a
	 block may not be the merge block of one construct and the continue target of another,
	 and the block the inner loop merges into is where the outer body ends."

	(ctx at: #outerLatchBlock) terminate:
		(self branchTo: (ctx at: #outerHeaderBlock))
]

{ #category : 'emitting - compute' }
PVSPIRVEmitter >> emitNestedPreheaderIn: ctx [
	"Runs once, before the outer loop. Its last act is to name the outer phi results, so
	 that every block of the loop reads the phi and not the value from before it."

	self emitNestedBlock: #preheader in: ctx into: #preBlock.
	self reservePhiResultsFor: (ctx at: #outer).
	(ctx at: #preBlock) terminate:
		(self branchTo: (ctx at: #outerHeaderBlock))
]

{ #category : 'emitting' }
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
        mapping spirvOp = #sharedLoad       ifTrue: [ self emitSharedLoad: op typeMap: typeMap block: blk. ^ self ].
        mapping spirvOp = #sharedStore      ifTrue: [ self emitSharedStore: op typeMap: typeMap block: blk. ^ self ].
        mapping spirvOp = #coopMatrixLoad    ifTrue: [ self emitCooperativeMatrixLoad: op resultTypeSymbol: mapping resultTypeSymbol typeMap: typeMap block: blk. ^ self ].
        mapping spirvOp = #coopMatrixMulAdd  ifTrue: [ self emitCooperativeMatrixMulAdd: op resultTypeSymbol: mapping resultTypeSymbol block: blk. ^ self ].
        mapping spirvOp = #coopMatrixStore   ifTrue: [ self emitCooperativeMatrixStore: op typeMap: typeMap block: blk. ^ self ].
        mapping spirvOp = #workgroupBarrier ifTrue: [ self emitWorkgroupBarrier: op block: blk. ^ self ].
        mapping spirvOp = #workItemX        ifTrue: [ self emitWorkItemComponent: 0 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemY        ifTrue: [ self emitWorkItemComponent: 1 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemZ        ifTrue: [ self emitWorkItemComponent: 2 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemLocalX   ifTrue: [ self emitLocalInvocationComponent: 0 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemLocalY   ifTrue: [ self emitLocalInvocationComponent: 1 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemLocalZ   ifTrue: [ self emitLocalInvocationComponent: 2 op: op block: blk. ^ self ].
        mapping spirvOp = #workItemGridWidth ifTrue: [ self emitGridWidth: op block: blk. ^ self ].
        mapping spirvOp = #compositeConstruct ifTrue: [ self emitCompositeConstruct: op typeMap: typeMap selectorTable: st block: blk. ^ self ].
        mapping spirvOp = #vecExtractX      ifTrue: [ self emitVecExtract: 0 op: op block: blk. ^ self ].
        mapping spirvOp = #vecExtractY      ifTrue: [ self emitVecExtract: 1 op: op block: blk. ^ self ].
        mapping spirvOp = #vecExtractZ      ifTrue: [ self emitVecExtract: 2 op: op block: blk. ^ self ].
        mapping spirvOp = #vecExtractW      ifTrue: [ self emitVecExtract: 3 op: op block: blk. ^ self ].
        mapping spirvOp = #subgroupReduceSum ifTrue: [ self emitSubgroupReduceSum: op resultTypeSymbol: mapping resultTypeSymbol block: blk. ^ self ].
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
		resultType: nil resultId: nil operands: { mergeSpvBlk id. SpvSelectionControl none }).
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
PVSPIRVEmitter >> emitSelectionArm: armKey into: blockKey valueKey: valueKey in: ctx [
	"One arm of the selection: its own work, then the branch to the merge block. The id of
	 the value it produces is kept under valueKey for the merge phi."

	| sims blk |
	sims := ctx at: #sims.
	blk := ctx at: blockKey.
	self
		emitRegOps: (sims at: armKey) regOps
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	ctx at: valueKey put: (self spvIdFor: (sims at: armKey) resultReg).
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
		emitRegOps: (sims at: #cond) regOps
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
						 SpvSelectionControl none });
		terminate: (SpvInstruction
				 opcode: SpvOpcode opBranchConditional
				 resultType: nil
				 resultId: nil
				 operands: {
						 (self spvIdFor: (sims at: #cond) resultReg).
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
		emitRegOps: (sims at: #merge) regOps
		typeMap: (sims at: #typeMap)
		selectorTable: (ctx at: #selectorTable)
		block: blk.
	blk isTerminated ifFalse: [
		blk terminate:
			(SpvInstruction opcode: SpvOpcode opReturn operands: #( )) ]
]

{ #category : 'emitting - shared memory' }
PVSPIRVEmitter >> emitSharedArrayParam: aParam at: paramIndex [
	"A shared parameter becomes one Workgroup variable holding a fixed-size array. It
	 carries no descriptor set and no binding, because the host binds nothing for it: the
	 workgroup owns the storage for the life of its invocations. It still has to reach the
	 entry point's interface list, which is why it is answered and kept."

	| elemType arrayT pArrayT sVar |
	self declareSharedCapabilitiesFor: aParam type.
	elemType := self sharedElementTypeFor: aParam type.
	arrayT := module typeRegistry
		          arrayType: elemType
		          length: aParam count.
	pArrayT := module typeRegistry
		           pointerType: SpvStorageClass workgroup
		           type: arrayT.
	sVar := SpvGlobalVariable new
		        id: module newId;
		        type: pArrayT;
		        storageClass: SpvStorageClass workgroup;
		        yourself.
	module addGlobalVariable: sVar.
	regMap at: paramIndex put: sVar id.
	sharedVariables add: sVar.
	^ sVar
]

{ #category : 'emitting - shared memory' }
PVSPIRVEmitter >> emitSharedLoad: op typeMap: typeMap block: blk [
	"One index only in the access chain, unlike a buffer load: a tile is a bare array, not a
	 struct holding one."

	| tileVarId idxId recvType elemType ptrType elemPtrId loadId |
	tileVarId := self spvIdFor: op inputs first.
	idxId := self spvIdFor: op inputs second.
	recvType := typeMap at: op inputs first.
	elemType := self sharedElementTypeFor: recvType.
	ptrType := module typeRegistry
		           pointerType: SpvStorageClass workgroup
		           type: elemType.
	elemPtrId := module newId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opAccessChain
			 resultType: ptrType id
			 resultId: elemPtrId
			 operands: {
					 tileVarId.
					 idxId }).
	loadId := module newId.
	regMap at: op result put: loadId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opLoad
			 resultType: elemType id
			 resultId: loadId
			 operands: { elemPtrId })
]

{ #category : 'emitting - shared memory' }
PVSPIRVEmitter >> emitSharedStore: op typeMap: typeMap block: blk [
	"One index only in the access chain, unlike a buffer store: a tile is a bare array, not a
	 struct holding one."

	| tileVarId idxId valId recvType elemType ptrType elemPtrId |
	tileVarId := self spvIdFor: op inputs first.
	idxId := self spvIdFor: op inputs second.
	valId := self spvIdFor: op inputs third.
	recvType := typeMap at: op inputs first.
	elemType := self sharedElementTypeFor: recvType.
	ptrType := module typeRegistry
		           pointerType: SpvStorageClass workgroup
		           type: elemType.
	elemPtrId := module newId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opAccessChain
			 resultType: ptrType id
			 resultId: elemPtrId
			 operands: {
					 tileVarId.
					 idxId }).
	blk addInstruction:
		(SpvInstruction opcode: SpvOpcode opStore operands: {
				 elemPtrId.
				 valId }).
	regMap at: op result put: elemPtrId
]

{ #category : 'emitting' }
PVSPIRVEmitter >> emitStorageBufferParam: aParam at: paramIndex binding: binding decoratedArrays: decoratedRtas [
	"A buffer parameter becomes a Block-decorated struct holding one runtime array. The
	 type registry hands back the same runtime array for two parameters of the same
	 element type, and a type may carry each decoration once only, hence decoratedRtas."

	| elemType rtaT structT pStructT bVar |
	self declareCapabilitiesFor: aParam type.
	elemType := self bufferElementTypeFor: aParam type.
	rtaT := module typeRegistry runtimeArrayType: elemType.
	structT := module typeRegistry structType: { rtaT }.
	pStructT := module typeRegistry
		            pointerType: SpvStorageClass storageBuffer
		            type: structT.
	(decoratedRtas includes: rtaT id) ifFalse: [
		module
			addDecoration: rtaT id
			decoration: SpvDecoration arrayStride
			literals: { self class storageBufferArrayStrideFor: aParam type }.
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
		decoration: SpvDecoration bindingDecoration
		literals: { binding }.
	^ bVar
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> emitSubgroupReduceSum: op resultTypeSymbol: aTypeSymbol block: blk [
	"Adds the value every lane of the subgroup holds and delivers the total to all of them.
	 The execution scope is an id of a constant rather than a literal, so the module declares
	 it like any other constant, while the group operation beside it is a literal. Both
	 capabilities are declared here rather than at module set-up, because a kernel that never
	 reduces must not ask the driver for them."

	| scopeId resultId elemType |
	module addCapability: self class groupNonUniformCapability.
	module addCapability: self class groupNonUniformArithmeticCapability.
	scopeId := module constantPool constantUInt32: SpvScope subgroup.
	elemType := self spvTypeFor: aTypeSymbol.
	resultId := module newId.
	regMap at: op result put: resultId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opGroupNonUniformFAdd
			 resultType: elemType id
			 resultId: resultId
			 operands: {
					 scopeId.
					 SpvGroupOperation reduce.
					 (self spvIdFor: op inputs first) })
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
	"The work item parameter stands for the GlobalInvocationId variable, so the component
	 comes from the receiver's own variable."

	^ self
		  emitComponent: compIdx
		  ofVariable: (self spvIdFor: op inputs first)
		  op: op
		  block: blk
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

{ #category : 'emitting - shared memory' }
PVSPIRVEmitter >> emitWorkgroupBarrier: op block: blk [
	"The barrier answers nothing, so the register the send writes stands for the receiver.
	 A kernel that used the value of a barrier send would be refused by type inference
	 before reaching here."

	blk addInstruction: module workgroupBarrierInstruction.
	regMap at: op result put: (self spvIdFor: op inputs first)
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> ensureBuiltIn: aBuiltInNumber [
	"An input built-in that only the kernel body asks for, created on first use and kept by
	 built-in number so two sends share one variable. Every one of them has to reach the
	 entry point's interface list, which is what keeping them here is for: a module that
	 reads a built-in the entry point does not list is invalid."

	^ demandBuiltIns at: aBuiltInNumber ifAbsentPut: [
		  | var |
		  var := SpvGlobalVariable new
			         id: module newId;
			         type: (module typeRegistry
					          pointerType: SpvStorageClass input
					          type: self uvec3Type);
			         storageClass: SpvStorageClass input;
			         yourself.
		  module addGlobalVariable: var.
		  module
			  addDecoration: var id
			  decoration: SpvDecoration builtIn
			  literals: { aBuiltInNumber }.
		  var ]
]

{ #category : 'private' }
PVSPIRVEmitter >> ensureGlslExtInstSet [
    "Import GLSL.std.450 once; return its result id."
    ^ module importExtInstSet: GlslStd450 instSetName
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> ensureLocalInvocationIdVariable [
	"Where the invocation sits inside its workgroup. Created on first use like the grid
	 built-in, since a kernel that never addresses shared memory has no reason to read it."

	^ self ensureBuiltIn: SpvBuiltIn localInvocationId
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> ensureNumWorkgroupsVariable [
	"The NumWorkgroups built-in is created on first use, because only the kernel body says
	 whether the kernel asks for the grid at all."

	^ self ensureBuiltIn: SpvBuiltIn numWorkgroups
]

{ #category : 'emitting compute' }
PVSPIRVEmitter >> finishComputeMain: spvFunc interfaces: interfaces [
	"Register the entry point and its local size. A kernel that asked for the grid geometry
	 or for its position in the workgroup created a built-in variable while its body was
	 emitted, and SPIR-V wants every module-scope variable the entry point touches in the
	 interface list, so those join the declared parameters here. They are added in id order
	 so that compiling the same method twice answers the same bytes."

	| allInterfaces |
	module addFunction: spvFunc.
	allInterfaces := interfaces asOrderedCollection.
	allInterfaces addAll:
		(demandBuiltIns values asSortedCollection: [ :a :b | a id <= b id ]).
	module
		addEntryPoint: spvFunc
		executionModel: SpvExecutionModel glCompute
		name: 'main'
		interfaces: allInterfaces asArray.
	module
		addExecutionMode: spvFunc
		mode: SpvExecutionMode localSize
		literals: annotation localSize.
	^ module serialize
]

{ #category : 'initialization' }
PVSPIRVEmitter >> initialize [
	super initialize.
	regMap := Dictionary new.
	outputVarIds := OrderedCollection new.
	demandBuiltIns := Dictionary new.
	sharedVariables := OrderedCollection new.
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

{ #category : 'emitting - cooperative matrix' }
PVSPIRVEmitter >> pointerInto: aBufferVarId ofType: aBufferTypeSymbol at: anIndexId block: blk [
	"The pointer to one element of a buffer, which is what a cooperative matrix load or
	 store addresses: the instruction reads or writes a whole matrix from there, using the
	 stride to find each row."

	| elemType ptrType pointerId |
	elemType := self bufferElementTypeFor: aBufferTypeSymbol.
	ptrType := module typeRegistry
		           pointerType: SpvStorageClass storageBuffer
		           type: elemType.
	pointerId := module newId.
	blk addInstruction: (SpvInstruction
			 opcode: SpvOpcode opAccessChain
			 resultType: ptrType id
			 resultId: pointerId
			 operands: {
					 aBufferVarId.
					 (module constantPool constantUInt32: self class bufferMemberIndex).
					 anIndexId }).
	^ pointerId
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

{ #category : 'emitting-nested-loop' }
PVSPIRVEmitter >> prependNestedPhisIn: ctx [
	"Both headers take their phis once every block that feeds them is emitted. The inner
	 phis come from the inner preheader and the inner body; the outer phis come from the
	 preheader and the outer latch, which is the block the back edge leaves from."

	| typeMap |
	typeMap := (ctx at: #sims) at: #typeMap.
	(ctx at: #inner)
		at: #header put: (ctx at: #innerHeaderBlock);
		at: #preBlock put: (ctx at: #innerPreBlock);
		at: #latchBlock put: (ctx at: #innerBodyBlock).
	(ctx at: #outer)
		at: #header put: (ctx at: #outerHeaderBlock);
		at: #preBlock put: (ctx at: #preBlock);
		at: #latchBlock put: (ctx at: #outerLatchBlock).
	self prependPhisFor: (ctx at: #inner) typeMap: typeMap.
	self prependPhisFor: (ctx at: #outer) typeMap: typeMap
]

{ #category : 'emitting-nested-loop' }
PVSPIRVEmitter >> prependPhisFor: aLoopLevel typeMap: typeMap [
	"A phi must be the first instruction of its block, and both its incoming ids are only
	 known once the body is emitted, so the phis go in last and go in at the front. The
	 three blocks a phi names are read off the level, which is what the caller filled in
	 once it knew which block the back edge leaves from."

	| phis hdr preBlk latchBlk |
	phis := aLoopLevel at: #phis.
	hdr := aLoopLevel at: #header.
	preBlk := aLoopLevel at: #preBlock.
	latchBlk := aLoopLevel at: #latchBlock.
	(phis at: #indices) doWithIndex: [ :k :n |
		| phiType |
		phiType := typeMap
			           at: ((phis at: #latch) at: k)
			           ifAbsent: [ typeMap at: ((phis at: #init) at: k) ].
		hdr prependInstruction: (SpvInstruction
				 opcode: SpvOpcode opPhi
				 resultType: (self spvTypeFor: phiType) id
				 resultId: ((aLoopLevel at: #resultIds) at: n)
				 operands: {
						 ((aLoopLevel at: #initIds) at: n).
						 preBlk id.
						 ((aLoopLevel at: #latchIds) at: n).
						 latchBlk id }) ]
]

{ #category : 'emitting - phis' }
PVSPIRVEmitter >> redirectToPhiResultsFor: aLoopLevel [
	"Point the registers the level was entered with at its phi results. The exit block asks
	 for this again after the inner loop has redirected the same registers at its own phis:
	 an inner phi does not dominate the outer loop's merge block, and the value that leaves
	 the outer loop is the outer phi."

	| phis |
	phis := aLoopLevel at: #phis.
	(phis at: #indices) doWithIndex: [ :k :n |
		regMap
			at: ((phis at: #init) at: k)
			put: ((aLoopLevel at: #resultIds) at: n) ]
]

{ #category : 'accessing' }
PVSPIRVEmitter >> regMap [
^ regMap
]

{ #category : 'accessing' }
PVSPIRVEmitter >> regMap: d [
	regMap := d
]

{ #category : 'emitting - phis' }
PVSPIRVEmitter >> reservePhiResultsFor: aLoopLevel [
	"Name the phi results of one loop level and point the registers the level was entered
	 with at them, so that every block inside the loop reads the phi rather than the value
	 from before the loop. The init ids are read first, because the redirection overwrites
	 the entries they come from."

	| phis |
	phis := aLoopLevel at: #phis.
	aLoopLevel
		at: #initIds
		put: ((phis at: #indices) collect: [ :k |
				 self spvIdFor: ((phis at: #init) at: k) ]).
	aLoopLevel
		at: #resultIds
		put: ((phis at: #indices) collect: [ :k | module newId ]).
	self redirectToPhiResultsFor: aLoopLevel
]

{ #category : 'emitting - shared memory' }
PVSPIRVEmitter >> sharedElementTypeFor: aSharedTypeSymbol [
	"The tile declaration, every load and every store ask here, because a module whose
	 three answers disagree declares one array and indexes another."

	^ self spvTypeFor: (self class sharedElementTypeOf: aSharedTypeSymbol)
]

{ #category : 'private' }
PVSPIRVEmitter >> spvIdFor: regId [
	^ regMap at: regId ifAbsent: [ PVTypeError signal: 'No SpvId for register: ' , regId printString ]
]

{ #category : 'private' }
PVSPIRVEmitter >> spvTypeFor: typeSymbol [
    (self class cooperativeMatrixValueTypes includesKey: typeSymbol) ifTrue: [
        ^ self cooperativeMatrixTypeFor: typeSymbol ].
    typeSymbol = #f32  ifTrue: [ ^ module typeRegistry floatType: 32 ].
    typeSymbol = #f16  ifTrue: [ ^ module typeRegistry floatType: 16 ].
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

{ #category : 'type mapping' }
PVSPIRVEmitter >> uvec3Type [
	"The type of every invocation built-in: three unsigned 32-bit components. The registry
	 deduplicates, so asking for it costs a lookup and cannot drift from the type the rest
	 of the module uses."

	^ module typeRegistry
		  vectorType: (module typeRegistry intType: 32 signed: false)
		  count: 3
]
