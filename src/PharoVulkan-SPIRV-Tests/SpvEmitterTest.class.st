"
Tests for SpvModuleEmitter (Phase 3). Verifies that IR nodes lower correctly to SPIR-V, validate, and produce correct GPU results.
"
Class {
	#name : 'SpvEmitterTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-SPIRV-Tests-Tests',
	#package : 'PharoVulkan-SPIRV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SpvEmitterTest >> buildVectorAddModule [
	| em mod tr cp f32 u32 uvec3 rta struct pStruct pF32 pUvec3 c0Id
	  bufA bufB bufR gidVar gidRef aRef bRef rRef c0Ref
	  fn blk gidLoad iExtract aChain aVal bChain bVal sum rChain spvFn |
	em := SpvModuleEmitter new.
	mod := em module.
	mod beShaderModule.
	tr := mod typeRegistry.
	cp := mod constantPool.
	f32 := tr floatType: 32.
	u32 := tr intType: 32 signed: false.
	uvec3 := tr vectorType: u32 count: 3.
	rta := tr runtimeArrayType: f32.
	struct := tr structType: (Array with: rta).
	pStruct := tr pointerType: SpvStorageClass storageBuffer type: struct.
	pF32 := tr pointerType: SpvStorageClass storageBuffer type: f32.
	pUvec3 := tr pointerType: SpvStorageClass input type: uvec3.
	mod addDecoration: struct id decoration: SpvDecoration block literals: #().
	mod addDecoration: rta id decoration: SpvDecoration arrayStride literals: (Array with: 4).
	mod addMemberDecoration: struct id member: 0 decoration: SpvDecoration offset literals: (Array with: 0).
	bufA := SpvGlobalVariable on: mod type: pStruct storageClass: SpvStorageClass storageBuffer.
	bufB := SpvGlobalVariable on: mod type: pStruct storageClass: SpvStorageClass storageBuffer.
	bufR := SpvGlobalVariable on: mod type: pStruct storageClass: SpvStorageClass storageBuffer.
	gidVar := SpvGlobalVariable on: mod type: pUvec3 storageClass: SpvStorageClass input.
	mod addGlobalVariable: bufA.
	mod addGlobalVariable: bufB.
	mod addGlobalVariable: bufR.
	mod addGlobalVariable: gidVar.
	mod addDecoration: bufA id decoration: SpvDecoration descriptorSet literals: (Array with: 0).
	mod addDecoration: bufA id decoration: SpvDecoration bindingDecoration literals: (Array with: 0).
	mod addDecoration: bufB id decoration: SpvDecoration descriptorSet literals: (Array with: 0).
	mod addDecoration: bufB id decoration: SpvDecoration bindingDecoration literals: (Array with: 1).
	mod addDecoration: bufR id decoration: SpvDecoration descriptorSet literals: (Array with: 0).
	mod addDecoration: bufR id decoration: SpvDecoration bindingDecoration literals: (Array with: 2).
	mod addDecoration: gidVar id decoration: SpvDecoration builtIn literals: (Array with: SpvBuiltIn globalInvocationId).
	c0Id := cp constantUInt32: 0.
	gidRef := em globalRef: gidVar id type: pUvec3.
	aRef := em globalRef: bufA id type: pStruct.
	bRef := em globalRef: bufB id type: pStruct.
	rRef := em globalRef: bufR id type: pStruct.
	c0Ref := em globalRef: c0Id type: u32.
	fn := SpvIRFunction name: 'main' returnType: tr voidType.
	blk := fn addBlock.
	gidLoad := blk add: (SpvIRLoad pointer: gidRef type: uvec3).
	iExtract := blk add: (SpvIRCompositeExtract composite: gidLoad indices: (Array with: 0) type: u32).
	aChain := blk add: (SpvIRAccessChain base: aRef indices: (Array with: c0Ref with: iExtract) type: pF32).
	aVal := blk add: (SpvIRLoad pointer: aChain type: f32).
	bChain := blk add: (SpvIRAccessChain base: bRef indices: (Array with: c0Ref with: iExtract) type: pF32).
	bVal := blk add: (SpvIRLoad pointer: bChain type: f32).
	sum := blk add: (SpvIRBinaryOp opcode: SpvOpcode opFAdd left: aVal right: bVal type: f32).
	rChain := blk add: (SpvIRAccessChain base: rRef indices: (Array with: c0Ref with: iExtract) type: pF32).
	blk add: (SpvIRStore pointer: rChain value: sum).
	blk terminate: SpvIRReturn new.
	spvFn := em emitFunction: fn.
	mod addEntryPoint: spvFn executionModel: SpvExecutionModel glCompute
		name: 'main' interfaces: (Array with: bufA with: bufB with: bufR with: gidVar).
	mod addExecutionMode: spvFn mode: 17 literals: (Array with: 64 with: 1 with: 1).
	^ mod serialize
]

{ #category : 'helpers' }
SpvEmitterTest >> bytesToFloats: ba [
	| floats n |
	n := ba size // 4.
	floats := Array new: n.
	1 to: n do: [:i |
		| bits |
		bits := (ba at: (i-1)*4+1)
			+ ((ba at: (i-1)*4+2) << 8)
			+ ((ba at: (i-1)*4+3) << 16)
			+ ((ba at: (i-1)*4+4) << 24).
		floats at: i put: (Float fromIEEE32Bit: bits)].
	^ floats
]

{ #category : 'helpers' }
SpvEmitterTest >> floatArrayToBytes: floats [
	| ba |
	ba := ByteArray new: floats size * 4.
	floats doWithIndex: [:f :i |
		| bits |
		bits := f asIEEE32BitWord.
		ba at: (i-1)*4+1 put: (bits bitAnd: 255).
		ba at: (i-1)*4+2 put: ((bits >> 8) bitAnd: 255).
		ba at: (i-1)*4+3 put: ((bits >> 16) bitAnd: 255).
		ba at: (i-1)*4+4 put: ((bits >> 24) bitAnd: 255)].
	^ ba
]

{ #category : 'tests' }
SpvEmitterTest >> testEmitterIdempotent [

	| bytes1 bytes2 |
	bytes1 := self buildVectorAddModule.
	bytes2 := self buildVectorAddModule.
	self assert: bytes1 equals: bytes2
]

{ #category : 'tests' }
SpvEmitterTest >> testVectorAddEmitted [

	| spirv ctx n aData bData aBytes bBytes a b r kernel result |
	spirv := self buildVectorAddModule.
	SpvValidator new validate: spirv.
	n := 64.
	aData := (1 to: n) asArray collect: [ :i | i asFloat ].
	bData := (1 to: n) asArray collect: [ :i | i asFloat ].
	aBytes := self floatArrayToBytes: aData.
	bBytes := self floatArrayToBytes: bData.
	ctx := VkContext computeContext.
	result := [
		          a := ctx device allocateBuffer: n * 4 usage: 32.
		          b := ctx device allocateBuffer: n * 4 usage: 32.
		          r := ctx device allocateBuffer: n * 4 usage: 32.
		          a copyFromByteArray: aBytes.
		          b copyFromByteArray: bBytes.
		          kernel := PVComputeKernel on: ctx spirv: spirv.
		          kernel buffers: (Array with: a with: b with: r).
		          kernel prepare.
		          kernel dispatch: 1 y: 1 z: 1.
		          self bytesToFloats: r copyToByteArray ] ensure: [
			          kernel ifNotNil: [ kernel destroy ].
			          a ifNotNil: [ a destroy ].
			          b ifNotNil: [ b destroy ].
			          r ifNotNil: [ r destroy ].
			          ctx destroy ].
	1 to: n do: [ :i |
	self assert: ((result at: i) - (i * 2.0)) abs < 0.001 ]
]
