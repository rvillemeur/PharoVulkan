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
SpvBuilder >> emitReturnValue: valueId [
    currentBlock terminate: (SpvInstruction
        opcode: SpvOpcode opReturnValue operands: { valueId })
]

{ #category : 'instructions' }
SpvBuilder >> emitStore: valueId at: ptrId [
    "Emit OpStore. No result id."
    currentBlock addInstruction: (SpvInstruction
        opcode: SpvOpcode opStore
        operands: { ptrId. valueId })
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

{ #category : 'accessing' }
SpvBuilder >> types [           ^ module typeRegistry
]

{ #category : 'barriers' }
SpvBuilder >> workgroupBarrier [
	"Answers the module's one barrier definition, so that a kernel built through the builder
	 and a kernel compiled from Pharo source emit the same instruction."

	^ module workgroupBarrierInstruction
]
