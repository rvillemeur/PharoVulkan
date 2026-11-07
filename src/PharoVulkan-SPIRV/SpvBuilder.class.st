"
High-level facade over SpvModule. Provides one method per frequently-used
SPIR-V instruction and drives type/constant allocation automatically.
Create via SpvBuilder new (creates a fresh SpvModule internally).
Key methods: module, currentBlock:, emitFunction:, emitLoad:, emitStore:at:,
emitAccessChain:indices:, emitBinaryOp:left:right:type:, emitReturn, emitReturnValue:.
"
Class {
	#name : 'SpvBuilder',
	#superclass : 'Object',
	#instVars : [
		'module',
		'currentBlock'
	],
	#category : 'PharoVulkan-SPIRV-Builder',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Builder'
}

{ #category : 'instance creation' }
SpvBuilder class >> on: aSpvModule [
	"A builder over a module its caller already owns. PVSPIRVEmitter builds its module
	 itself and still needs the instructions whose operand assembly lives here, and two
	 producers of the same operand order would drift apart."

	^ self new setModule: aSpvModule; yourself
]

{ #category : 'module' }
SpvBuilder >> addCapability: aSymbol [
    module addCapability: aSymbol
]

{ #category : 'module' }
SpvBuilder >> addDecoration: id decoration: dec literals: lits [
    module addDecoration: id decoration: dec literals: lits
]

{ #category : 'module' }
SpvBuilder >> addEntryPoint: func executionModel: model name: name interfaces: ifaces [
    module addEntryPoint: func executionModel: model name: name interfaces: ifaces
]

{ #category : 'module' }
SpvBuilder >> addExecutionMode: func mode: mode literals: lits [
    module addExecutionMode: func mode: mode literals: lits
]

{ #category : 'module' }
SpvBuilder >> addGlobalVariable: aPointerType storageClass: sc [
    "Create, register, and return a SpvGlobalVariable."
    | v |
    v := SpvGlobalVariable on: module type: aPointerType storageClass: sc.
    module addGlobalVariable: v.
    ^ v
]

{ #category : 'module' }
SpvBuilder >> addMemberDecoration: sid member: idx decoration: dec literals: lits [
    module addMemberDecoration: sid member: idx decoration: dec literals: lits
]

{ #category : 'module header' }
SpvBuilder >> beShaderModule [
	"Asked of the builder, so a caller that holds one never reaches past it to the module.
	 See SpvModule >> beShaderModule for what the three facts are."

	module beShaderModule
]

{ #category : 'inspecting' }
SpvBuilder >> blockRows [
	"One row a block of the current function, in the order the module serialises them. Every
	 column is read from the blocks themselves, so a block added in another order or a merge
	 that stopped being emitted shows up here."

	currentBlock ifNil: [ ^ #(  ) ].
	^ currentBlock function blocks withIndexCollect: [ :each :index |
		  Dictionary newFrom: {
				  (#position -> index).
				  (#label -> each id).
				  (#instructions -> each instructions size).
				  (#merge -> (self mergeDescriptionOf: each)).
				  (#terminator -> (self terminatorNameOf: each)) } ]
]

{ #category : 'accessing' }
SpvBuilder >> constants [       ^ module constantPool
]

{ #category : 'accessing' }
SpvBuilder >> currentBlock [    ^ currentBlock
]

{ #category : 'accessing' }
SpvBuilder >> currentBlock: b [ currentBlock := b
]

{ #category : 'instructions' }
SpvBuilder >> emitAccessChain: baseId type: ptrType indices: indexIds [
    "Emit OpAccessChain. Returns result id."
    | id ops |
    id := module newId.
    ops := OrderedCollection with: baseId.
    indexIds do: [:i | ops add: i].
    currentBlock addInstruction: (SpvInstruction
        opcode: SpvOpcode opAccessChain
        resultType: ptrType id
        resultId: id
        operands: ops asArray).
    ^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitBinaryOp: opcode left: leftId right: rightId type: aType [
    "Emit a binary arithmetic or logical instruction. Returns result id."
    | id |
    id := module newId.
    currentBlock addInstruction: (SpvInstruction
        opcode: opcode
        resultType: aType id
        resultId: id
        operands: { leftId. rightId }).
    ^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitBranch: targetBlockId [
    currentBlock terminate: (SpvInstruction
        opcode: SpvOpcode opBranch operands: { targetBlockId })
]

{ #category : 'instructions' }
SpvBuilder >> emitCompositeConstruct: anArray type: aType [
	"A vector or a matrix built from its components in order, which is how a matrix reaches a
	 multiply without a constant composite in the pool."

	| id |
	id := module newId.
	currentBlock addInstruction: (SpvInstruction
			 opcode: SpvOpcode opCompositeConstruct
			 resultType: aType id
			 resultId: id
			 operands: anArray).
	^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitCompositeExtract: compositeId type: aType indices: anArray [
    "Emit OpCompositeExtract. Returns result id."
    | id ops |
    id := module newId.
    ops := OrderedCollection with: compositeId.
    anArray do: [:i | ops add: i].
    currentBlock addInstruction: (SpvInstruction
        opcode: SpvOpcode opCompositeExtract
        resultType: aType id
        resultId: id
        operands: ops asArray).
    ^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitConvertUToF: valueId fromType: intType toType: floatType [
    | id |
    id := module newId.
    currentBlock addInstruction: (SpvInstruction
        opcode: SpvOpcode opConvertUToF
        resultType: floatType id
        resultId: id
        operands: { valueId }).
    ^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitCooperativeMatrixLoad: aPointerId type: aMatrixType layout: aLayout stride: aStrideId [
	"Emit OpCooperativeMatrixLoadKHR. The layout is an id of a constant, not a literal, and
	 the stride counts elements between consecutive rows under the row-major layout. Every
	 invocation of the scope must reach this instruction, so it belongs in uniform control
	 flow. Returns result id."

	| id |
	id := module newId.
	currentBlock addInstruction: (SpvInstruction
			 opcode: SpvOpcode opCooperativeMatrixLoadKHR
			 resultType: aMatrixType id
			 resultId: id
			 operands: {
					 aPointerId.
					 (module constantPool constantUInt32: aLayout).
					 aStrideId }).
	^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitCooperativeMatrixMulAdd: aMatrixId by: bMatrixId into: accumulatorId type: aMatrixType [
	"Emit OpCooperativeMatrixMulAddKHR: A times B added to the accumulator, answering a new
	 accumulator. The result type is the accumulator's type, which is what makes an f16 by
	 f16 product accumulate in f32. Returns result id."

	| id |
	id := module newId.
	currentBlock addInstruction: (SpvInstruction
			 opcode: SpvOpcode opCooperativeMatrixMulAddKHR
			 resultType: aMatrixType id
			 resultId: id
			 operands: {
					 aMatrixId.
					 bMatrixId.
					 accumulatorId }).
	^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitCooperativeMatrixStore: aMatrixId at: aPointerId layout: aLayout stride: aStrideId [
	"Emit OpCooperativeMatrixStoreKHR. The operand order is the pointer first and the matrix
	 second, the other way round from this method's own reading, which is why the instruction
	 is built here rather than at each call site. No result id."

	currentBlock addInstruction: (SpvInstruction
			 opcode: SpvOpcode opCooperativeMatrixStoreKHR
			 operands: {
					 aPointerId.
					 aMatrixId.
					 (module constantPool constantUInt32: aLayout).
					 aStrideId })
]

{ #category : 'instructions' }
SpvBuilder >> emitExtInst: aSetId op: anInstructionNumber operands: anArray type: aType [
	"An instruction of an imported extended set, GLSL.std.450 in this project. The set id is
	 what importGLSL answers and the number is a constant of GlslStd450."

	| id |
	id := module newId.
	currentBlock addInstruction: (SpvInstruction
			 opcode: SpvOpcode opExtInst
			 resultType: aType id
			 resultId: id
			 operands: { aSetId. anInstructionNumber } , anArray).
	^ id
]

{ #category : 'emitting' }
SpvBuilder >> emitIf: aConditionId then: aBlock [
	"A structured selection: the body runs where the condition holds and the merge block is
	 current afterwards. The merge block is added after the body, because the blocks the body
	 adds have to precede the block they all branch to."

	| function thenBlock mergeId mergeBlock |
	function := currentBlock function.
	mergeId := module newId.
	currentBlock addInstruction: (SpvInstruction
			 opcode: SpvOpcode opSelectionMerge
			 operands: {
					 mergeId.
					 SpvSelectionControl none }).
	thenBlock := function addBlock.
	currentBlock terminate: (SpvInstruction
			 opcode: SpvOpcode opBranchConditional
			 operands: {
					 aConditionId.
					 thenBlock id.
					 mergeId }).
	self currentBlock: thenBlock.
	aBlock value.
	currentBlock isTerminated ifFalse: [ self emitBranch: mergeId ].
	mergeBlock := function addBlockWithId: mergeId.
	self currentBlock: mergeBlock.
	^ mergeBlock
]

{ #category : 'instructions' }
SpvBuilder >> emitLoad: ptrId type: aType [
    "Emit OpLoad. Returns result id."
    | id |
    id := module newId.
    currentBlock addInstruction: (SpvInstruction
        opcode: SpvOpcode opLoad
        resultType: aType id
        resultId: id
        operands: { ptrId }).
    ^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitReturn [
    currentBlock terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #())
]

{ #category : 'instructions' }
SpvBuilder >> emitSelect: aConditionId ifTrue: aTrueId ifFalse: aFalseId type: aType [
	"OpSelect: both values are computed and one is kept, so the block does not divide and no
	 merge is declared. A kernel whose invocations must stay together uses this where Pharo
	 would send ifTrue:ifFalse:."

	| id |
	id := module newId.
	currentBlock addInstruction: (SpvInstruction
			 opcode: SpvOpcode opSelect
			 resultType: aType id
			 resultId: id
			 operands: {
					 aConditionId.
					 aTrueId.
					 aFalseId }).
	^ id
]

{ #category : 'instructions' }
SpvBuilder >> emitStore: valueId at: ptrId [
    "Emit OpStore. No result id."
    currentBlock addInstruction: (SpvInstruction
        opcode: SpvOpcode opStore
        operands: { ptrId. valueId })
]

{ #category : 'instructions' }
SpvBuilder >> emitUnaryOp: anOpcode operand: anId type: aType [
	"A conversion or a negation: one operand, one result. emitConvertUToF:fromType:toType:
	 beside this is the one conversion the emitter asked for before this existed."

	| id |
	id := module newId.
	currentBlock addInstruction: (SpvInstruction
			 opcode: anOpcode
			 resultType: aType id
			 resultId: id
			 operands: { anId }).
	^ id
]

{ #category : 'emitting' }
SpvBuilder >> emitVariableOfType: aType [
	"A function-scope variable, answered as its pointer id. SPIR-V asks that every OpVariable
	 of a function stand in that function's first block, so the declaration is prepended
	 there whatever block is current, and nothing is stored into it here."

	| function pointerType id |
	function := currentBlock function.
	pointerType := self types
		               pointerType: SpvStorageClass function
		               type: aType.
	id := module newId.
	function blocks first prependInstruction: (SpvInstruction
			 opcode: SpvOpcode opVariable
			 resultType: pointerType id
			 resultId: id
			 operands: { SpvStorageClass function }).
	^ id
]

{ #category : 'emitting' }
SpvBuilder >> emitWhile: aConditionBlock do: aBodyBlock [
	"A structured loop: the condition block is emitted in the loop header and answers the id
	 the header branches on, the body runs while it holds, and the merge block is current
	 afterwards. The continue target and the merge block are added once the body is emitted,
	 because every block the body adds has to precede them."

	| function header body mergeId continueId condition mergeBlock |
	function := currentBlock function.
	header := function addBlock.
	self emitBranch: header id.
	self currentBlock: header.
	mergeId := module newId.
	continueId := module newId.
	condition := aConditionBlock value.
	header addInstruction: (SpvInstruction
			 opcode: SpvOpcode opLoopMerge
			 operands: {
					 mergeId.
					 continueId.
					 SpvLoopControl none }).
	body := function addBlock.
	header terminate: (SpvInstruction
			 opcode: SpvOpcode opBranchConditional
			 operands: {
					 condition.
					 body id.
					 mergeId }).
	self currentBlock: body.
	aBodyBlock value.
	currentBlock isTerminated ifFalse: [ self emitBranch: continueId ].
	self currentBlock: (function addBlockWithId: continueId).
	self emitBranch: header id.
	mergeBlock := function addBlockWithId: mergeId.
	self currentBlock: mergeBlock.
	^ mergeBlock
]

{ #category : 'module' }
SpvBuilder >> importGLSL [
    "Import GLSL.std.450 extended instruction set. Returns its result id."
    ^ module importExtInstSet: 'GLSL.std.450'
]

{ #category : 'initialization' }
SpvBuilder >> initialize [

	super initialize.
	module := SpvModule new
]

{ #category : 'inspecting' }
SpvBuilder >> inspectorBlocks: aBuilder [
	"The block order of the function being built, which is the one thing a structured
	 emitter can get wrong without any instruction being wrong."

	<inspectorPresentationOrder: 10 title: 'Blocks'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'At' evaluated: [ :each |
					   (each at: #position) printString ]);
		  addColumn: (SpStringTableColumn title: 'Label' evaluated: [ :each |
					   (each at: #label) printString ]);
		  addColumn: (SpStringTableColumn title: 'Instructions' evaluated: [ :each |
					   (each at: #instructions) printString ]);
		  addColumn: (SpStringTableColumn title: 'Merge' evaluated: [ :each |
					   each at: #merge ]);
		  addColumn: (SpStringTableColumn title: 'Terminator' evaluated: [ :each |
					   each at: #terminator ]);
		  items: self blockRows;
		  yourself
]

{ #category : 'inspecting' }
SpvBuilder >> mergeDescriptionOf: aBlock [
	"The merge instruction a block carries, named after the constant that answers its opcode
	 and followed by the blocks it names. The last operand is the control mask, which is a
	 hint and not a target, so it is left out."

	| merge |
	merge := aBlock instructions
		         detect: [ :each |
			         each opcode = SpvOpcode opSelectionMerge or: [
				         each opcode = SpvOpcode opLoopMerge ] ]
		         ifNone: [ nil ].
	merge ifNil: [ ^ '' ].
	^ String streamContents: [ :stream |
		  stream nextPutAll: (SpvOpcode nameOfOpcode: merge opcode).
		  merge operands allButLast do: [ :each |
			  stream
				  nextPut: Character space;
				  print: each ] ]
]

{ #category : 'accessing' }
SpvBuilder >> module [          ^ module
]

{ #category : 'functions' }
SpvBuilder >> newFunction: aReturnType [
    "Create and register a new SpvFunction with void return type. Returns it."
    | ft func |
    ft := module typeRegistry functionType: aReturnType paramTypes: #().
    func := SpvFunction on: module returnType: aReturnType functionType: ft.
    module addFunction: func.
    ^ func
]

{ #category : 'module' }
SpvBuilder >> setMemoryModel: addrModel memoryModel: memModel [
    module setAddressingModel: addrModel memoryModel: memModel
]

{ #category : 'initialization' }
SpvBuilder >> setModule: aSpvModule [
	module := aSpvModule
]

{ #category : 'inspecting' }
SpvBuilder >> terminatorNameOf: aBlock [
	^ aBlock terminator
		  ifNil: [ 'none' ]
		  ifNotNil: [ :terminator |
			  (SpvOpcode nameOfOpcode: terminator opcode) asString ]
]

{ #category : 'accessing' }
SpvBuilder >> types [           ^ module typeRegistry
]

{ #category : 'barriers' }
SpvBuilder >> workgroupBarrier [
	"Answers the module's one barrier definition, so that a kernel built through the builder
	 and a kernel compiled from Pharo source emit the same instruction."

	^ module workgroupBarrierInstruction
]
