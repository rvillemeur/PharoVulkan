"
Tests for the PharoVulkan-SPIRV builder infrastructure.
Covers serialization, type deduplication, constant deduplication,
and end-to-end construction of a compute vector-add SPIR-V module.
"
Class {
	#name : 'SpvBuilderTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-SPIRV',
	#package : 'PharoVulkan-Tests',
	#tag : 'SPIRV'
}

{ #category : 'helpers' }
SpvBuilderTest >> buildVectorAddModule [
    "Build a GLCompute SPIR-V module: result[i] = a[i] + b[i].
     Three storage buffer bindings at set=0, binding=0/1/2. LocalSize 64 1 1."
    | b types consts f32 u32 uvec3 pUvec3 rta struct pStruct pF32Buf
      mainFn entryBlock invIdGlobal bufA bufB bufR voidType
      invIdVar idx zero aPtr bPtr rPtr aVal bVal rVal |

    b := SpvBuilder new.
    b addCapability: #Shader.
    b setMemoryModel: 0 memoryModel: 1.
    types  := b types.
    consts := b constants.

    "Scalar types"
    f32   := types floatType: 32.
    u32   := types intType: 32 signed: false.
    uvec3 := types vectorType: u32 count: 3.

    "Buffer layout: struct { float[] }"
    rta    := types runtimeArrayType: f32.
    struct := types structType: { rta }.
    pStruct := types pointerType: SpvStorageClass storageBuffer type: struct.
    pF32Buf := types pointerType: SpvStorageClass storageBuffer type: f32.
    pUvec3  := types pointerType: SpvStorageClass input type: uvec3.

    "Struct/array decorations"
    b addDecoration: struct id decoration: SpvDecoration block literals: #().
    b addMemberDecoration: struct id member: 0 decoration: SpvDecoration arrayStride literals: { 4 }.

    "Global variables"
    bufA       := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
    bufB       := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
    bufR       := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
    invIdGlobal := b addGlobalVariable: pUvec3 storageClass: SpvStorageClass input.

    "Descriptor binding decorations"
    b addDecoration: bufA id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufA id decoration: SpvDecoration bindingDecoration         literals: { 0 }.
    b addDecoration: bufB id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufB id decoration: SpvDecoration bindingDecoration         literals: { 1 }.
    b addDecoration: bufR id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufR id decoration: SpvDecoration bindingDecoration         literals: { 2 }.
    b addDecoration: invIdGlobal id decoration: SpvDecoration builtIn
        literals: { SpvBuiltIn globalInvocationId }.

    "main function body"
    voidType  := types voidType.
    mainFn    := b newFunction: voidType.
    entryBlock := mainFn addBlock.
    b currentBlock: entryBlock.

    invIdVar := b emitLoad: invIdGlobal id type: uvec3.
    idx      := b emitCompositeExtract: invIdVar type: u32 indices: { 0 }.
    zero     := consts constantUInt32: 0.
    aPtr     := b emitAccessChain: bufA id type: pF32Buf indices: { zero. idx }.
    bPtr     := b emitAccessChain: bufB id type: pF32Buf indices: { zero. idx }.
    rPtr     := b emitAccessChain: bufR id type: pF32Buf indices: { zero. idx }.
    aVal     := b emitLoad: aPtr type: f32.
    bVal     := b emitLoad: bPtr type: f32.
    rVal     := b emitBinaryOp: SpvOpcode opFAdd left: aVal right: bVal type: f32.
    b emitStore: rVal at: rPtr.
    b emitReturn.

    "Entry point — execution mode LocalSize = 64 1 1 (mode id 17)"
    b addEntryPoint: mainFn
        executionModel: SpvExecutionModel glCompute
        name: 'main'
        interfaces: { bufA. bufB. bufR. invIdGlobal }.
    b addExecutionMode: mainFn mode: 17 literals: { 64. 1. 1 }.

    ^ b module
]

{ #category : 'helpers' }
SpvBuilderTest >> definitionOrderIn: bytes [
	"Maps every result id in the module to the position of the instruction that defines it, so
	 a test can state that a definition precedes its use rather than reading hex by eye. Only
	 the instructions that carry a result id in the same place are walked: types, constants
	 and global variables all put it first or second, and this answers both forms by taking
	 the id a type instruction declares."

	| words index order position |
	order := Dictionary new.
	words := self wordsIn: bytes.
	index := 6.
	position := 0.
	[ index <= words size ] whileTrue: [
		| word wordCount opcode |
		word := words at: index.
		wordCount := word bitShift: -16.
		opcode := word bitAnd: 16rFFFF.
		position := position + 1.
		(self resultIdOfTypeOrConstant: opcode at: index in: words) ifNotNil: [ :id |
			order at: id ifAbsentPut: [ position ] ].
		index := index + wordCount ].
	^ order
]

{ #category : 'helpers' }
SpvBuilderTest >> resultIdOfTypeOrConstant: anOpcode at: anIndex in: words [
	"Type declarations carry their result id as the first word after the opcode; constants and
	 variables carry a result type first and the result id second. Anything else answers nil,
	 since this is only asked about the types-and-constants section."

	| typeOpcodes typedOpcodes |
	typeOpcodes := {
		               SpvOpcode opTypeVoid.
		               SpvOpcode opTypeBool.
		               SpvOpcode opTypeInt.
		               SpvOpcode opTypeFloat.
		               SpvOpcode opTypeVector.
		               SpvOpcode opTypeMatrix.
		               SpvOpcode opTypeArray.
		               SpvOpcode opTypeRuntimeArray.
		               SpvOpcode opTypeStruct.
		               SpvOpcode opTypePointer.
		               SpvOpcode opTypeFunction }.
	typedOpcodes := {
		                SpvOpcode opConstant.
		                SpvOpcode opConstantTrue.
		                SpvOpcode opConstantFalse.
		                SpvOpcode opConstantNull.
		                SpvOpcode opVariable }.
	(typeOpcodes includes: anOpcode) ifTrue: [ ^ words at: anIndex + 1 ].
	(typedOpcodes includes: anOpcode) ifTrue: [ ^ words at: anIndex + 2 ].
	^ nil
]

{ #category : 'tests' }
SpvBuilderTest >> testArrayLengthConstantIsDefinedBeforeTheArrayType [
	"An array type's length is an id, so the constant holding it has to be serialised first.
	 The serialiser used to emit every type and only then every constant, which put the use
	 before the definition and made any fixed-size array invalid SPIR-V."

	| b types f32 array lengthId bytes order |
	b := SpvBuilder new.
	b addCapability: #Shader.
	b setMemoryModel: 0 memoryModel: 1.
	types := b types.
	f32 := types floatType: 32.
	array := types arrayType: f32 length: 16.
	lengthId := b constants constantUInt32: 16.
	bytes := SpvSerializer serialize: b module.
	order := self definitionOrderIn: bytes.
	self assert: ((order at: lengthId) < (order at: array id))
]

{ #category : 'tests' }
SpvBuilderTest >> testArrayTypeCarriesItsElementTypeAndLengthConstant [
	"A fixed-size array names its length through an id of a constant, not a literal, which is
	 what separates OpTypeArray from OpTypeRuntimeArray."

	| b types f32 array lengthId |
	b := SpvBuilder new.
	types := b types.
	f32 := types floatType: 32.
	lengthId := b constants constantUInt32: 16.
	array := types arrayType: f32 length: 16.
	self assert: array instruction opcode equals: SpvOpcode opTypeArray.
	self assert: array instruction operands equals: {
			f32 id.
			lengthId }
]

{ #category : 'tests' }
SpvBuilderTest >> testArrayTypeOfTheSameShapeIsDeduplicated [
	"Two arrays of the same element type and length are one type, as every other type in the
	 registry is."

	| b types f32 |
	b := SpvBuilder new.
	types := b types.
	f32 := types floatType: 32.
	self
		assert: (types arrayType: f32 length: 16) id
		equals: (types arrayType: f32 length: 16) id.
	self
		deny: (types arrayType: f32 length: 16) id
		equals: (types arrayType: f32 length: 32) id
]

{ #category : 'tests - cooperative matrix' }
SpvBuilderTest >> testBuilderCanBeOpenedOnAModuleSomeoneElseOwns [
	"PVSPIRVEmitter owns its module and still has to build the cooperative matrix
	 instructions, whose operand assembly lives in this class. A builder opened on an
	 existing module writes into it rather than into one of its own."

	| module builder |
	module := SpvModule new.
	builder := SpvBuilder on: module.
	self assert: builder module identicalTo: module.
	self assert: (builder types floatType: 32) id equals: (module typeRegistry floatType: 32) id
]

{ #category : 'tests' }
SpvBuilderTest >> testConstantDeduplication [
    "Requesting the same constant twice must return the same result id."
    | m id1 id2 |
    m := SpvModule new.
    id1 := m constantPool constantFloat32: 1.0.
    id2 := m constantPool constantFloat32: 1.0.
    self assert: id1 equals: id2
]

{ #category : 'tests - cooperative matrix' }
SpvBuilderTest >> testCooperativeMatrixTypeIsOnePerShapeAndRole [
	"The registry keys a cooperative matrix on its component type and its whole shape, so
	 asking twice for the same one answers the same type, while a different use is a
	 different type even with everything else equal. A key that missed would emit a second
	 OpTypeCooperativeMatrixKHR for a type the module already has."

	| builder f16 shapeOf |
	builder := SpvBuilder new.
	f16 := builder types floatType: 16.
	shapeOf := [ :use |
	           SpvCooperativeMatrixShape
		           rows: 8
		           columns: 8
		           scope: SpvScope subgroup
		           use: use ].
	self
		assert:
		(builder types
			 cooperativeMatrixType: f16
			 shape: (shapeOf value: SpvCooperativeMatrixType matrixAUse)) id
		equals: (builder types
				 cooperativeMatrixType: f16
				 shape: (shapeOf value: SpvCooperativeMatrixType matrixAUse)) id.
	self
		deny:
		(builder types
			 cooperativeMatrixType: f16
			 shape: (shapeOf value: SpvCooperativeMatrixType matrixAUse)) id
		equals: (builder types
				 cooperativeMatrixType: f16
				 shape: (shapeOf value: SpvCooperativeMatrixType matrixBUse)) id
]

{ #category : 'tests - package' }
SpvBuilderTest >> testEveryClassOfTheSpirvPackageAnswersItsOwnBinding [
	"A class-side method named after a reflection selector hides the real one. The decoration
	 number used to be answered by a class-side method named binding, so asking SpvDecoration for
	 its binding answered that integer rather than the global variable holding the class, and
	 every tool reading a class through its binding failed on it: Renraku's unreferenced-class
	 rule raised 'SmallInteger did not understand #isReferenced'. Each class of the package is
	 asked, because the next constant named after a reflection selector would break the same way."

	SpvBuilder package definedClasses do: [ :each |
		self assert: each binding value identicalTo: each ]
]

{ #category : 'tests' }
SpvBuilderTest >> testMemorySemanticsAreSingleBitsOfOneMask [
	"Memory semantics is a bitmask, so the named values have to be distinct single bits that
	 can be combined. A value that is not a power of two would silently set two meanings."

	{
		SpvMemorySemantics acquire.
		SpvMemorySemantics release.
		SpvMemorySemantics acquireRelease.
		SpvMemorySemantics uniformMemory.
		SpvMemorySemantics subgroupMemory.
		SpvMemorySemantics workgroupMemory } do: [ :each |
		self assert: each isPowerOfTwo ].
	self
		assert: (SpvMemorySemantics acquireRelease bitAnd:
				 SpvMemorySemantics workgroupMemory)
		equals: 0
]

{ #category : 'tests - barriers' }
SpvBuilderTest >> testModuleAnswersTheSameBarrierTheBuilderDoes [
	"The hand-built path reaches the barrier through the builder and the compiled path
	 reaches it through the module. One definition, so the two cannot drift apart in scope
	 or memory semantics."

	| b fromBuilder fromModule |
	b := SpvBuilder new.
	fromBuilder := b workgroupBarrier.
	fromModule := b module workgroupBarrierInstruction.
	self assert: fromModule opcode equals: fromBuilder opcode.
	self assert: fromModule operands equals: fromBuilder operands
]

{ #category : 'tests - cooperative matrix' }
SpvBuilderTest >> testNullConstantOfACooperativeMatrixTypeIsDeclaredOnce [
	"A zero accumulator is OpConstantNull of the matrix type. Asking twice answers the same
	 id, and the constant must come after the type it is null of, which the ascending id
	 order of the declaration section gives for free."

	| builder matrixType first second |
	builder := SpvBuilder new.
	matrixType := builder types
		              cooperativeMatrixType: (builder types floatType: 32)
		              shape: (SpvCooperativeMatrixShape
				               rows: PVCooperativeMatrixKernel matrixOrder
				               columns: PVCooperativeMatrixKernel matrixOrder
				               scope: SpvScope subgroup
				               use: SpvCooperativeMatrixType matrixAccumulatorUse).
	first := builder constants constantNullOfType: matrixType.
	second := builder constants constantNullOfType: matrixType.
	self assert: first equals: second.
	self assert: first > matrixType id
]

{ #category : 'tests' }
SpvBuilderTest >> testSerializeHeader [
    "Serialized SPIR-V must start with the magic bytes 0x07230203 in little-endian."
    | bytes |
    bytes := SpvModule new serialize.
    self assert: (bytes at: 1) equals: 16r03.
    self assert: (bytes at: 2) equals: 16r02.
    self assert: (bytes at: 3) equals: 16r23.
    self assert: (bytes at: 4) equals: 16r07
]

{ #category : 'tests' }
SpvBuilderTest >> testTypeDeduplication [
    "Requesting the same type twice must return the identical object."
    | m reg t1 t2 |
    m := SpvModule new.
    reg := m typeRegistry.
    t1 := reg floatType: 32.
    t2 := reg floatType: 32.
    self assert: t1 identicalTo: t2
]

{ #category : 'tests' }
SpvBuilderTest >> testTypeIdsAreUnique [
	"Different types must get different ids."

	| m reg |
	m := SpvModule new.
	reg := m typeRegistry.
	self
		deny: (reg floatType: 32) id
		equals: (reg intType: 32 signed: true) id
]

{ #category : 'tests' }
SpvBuilderTest >> testValidatorRaisesOnGarbage [
    "Passing garbage bytes to SpvValidator must raise SpvValidationError."
    self should: [ SpvValidator validate: #[0 1 2 3] asByteArray ]
        raise: SpvValidationError
]

{ #category : 'tests' }
SpvBuilderTest >> testVectorAddModuleSerializes [
    "Build the vector-add compute module and verify it serializes without error."
    | m bytes |
    m := self buildVectorAddModule.
    bytes := m serialize.
    self assert: bytes size > 20.
    self assert: (bytes at: 1) equals: 16r03.
    self assert: (bytes at: 2) equals: 16r02.
    self assert: (bytes at: 3) equals: 16r23.
    self assert: (bytes at: 4) equals: 16r07
]

{ #category : 'tests' }
SpvBuilderTest >> testWorkgroupBarrierCarriesThreeConstantIds [
	"OpControlBarrier takes an execution scope, a memory scope and memory semantics, and all
	 three are ids of constants rather than literals — unlike the group operation beside the
	 scope in a subgroup reduction. The semantics say the workgroup's shared memory is made
	 visible, which is the whole reason a tiled kernel needs the barrier."

	| b barrier scopeId semanticsId |
	b := SpvBuilder new.
	b addCapability: #Shader.
	b setMemoryModel: 0 memoryModel: 1.
	barrier := b workgroupBarrier.
	scopeId := b constants constantUInt32: SpvScope workgroup.
	semanticsId := b constants constantUInt32:
		               (SpvMemorySemantics acquireRelease
			                bitOr: SpvMemorySemantics workgroupMemory).
	self assert: barrier opcode equals: SpvOpcode opControlBarrier.
	self assert: barrier operands equals: {
			scopeId.
			scopeId.
			semanticsId }
]

{ #category : 'helpers' }
SpvBuilderTest >> wordsIn: bytes [
	"The module as 32-bit little-endian words, which is the only form its instruction stream
	 can be walked in."

	^ (1 to: bytes size by: 4) collect: [ :each |
		  (bytes at: each) + ((bytes at: each + 1) bitShift: 8)
		  + ((bytes at: each + 2) bitShift: 16)
		  + ((bytes at: each + 3) bitShift: 24) ]
]
