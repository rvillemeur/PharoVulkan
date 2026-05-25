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
    b addDecoration: bufA id decoration: SpvDecoration binding         literals: { 0 }.
    b addDecoration: bufB id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufB id decoration: SpvDecoration binding         literals: { 1 }.
    b addDecoration: bufR id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufR id decoration: SpvDecoration binding         literals: { 2 }.
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

{ #category : 'tests' }
SpvBuilderTest >> testConstantDeduplication [
    "Requesting the same constant twice must return the same result id."
    | m id1 id2 |
    m := SpvModule new.
    id1 := m constantPool constantFloat32: 1.0.
    id2 := m constantPool constantFloat32: 1.0.
    self assert: id1 equals: id2
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
