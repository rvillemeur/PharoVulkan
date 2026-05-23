Class {
	#name : 'PVSPIRVEmitter',
	#superclass : 'SpvModuleEmitter',
	#instVars : [
		'annotation',
		'regMap'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'compiling' }
PVSPIRVEmitter class >> compileKernel: regOps typeMap: typeMap annotation: ann selectorTable: st name: funcName [
	| em |
	em := self new initialize.
	em annotation: ann.
	em module addCapability: 1.    "Shader"
	em module setAddressingModel: 0 memoryModel: 1.    "Logical GLSL450"
	em emitKernelFunction: regOps typeMap: typeMap selectorTable: st name: funcName.
	^ em module serialize
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

{ #category : 'emitting' }
PVSPIRVEmitter >> emitRegOp: op typeMap: typeMap selectorTable: st block: blk [
	| opc |
	op opcode = #const ifTrue: [
		| constId |
		op literal isFloat
			ifTrue: [ constId := module constantPool constantFloat32: op literal asFloat ]
			ifFalse: [ constId := module constantPool constantInt32: op literal ].
		regMap at: op result put: constId.
		^ self ].
	op opcode = #move ifTrue: [
		regMap at: op result put: (self spvIdFor: op inputs first).
		^ self ].
	op opcode = #send ifTrue: [
		| mapping resultTypeId recvId resultId instr |
		mapping := st at: op literal receiverType: (typeMap at: op inputs first).
		mapping ifNil: [ PVTypeError signal: 'No mapping for ' , op literal ].
		opc := self opcodeFor: mapping spirvOp.
		resultTypeId := (self spvTypeFor: mapping resultTypeSymbol) id.
		recvId := self spvIdFor: op inputs first.
		resultId := module newId.
		regMap at: op result put: resultId.
		instr := SpvInstruction
			opcode: opc
			resultType: resultTypeId
			resultId: resultId
			operands: (op inputs collect: [ :r | self spvIdFor: r ]).
		blk addInstruction: instr.
		^ self ].
	op opcode = #return ifTrue: [
		blk terminate: (SpvInstruction
			opcode: SpvOpcode opReturnValue
			resultType: nil
			resultId: nil
			operands: { self spvIdFor: op inputs first }).
		^ self ].
	op opcode = #returnSelf ifTrue: [
		blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()).
		^ self ].
	"#self, #pop, #storeTemp with no result: skip"
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

{ #category : 'initialize-release' }
PVSPIRVEmitter >> initialize [
	super initialize.
	regMap := Dictionary new
]

{ #category : 'type mapping' }
PVSPIRVEmitter >> opcodeFor: spirvOpSymbol [
	^ SpvOpcode perform: spirvOpSymbol asString uncapitalized asSymbol
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

{ #category : 'type mapping' }
PVSPIRVEmitter >> spvTypeFor: typeSymbol [
	typeSymbol = #f32  ifTrue: [ ^ module typeRegistry floatType: 32 ].
	typeSymbol = #i32  ifTrue: [ ^ module typeRegistry intType: 32 signed: true ].
	typeSymbol = #u32  ifTrue: [ ^ module typeRegistry intType: 32 signed: false ].
	typeSymbol = #bool ifTrue: [ ^ module typeRegistry boolType ].
	typeSymbol = #void ifTrue: [ ^ module typeRegistry voidType ].
	PVTypeError signal: 'Unknown type: ' , typeSymbol
]
