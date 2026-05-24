"
SUnit test suite for the compute pipeline. Verifies end-to-end GPU dispatch: buffer allocation, descriptor binding, pipeline creation, and result readback against a CPU reference.
"
Class {
	#name : 'PVComputeTest',
	#superclass : 'TestCase',
	#instVars : [
		'ctx'
	],
	#category : 'PharoVulkan-Compute-Tests',
	#package : 'PharoVulkan-Compute-Tests'
}

{ #category : 'helpers' }
PVComputeTest >> buildVectorAddSpirv [
	| b types consts f32 u32 uvec3 pUvec3 rta struct pStruct pF32Buf
	  mainFn entryBlock invIdGlobal bufA bufB bufR voidType
	  invIdVar idx zero aPtr bPtr rPtr aVal bVal rVal |
	b := SpvBuilder new.
	b addCapability: #Shader.
	b setMemoryModel: 0 memoryModel: 1.
	types := b types. consts := b constants.
	f32 := types floatType: 32.
	u32 := types intType: 32 signed: false.
	uvec3 := types vectorType: u32 count: 3.
	rta := types runtimeArrayType: f32.
	struct := types structType: { rta }.
	pStruct := types pointerType: SpvStorageClass storageBuffer type: struct.
	pF32Buf := types pointerType: SpvStorageClass storageBuffer type: f32.
	pUvec3 := types pointerType: SpvStorageClass input type: uvec3.
	"Block on struct, ArrayStride on rta, Offset=0 on member 0"
	b addDecoration: struct id decoration: SpvDecoration block literals: #().
	b addDecoration: rta id decoration: SpvDecoration arrayStride literals: { 4 }.
	b addMemberDecoration: struct id member: 0 decoration: SpvDecoration offset literals: { 0 }.
	bufA := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
	bufB := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
	bufR := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
	invIdGlobal := b addGlobalVariable: pUvec3 storageClass: SpvStorageClass input.
	b addDecoration: bufA id decoration: SpvDecoration descriptorSet literals: { 0 }.
	b addDecoration: bufA id decoration: SpvDecoration binding literals: { 0 }.
	b addDecoration: bufB id decoration: SpvDecoration descriptorSet literals: { 0 }.
	b addDecoration: bufB id decoration: SpvDecoration binding literals: { 1 }.
	b addDecoration: bufR id decoration: SpvDecoration descriptorSet literals: { 0 }.
	b addDecoration: bufR id decoration: SpvDecoration binding literals: { 2 }.
	b addDecoration: invIdGlobal id decoration: SpvDecoration builtIn literals: { SpvBuiltIn globalInvocationId }.
	voidType := types voidType.
	mainFn := b newFunction: voidType.
	entryBlock := mainFn addBlock.
	b currentBlock: entryBlock.
	invIdVar := b emitLoad: invIdGlobal id type: uvec3.
	idx := b emitCompositeExtract: invIdVar type: u32 indices: { 0 }.
	zero := consts constantUInt32: 0.
	aPtr := b emitAccessChain: bufA id type: pF32Buf indices: { zero. idx }.
	bPtr := b emitAccessChain: bufB id type: pF32Buf indices: { zero. idx }.
	rPtr := b emitAccessChain: bufR id type: pF32Buf indices: { zero. idx }.
	aVal := b emitLoad: aPtr type: f32.
	bVal := b emitLoad: bPtr type: f32.
	rVal := b emitBinaryOp: SpvOpcode opFAdd left: aVal right: bVal type: f32.
	b emitStore: rVal at: rPtr.
	b emitReturn.
	b addEntryPoint: mainFn executionModel: SpvExecutionModel glCompute
		name: 'main' interfaces: { bufA. bufB. bufR. invIdGlobal }.
	b addExecutionMode: mainFn mode: 17 literals: { 64. 1. 1 }.
	^ b module serialize
]

{ #category : 'helpers' }
PVComputeTest >> bytesToFloats: bytes [
	| result |
	result := Array new: bytes size // 4.
	1 to: result size do: [:i |
		| base word |
		base := (i - 1) * 4 + 1.
		word := (bytes at: base)
			+ ((bytes at: base + 1) bitShift: 8)
			+ ((bytes at: base + 2) bitShift: 16)
			+ ((bytes at: base + 3) bitShift: 24).
		result at: i put: (Float fromIEEE32Bit: word)].
	^ result
]

{ #category : 'helpers' }
PVComputeTest >> floatArrayToBytes: anArray [
	| bytes |
	bytes := ByteArray new: anArray size * 4.
	anArray doWithIndex: [:f :i |
		| word base |
		word := f asFloat asIEEE32BitWord.
		base := (i - 1) * 4 + 1.
		bytes at: base     put: (word bitAnd: 16rFF).
		bytes at: base + 1 put: ((word >> 8)  bitAnd: 16rFF).
		bytes at: base + 2 put: ((word >> 16) bitAnd: 16rFF).
		bytes at: base + 3 put: ((word >> 24) bitAnd: 16rFF)].
	^ bytes
]

{ #category : 'running' }
PVComputeTest >> setUp [

	super setUp.
	ctx := VkContext computeContext
]

{ #category : 'running' }
PVComputeTest >> tearDown [
	ctx destroy.
	super tearDown.
]

{ #category : 'tests' }
PVComputeTest >> testVectorAdd [
	"c[i] = a[i] + b[i] for i in [0,63]. LocalSize=64, dispatch 1 group."
	| n spirv bufA bufB bufC kernel result |
	n := 64.
	spirv := self buildVectorAddSpirv.
	bufA := VkBuffer on: ctx device size: n * 4 usage: 32.
	bufB := VkBuffer on: ctx device size: n * 4 usage: 32.
	bufC := VkBuffer on: ctx device size: n * 4 usage: 32.
	[
		bufA copyFromByteArray: (self floatArrayToBytes: ((0 to: n - 1) asArray collect: [:i | i asFloat])).
		bufB copyFromByteArray: (self floatArrayToBytes: ((0 to: n - 1) asArray collect: [:i | i asFloat])).
		bufC copyFromByteArray: (ByteArray new: n * 4).
		kernel := PVComputeKernel on: ctx spirv: spirv.
		kernel bindBuffer: bufA.
		kernel bindBuffer: bufB.
		kernel bindBuffer: bufC.
		kernel prepare.
		kernel dispatch: 1 y: 1 z: 1.
		result := self bytesToFloats: bufC copyToByteArray.
		0 to: n - 1 do: [:i |
			self assert: (result at: i + 1) closeTo: i * 2.0].
		kernel destroy
	] ensure: [
		bufA destroy. bufB destroy. bufC destroy ]
]
