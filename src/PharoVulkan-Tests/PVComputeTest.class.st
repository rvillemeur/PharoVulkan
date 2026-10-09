"
SUnit test suite for the compute pipeline. Verifies end-to-end GPU dispatch: buffer allocation, descriptor binding, pipeline creation, and result readback against a CPU reference.
"
Class {
	#name : 'PVComputeTest',
	#superclass : 'TestCase',
	#instVars : [
		'ctx'
	],
	#category : 'PharoVulkan-Tests-Compute',
	#package : 'PharoVulkan-Tests',
	#tag : 'Compute'
}

{ #category : 'helpers' }
PVComputeTest >> aAtRow: r col: c [
	"Deliberately asymmetric input: a row-column swap in the kernel cannot pass unnoticed.
	 Small magnitudes keep a 512-term float32 sum well inside tolerance."

	^ ((r + (2 * c)) \\ 7) / 7.0
]

{ #category : 'helpers' }
PVComputeTest >> bAtRow: r col: c [
	^ ((3 * r + c) \\ 5) / 5.0
]

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

{ #category : 'private' }
PVComputeTest >> dispatchMatmulOn: buffers groups: groupCount [
	"Bind the kernel's buffers in declaration order and answer the last one's contents: the
	 kernel writes its result to its final parameter."

	| kernel |
	kernel := PVComputeKernel
		          fromMethod: PVKernelExamples >> #matmulF32:a:b:out:
		          on: ctx.
	^ [
	  buffers do: [ :each | kernel bindBuffer: each ].
	  kernel prepare.
	  kernel dispatch: groupCount y: groupCount z: 1.
	  buffers last getF32s ] ensure: [ kernel destroy ]
]

{ #category : 'helpers' }
PVComputeTest >> flatMatrixOfOrder: n with: aBlock [
	"Row-major flattening, the layout the kernel indexes with row * n + col."

	| m |
	m := Array new: n * n.
	0 to: n - 1 do: [ :r |
		0 to: n - 1 do: [ :c | m at: r * n + c + 1 put: (aBlock value: r value: c) ] ].
	^ m
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

{ #category : 'helpers' }
PVComputeTest >> matmulSamplePositions [
	"Fixed positions rather than random ones, so a failure reproduces. They include the
	 corners, the first workgroup boundary (15, 16, 17) and the last row and column."

	^ #( 0 1 15 16 17 255 256 510 511 )
]

{ #category : 'helpers' }
PVComputeTest >> referenceAtRow: r col: c order: n [
	^ (0 to: n - 1) inject: 0.0 into: [ :acc :k |
		  acc + ((self aAtRow: r col: k) * (self bAtRow: k col: c)) ]
]

{ #category : 'private' }
PVComputeTest >> runMatmulOfOrder: n groups: groupCount [
	"Dispatch the baseline matmul over a fresh pair of input matrices and answer the output
	 buffer's contents. The grid has to cover the matrix exactly, since the kernel takes N
	 from wi gridWidth."

	| bufA bufB bufOut |
	bufA := VkBuffer storageBuffer: n * n on: ctx device.
	bufB := VkBuffer storageBuffer: n * n on: ctx device.
	bufOut := VkBuffer storageBuffer: n * n on: ctx device.
	^ [
	  bufA putF32s: (self flatMatrixOfOrder: n with: [ :r :c | self aAtRow: r col: c ]).
	  bufB putF32s: (self flatMatrixOfOrder: n with: [ :r :c | self bAtRow: r col: c ]).
	  bufOut putF32s: (Array new: n * n withAll: 0.0).
	  self dispatchMatmulOn: { bufA. bufB. bufOut } groups: groupCount ] ensure: [
		  bufA destroy.
		  bufB destroy.
		  bufOut destroy ]
]

{ #category : 'running' }
PVComputeTest >> setUp [

	super setUp.
	ctx := VkContext computeContext
]

{ #category : 'running' }
PVComputeTest >> tearDown [

	ctx destroy.
	super tearDown
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkRejectsOrderThatTheGridCannotCover [
	"The kernel reads N from the dispatch grid, so an order the workgroup does not divide
	 has no grid that covers it. Silently rounding would benchmark the wrong matrix."

	self
		should: [ PVBenchmark on: ctx order: 100 repeats: 1 ]
		raise: PVTypeError
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkReportRowsBeforeAnyRun [
	"The inspector view is readable before the benchmark has run, and says so instead of
	 showing a zero time."

	| rows |
	rows := (PVBenchmark on: ctx order: 64 repeats: 1) reportRows.
	self assert: rows size equals: 1.
	self assert: (rows first at: #value) equals: 'not run yet'
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkResultDerivesRateFromTime [
	"2 N cubed floating point operations over the measured time. 512 cubed multiply-adds in
	 100 ms is 2.68 GFLOP/s, and a result that cannot do this arithmetic is not a benchmark."

	| result |
	result := PVBenchmarkResult order: 512 milliseconds: 100 repeats: 1.
	self assert: result floatingPointOperations equals: 2 * (512 * 512 * 512).
	self
		assert: result gigaflopsPerSecond
		closeTo: 2 * (512 * 512 * 512) / 0.1 / 1e9
		precision: 0.001
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkResultWithoutElapsedTimeHasNoRate [
	"A dispatch too quick for the millisecond clock has no rate to report. Reporting one
	 would mean dividing by zero, and reporting zero would be a lie."

	| result |
	result := PVBenchmarkResult order: 64 milliseconds: 0 repeats: 10.
	self assert: result gigaflopsPerSecond isNil
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkRunsMatmulAndReportsTime [
	"The baseline needs a number, not a claim. No speed assertion here: the point is that a
	 run produces a time and a derived rate for the configuration it was asked for."

	| result |
	result := (PVBenchmark on: ctx order: 128 repeats: 3) run.
	self assert: result order equals: 128.
	self assert: result repeats equals: 3.
	self assert: result milliseconds >= 0.
	result milliseconds = 0
		ifTrue: [ self assert: result gigaflopsPerSecond isNil ]
		ifFalse: [ self assert: result gigaflopsPerSecond > 0 ]
]

{ #category : 'tests' }
PVComputeTest >> testComputeLoopSumOnDevice [
	"The loop kernel must produce the right numbers on the device. spirv-val cannot see a
	 dropped loop — a straight-line kernel is valid SPIR-V — so only a GPU run proves the
	 loop ran all 16 iterations."

	| n bufIn bufOut kernel result expected |
	n := 64.
	bufIn := VkBuffer storageBuffer: n on: ctx device.
	bufOut := VkBuffer storageBuffer: n on: ctx device.
	[
	bufIn putF32s: ((0 to: n - 1) asArray collect: [ :i | i asFloat ]).
	bufOut putF32s: (Array new: n withAll: 0.0).
	kernel := PVComputeKernel
		          fromMethod: PVCfgShapeFixture >> #computeLoopSum:data:out:
		          on: ctx.
	kernel bindBuffer: bufIn.
	kernel bindBuffer: bufOut.
	kernel prepare.
	kernel dispatch: 1 y: 1 z: 1.
	result := bufOut getF32s.
	expected := (0 to: 15) inject: 0.0 into: [ :acc :i | acc + i ].
	1 to: n do: [ :i | self assert: (result at: i) closeTo: expected ].
	kernel destroy ] ensure: [
		bufIn destroy.
		bufOut destroy ]
]

{ #category : 'tests' }
PVComputeTest >> testComputeSelectionClampOnDevice [
	"The selection kernel must clamp negatives to zero on the device, which proves both
	 arms of the OpBranchConditional and the OpPhi that joins them."

	| n bufIn bufOut kernel input result |
	n := 64.
	bufIn := VkBuffer storageBuffer: n on: ctx device.
	bufOut := VkBuffer storageBuffer: n on: ctx device.
	[
	input := (0 to: n - 1) asArray collect: [ :i | i - 32 ].
	bufIn putF32s: (input collect: [ :each | each asFloat ]).
	bufOut putF32s: (Array new: n withAll: -1.0).
	kernel := PVComputeKernel
		          fromMethod: PVCfgShapeFixture >> #computeSelectionClamp:data:out:
		          on: ctx.
	kernel bindBuffer: bufIn.
	kernel bindBuffer: bufOut.
	kernel prepare.
	kernel dispatch: 1 y: 1 z: 1.
	result := bufOut getF32s.
	1 to: n do: [ :i |
		self assert: (result at: i) closeTo: ((input at: i) asFloat max: 0.0) ].
	kernel destroy ] ensure: [
		bufIn destroy.
		bufOut destroy ]
]

{ #category : 'tests' }
PVComputeTest >> testGridWidthFromDispatchOnDevice [
	"wi gridWidth must answer groupCountX times localSizeX, read from the dispatch. Two
	 dispatches of the same module with different group counts must sum different numbers
	 of elements, which a constant baked at compile time could not do. The untouched tail
	 also pins the <localSize: #( 8 1 1 )> pragma: a 64-wide local size would write every
	 slot."

	| n bufIn bufOut kernel result |
	n := 64.
	bufIn := VkBuffer storageBuffer: n on: ctx device.
	bufOut := VkBuffer storageBuffer: n on: ctx device.
	[
	bufIn putF32s: ((0 to: n - 1) asArray collect: [ :i | i asFloat ]).
	bufOut putF32s: (Array new: n withAll: -1.0).
	kernel := PVComputeKernel
		          fromMethod: PVKernelExamples >> #sumFirstGridWidth:data:out:
		          on: ctx.
	kernel bindBuffer: bufIn.
	kernel bindBuffer: bufOut.
	kernel prepare.
	kernel dispatch: 2 y: 1 z: 1.
	result := bufOut getF32s.
	1 to: 16 do: [ :i | self assert: (result at: i) closeTo: 120.0 ].
	17 to: n do: [ :i | self assert: (result at: i) closeTo: -1.0 ].
	bufOut putF32s: (Array new: n withAll: -1.0).
	kernel dispatch: 4 y: 1 z: 1.
	result := bufOut getF32s.
	1 to: 32 do: [ :i | self assert: (result at: i) closeTo: 496.0 ].
	33 to: n do: [ :i | self assert: (result at: i) closeTo: -1.0 ].
	kernel destroy ] ensure: [
		bufIn destroy.
		bufOut destroy ]
]

{ #category : 'tests' }
PVComputeTest >> testMatmulOrder16MatchesReference [
	"One workgroup, every element checked against a CPU reference. 16 by 16 is small enough
	 to compare in full, so this is the test that pins the index arithmetic."

	| n result |
	n := 16.
	result := self runMatmulOfOrder: n groups: 1.
	0 to: n - 1 do: [ :r |
		0 to: n - 1 do: [ :c |
			self
				assert: (result at: r * n + c + 1)
				closeTo: (self referenceAtRow: r col: c order: n)
				precision: 0.001 ] ]
]

{ #category : 'tests' }
PVComputeTest >> testMatmulOrder512MatchesReferenceAtSampledPositions [
	"The Phase 7 baseline size. A full CPU reference would be 512 cubed multiply-adds in
	 Pharo, so the check is 81 sampled elements, each a complete 512-term dot product. The
	 grid is 32 by 32 groups of 16 by 16, which is what makes wi gridWidth answer 512."

	| n result |
	n := 512.
	result := self runMatmulOfOrder: n groups: n / 16.
	self matmulSamplePositions do: [ :r |
		self matmulSamplePositions do: [ :c |
			self
				assert: (result at: r * n + c + 1)
				closeTo: (self referenceAtRow: r col: c order: n)
				precision: 0.01 ] ]
]

{ #category : 'tests' }
PVComputeTest >> testVectorAdd [
	"c[i] = a[i] + b[i] for i in [0,63]. LocalSize=64, dispatch 1 group."
	| n spirv bufA bufB bufC kernel result |
	n := 64.
	spirv := self buildVectorAddSpirv.
	bufA := VkBuffer storageBuffer: n on: ctx device.
	bufB := VkBuffer storageBuffer: n on: ctx device.
	bufC := VkBuffer storageBuffer: n on: ctx device.
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

{ #category : 'tests' }
PVComputeTest >> testVectorAddFromCompiledMethod [
	"End-to-end: compile Pharo kernel, run on GPU, verify result."
	| n bufA bufB bufC kernel result |
	n := 64.
	bufA := VkBuffer storageBuffer: n on: ctx device.
	bufB := VkBuffer storageBuffer: n on: ctx device.
	bufC := VkBuffer storageBuffer: n on: ctx device.
	[
		bufA putF32s: ((0 to: n - 1) asArray collect: [:i | i asFloat]).
		bufB putF32s: ((0 to: n - 1) asArray collect: [:i | i asFloat]).
		bufC putF32s: (Array new: n withAll: 0.0).
		kernel := PVComputeKernel fromMethod: (PVKernelExamples >> #vectorAdd:a:b:out:) on: ctx.
		kernel bindBuffer: bufA.
		kernel bindBuffer: bufB.
		kernel bindBuffer: bufC.
		kernel prepare.
		kernel dispatch: 1 y: 1 z: 1.
		result := bufC getF32s.
		0 to: n - 1 do: [:i |
			self assert: (result at: i + 1) closeTo: i * 2.0].
		kernel destroy
	] ensure: [
		bufA destroy. bufB destroy. bufC destroy ]
]
