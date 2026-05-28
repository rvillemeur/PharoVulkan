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

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileComputeKernel: regOps annotation: ann typeMap: typeMap selectorTable: st [
	| em mod u32T v3u32T pV3u32InT voidT voidFnT spvFunc blk interfaces binding decoratedRtas |
	em := self new.
	em annotation: ann.
	mod := em module.
	mod addCapability: 1.
	mod setAddressingModel: 0 memoryModel: 1.
	u32T := mod typeRegistry intType: 32 signed: false.
	v3u32T := mod typeRegistry vectorType: u32T count: 3.
	pV3u32InT := mod typeRegistry pointerType: SpvStorageClass input type: v3u32T.
	interfaces := OrderedCollection new.
	decoratedRtas := Set new.
	binding := 0.
	ann params doWithIndex: [ :p :i |
		p type = #workItem ifTrue: [
			| gVar |
			gVar := SpvGlobalVariable new id: mod newId; type: pV3u32InT; storageClass: SpvStorageClass input; yourself.
			mod addGlobalVariable: gVar.
			interfaces add: gVar.
			em regMap at: i put: gVar id.
			mod addDecoration: gVar id decoration: SpvDecoration builtIn literals: { SpvBuiltIn globalInvocationId }
		] ifFalse: [
			| elemType rtaT structT pStructT bVar |
			elemType := p type = #bufferOf_i32
				ifTrue: [ mod typeRegistry intType: 32 signed: true ]
				ifFalse: [ mod typeRegistry floatType: 32 ].
			rtaT := mod typeRegistry runtimeArrayType: elemType.
			structT := mod typeRegistry structType: { rtaT }.
			pStructT := mod typeRegistry pointerType: SpvStorageClass storageBuffer type: structT.
			(decoratedRtas includes: rtaT id) ifFalse: [
				mod addDecoration: rtaT id decoration: SpvDecoration arrayStride literals: { 4 }.
				mod addDecoration: structT id decoration: SpvDecoration block literals: #().
				mod addMemberDecoration: structT id member: 0 decoration: SpvDecoration offset literals: { 0 }.
				decoratedRtas add: rtaT id ].
			bVar := SpvGlobalVariable new id: mod newId; type: pStructT; storageClass: SpvStorageClass storageBuffer; yourself.
			mod addGlobalVariable: bVar.
			interfaces add: bVar.
			em regMap at: i put: bVar id.
			mod addDecoration: bVar id decoration: SpvDecoration descriptorSet literals: { 0 }.
			mod addDecoration: bVar id decoration: SpvDecoration binding literals: { binding }.
			binding := binding + 1 ] ].
	voidT := mod typeRegistry voidType.
	voidFnT := mod typeRegistry functionType: voidT paramTypes: #().
	spvFunc := SpvFunction new id: mod newId; returnType: voidT; functionType: voidFnT; module: mod; initialize; yourself.
	blk := spvFunc addBlock.
	regOps do: [ :op | em emitRegOp: op typeMap: typeMap selectorTable: st block: blk ].
	blk isTerminated ifFalse: [ blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()) ].
	mod addFunction: spvFunc.
	mod addEntryPoint: spvFunc executionModel: SpvExecutionModel glCompute name: 'main' interfaces: interfaces asArray.
	mod addExecutionMode: spvFunc mode: SpvExecutionMode localSize literals: #(64 1 1).
	^ mod serialize
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
PVSPIRVEmitter class >> compileVertexShader: regOps annotation: ann typeMap: typeMap selectorTable: st [
    ^ self compileShaderKernel: regOps annotation: ann typeMap: typeMap selectorTable: st
        executionModel: SpvExecutionModel vertex
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

{ #category : 'private' }
PVSPIRVEmitter >> ensureGlslExtInstSet [
    "Import GLSL.std.450 once; return its result id."
    ^ module importExtInstSet: GlslStd450 instSetName
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
