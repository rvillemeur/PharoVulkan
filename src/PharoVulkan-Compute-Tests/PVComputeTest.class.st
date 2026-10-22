"
SUnit test suite for the compute pipeline. Verifies end-to-end GPU dispatch: buffer allocation, descriptor binding, pipeline creation, and result readback against a CPU reference.
"
Class {
	#name : 'PVComputeTest',
	#superclass : 'TestCase',
	#instVars : [
		'ctx'
	],
	#category : 'PharoVulkan-Compute-Tests-Tests',
	#package : 'PharoVulkan-Compute-Tests',
	#tag : 'Tests'
}

{ #category : 'constants' }
PVComputeTest class >> halfErrorBudget [
	"How many roundings to the nearest half a matmul element is allowed to be out by: one
	 for each input matrix, one for the stored result, and the rest slack for the order the
	 device accumulates the dot product in."

	^ 8
]

{ #category : 'helpers' }
PVComputeTest >> aAtRow: r col: c [
	"Deliberately asymmetric input: a row-column swap in the kernel cannot pass unnoticed.
	 Small magnitudes keep a 512-term float32 sum well inside tolerance."

	^ ((r + (2 * c)) \\ 7) / 7.0
]

{ #category : 'helpers' }
PVComputeTest >> assertHalf: actual matchesReference: expected [
	"Half precision is lossy by construction, so the tolerance scales with the magnitude of
	 the value rather than being a fixed number of decimals. The floor covers an element
	 whose reference is near zero, where a relative tolerance would demand exactness the
	 format cannot give."

	| tolerance |
	tolerance := expected abs * self halfRoundoff * self class halfErrorBudget
	             + self halfRoundoff.
	self assert: actual closeTo: expected precision: tolerance
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
	b addDecoration: bufA id decoration: SpvDecoration bindingDecoration literals: { 0 }.
	b addDecoration: bufB id decoration: SpvDecoration descriptorSet literals: { 0 }.
	b addDecoration: bufB id decoration: SpvDecoration bindingDecoration literals: { 1 }.
	b addDecoration: bufR id decoration: SpvDecoration descriptorSet literals: { 0 }.
	b addDecoration: bufR id decoration: SpvDecoration bindingDecoration literals: { 2 }.
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

{ #category : 'running - matmul' }
PVComputeTest >> dispatchCompiledTiledMatmulOn: buffers groups: groupCount [
	"Bind the compiled tiled kernel's three buffers in binding order and answer the last
	 one's contents. Its two shared tiles take no binding, which is the whole point of
	 declaring them with <shared:named:count:> rather than as buffers."

	| kernel |
	kernel := PVComputeKernel
		          fromMethod:
		          PVKernelExamples >> #tiledMatmulF32:a:b:out:tileA:tileB:
		          on: ctx.
	^ [
	  buffers do: [ :each | kernel bindBuffer: each ].
	  kernel prepare.
	  kernel dispatch: groupCount y: groupCount z: 1.
	  buffers last elementsAs: #f32 ] ensure: [ kernel destroy ]
]

{ #category : 'running' }
PVComputeTest >> dispatchCompiledTiledMatmulOn: buffers groups: groupCount elementType: anElementTypeSymbol [
	"Bind the compiled tiled kernel's three buffers in binding order and answer the last
	 one's contents. Its two shared tiles take no binding, which is the whole point of
	 declaring them with <shared:named:count:> rather than as buffers. The kernel is asked
	 of the precision, so the module dispatched and the buffers bound hold the same width."

	| kernel |
	kernel := PVComputeKernel
		          fromMethod: (PVKernelExamples tiledMatmulFor: anElementTypeSymbol)
		          on: ctx.
	^ [
	  buffers do: [ :each | kernel bindBuffer: each ].
	  kernel prepare.
	  kernel dispatch: groupCount y: groupCount z: 1.
	  buffers last elementsAs: anElementTypeSymbol ] ensure: [ kernel destroy ]
]

{ #category : 'helpers' }
PVComputeTest >> dispatchMatmulOn: buffers groups: groupCount [
	^ self
		  dispatchMatmulOn: buffers
		  groups: groupCount
		  elementType: #f32
]

{ #category : 'helpers' }
PVComputeTest >> dispatchMatmulOn: buffers groups: groupCount elementType: anElementTypeSymbol [
	"Bind the kernel's buffers in declaration order and answer the last one's contents: the
	 kernel writes its result to its final parameter."

	| kernel |
	kernel := PVComputeKernel
		          fromMethod: (PVKernelExamples matmulFor: anElementTypeSymbol)
		          on: ctx.
	^ [
	  buffers do: [ :each | kernel bindBuffer: each ].
	  kernel prepare.
	  kernel dispatch: groupCount y: groupCount z: 1.
	  buffers last elementsAs: anElementTypeSymbol ] ensure: [ kernel destroy ]
]

{ #category : 'helpers' }
PVComputeTest >> dispatchTiledMatmulOn: buffers groups: groupCount [
	"Bind the tiled kernel's three buffers in binding order and answer the last one's
	 contents. The kernel is hand-built SPIR-V, so the runner is given bytes rather than a
	 compiled method."

	| kernel |
	kernel := PVComputeKernel on: ctx spirv: PVTiledMatmulKernel new spirv.
	^ [
	  buffers do: [ :each | kernel bindBuffer: each ].
	  kernel prepare.
	  kernel dispatch: groupCount y: groupCount z: 1.
	  buffers last elementsAs: #f32 ] ensure: [ kernel destroy ]
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
PVComputeTest >> halfRoundoff [
	"A value rounded to the nearest half lands within this fraction of itself: half
	 precision carries mantissaBits explicit bits plus the implicit one."

	^ 1 / (2 raisedTo: PVFloat16 mantissaBits + 1)
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

{ #category : 'running' }
PVComputeTest >> runCompiledTiledMatmulOfOrder: n [
	^ self
		  runCompiledTiledMatmulOfOrder: n
		  elementType: PVBenchmark defaultElementType
]

{ #category : 'running' }
PVComputeTest >> runCompiledTiledMatmulOfOrder: n elementType: anElementTypeSymbol [
	"The same inputs the other matmul kernels are checked against, held in the precision
	 under test, so every kernel is compared on identical data."

	| bufA bufB bufOut |
	bufA := VkBuffer
		        storageBuffer: n * n
		        of: anElementTypeSymbol
		        on: ctx device.
	bufB := VkBuffer
		        storageBuffer: n * n
		        of: anElementTypeSymbol
		        on: ctx device.
	bufOut := VkBuffer
		          storageBuffer: n * n
		          of: anElementTypeSymbol
		          on: ctx device.
	^ [
	  bufA
		  put: (self flatMatrixOfOrder: n with: [ :r :c | self aAtRow: r col: c ])
		  as: anElementTypeSymbol.
	  bufB
		  put: (self flatMatrixOfOrder: n with: [ :r :c | self bAtRow: r col: c ])
		  as: anElementTypeSymbol.
	  bufOut put: (Array new: n * n withAll: 0.0) as: anElementTypeSymbol.
	  self
		  dispatchCompiledTiledMatmulOn: {
				  bufA.
				  bufB.
				  bufOut }
		  groups: n // PVTiledMatmulKernel tileWidth
		  elementType: anElementTypeSymbol ] ensure: [
		  bufA destroy.
		  bufB destroy.
		  bufOut destroy ]
]

{ #category : 'running - matmul' }
PVComputeTest >> runCooperativeMatrixMatmulOn: aContext [
	"The same asymmetric inputs the other matmul tests use, flattened row by row, run
	 through the kernel's own dispatch so the test exercises the API the examples use."

	| n |
	n := PVCooperativeMatrixKernel matrixOrder.
	^ PVCooperativeMatrixKernel new
		  productOf:
		  (self flatMatrixOfOrder: n with: [ :r :c | self aAtRow: r col: c ])
		  by: (self flatMatrixOfOrder: n with: [ :r :c | self bAtRow: r col: c ])
		  on: aContext
]

{ #category : 'private' }
PVComputeTest >> runMatmulOfOrder: n groups: groupCount [
	^ self runMatmulOfOrder: n groups: groupCount elementType: #f32
]

{ #category : 'private' }
PVComputeTest >> runMatmulOfOrder: n groups: groupCount elementType: anElementTypeSymbol [
	"Dispatch the matmul written for that element width over a fresh pair of input matrices
	 and answer the output buffer's contents. The grid has to cover the matrix exactly,
	 since the kernel takes N from wi gridWidth."

	| bufA bufB bufOut |
	bufA := VkBuffer storageBuffer: n * n of: anElementTypeSymbol on: ctx device.
	bufB := VkBuffer storageBuffer: n * n of: anElementTypeSymbol on: ctx device.
	bufOut := VkBuffer
		          storageBuffer: n * n
		          of: anElementTypeSymbol
		          on: ctx device.
	^ [
	  bufA
		  put: (self flatMatrixOfOrder: n with: [ :r :c | self aAtRow: r col: c ])
		  as: anElementTypeSymbol.
	  bufB
		  put: (self flatMatrixOfOrder: n with: [ :r :c | self bAtRow: r col: c ])
		  as: anElementTypeSymbol.
	  bufOut put: (Array new: n * n withAll: 0.0) as: anElementTypeSymbol.
	  self
		  dispatchMatmulOn: { bufA. bufB. bufOut }
		  groups: groupCount
		  elementType: anElementTypeSymbol ] ensure: [
		  bufA destroy.
		  bufB destroy.
		  bufOut destroy ]
]

{ #category : 'helpers' }
PVComputeTest >> runTiledMatmulOfOrder: n [
	"The same inputs the naive matmul is checked against, so the two kernels are compared
	 on identical data. The kernel takes N from the grid, so the grid covers the matrix
	 exactly: n divided by the tile width, along both axes."

	| bufA bufB bufOut |
	bufA := VkBuffer storageBuffer: n * n of: #f32 on: ctx device.
	bufB := VkBuffer storageBuffer: n * n of: #f32 on: ctx device.
	bufOut := VkBuffer storageBuffer: n * n of: #f32 on: ctx device.
	^ [
	  bufA
		  put: (self flatMatrixOfOrder: n with: [ :r :c | self aAtRow: r col: c ])
		  as: #f32.
	  bufB
		  put: (self flatMatrixOfOrder: n with: [ :r :c | self bAtRow: r col: c ])
		  as: #f32.
	  bufOut put: (Array new: n * n withAll: 0.0) as: #f32.
	  self
		  dispatchTiledMatmulOn: { bufA. bufB. bufOut }
		  groups: n // PVTiledMatmulKernel tileWidth ] ensure: [
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
PVComputeTest >> testBenchmarkOfEachElementTypeDispatchesTheKernelOfThatWidth [
	"A benchmark names the precision it measures, and takes the kernel and the workgroup from
	 the matmul written for that precision rather than from a hardcoded one."

	PVBenchmark elementTypes do: [ :each |
		| benchmark |
		benchmark := PVBenchmark on: ctx order: 64 repeats: 1 elementType: each.
		self assert: benchmark elementType equals: each.
		self
			assert: benchmark kernelMethod
			equals: (PVKernelExamples matmulFor: each).
		self assert: benchmark workgroupWidth equals: 16 ]
]

{ #category : 'tests - benchmark' }
PVComputeTest >> testBenchmarkRefusesAKernelItCannotFillBuffersFor [
	"A benchmark fills three buffers of one width, so a kernel declaring buffers of two widths
	 is refused rather than measured at one of them. The cooperative matrix kernel is such a
	 kernel: half inputs, a float accumulator. An unknown family is refused the same way,
	 before anything is dispatched, because there is no kernel to time."

	self
		should: [
			PVBenchmark
				on: ctx
				order: 64
				repeats: 1
				kernel: PVKernelExamples >> #coopMatrixProductOf:by:into: ]
		raise: PVTypeError.
	self
		should: [
		PVPrecisionComparison on: ctx order: 64 repeats: 1 family: #nosuchfamily ]
		raise: PVTypeError
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkRefusesAnUnknownElementType [
	"There is no matmul kernel of that width, so there is nothing to measure. Falling back to
	 float would report a number for a precision nobody asked for."

	self
		should: [ PVBenchmark on: ctx order: 64 repeats: 1 elementType: #f64 ]
		raise: PVTypeError
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkRejectsOrderThatTheGridCannotCover [
	"The kernel reads N from the dispatch grid, so an order the workgroup does not divide
	 has no grid that covers it. Silently rounding would benchmark the wrong matrix."

	self
		should: [ PVBenchmark on: ctx order: 100 repeats: 1 ]
		raise: PVTypeError
]

{ #category : 'tests - benchmark' }
PVComputeTest >> testBenchmarkReportNamesTheKernelItDispatched [
	"Two rates at one matrix order and one precision mean nothing beside each other unless
	 each table says which kernel produced it. The row is read off the method the benchmark
	 dispatches, so it cannot name a kernel other than the one that ran."

	| kernel rows |
	kernel := PVKernelExamples tiledMatmulFor: PVBenchmark defaultElementType.
	rows := (PVBenchmark on: ctx order: 64 repeats: 1 kernel: kernel)
		        run;
		        reportRows.
	self assert: (rows anySatisfy: [ :row |
			 (row at: #value) = kernel selector asString ])
]

{ #category : 'tests' }
PVComputeTest >> testBenchmarkReportNamesThePrecisionItMeasured [
	"Two rates at one matrix order mean nothing beside each other unless each row says which
	 precision produced it."

	| rows |
	rows := (PVBenchmark on: ctx order: 64 repeats: 1 elementType: #f16) run; reportRows.
	self
		assert: (rows anySatisfy: [ :row |
				 (row at: #name) = 'Element type' and: [ (row at: #value) = 'f16' ] ])
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

{ #category : 'tests - benchmark' }
PVComputeTest >> testBenchmarkTakesPrecisionAndWidthFromTheKernelItWasGiven [
	"A benchmark is told which kernel to time and reads everything else off it: the precision
	 of the buffers it fills and the workgroup width the grid is built from. Stated over every
	 family and precision the examples hold, so a kernel added later is covered without a test
	 being written for it. A benchmark asked for a precision alone measures the naive matmul,
	 the baseline every other family is read against."

	PVKernelExamples matmulFamilies keysDo: [ :family |
		PVBenchmark elementTypes do: [ :elementType |
			| kernel benchmark |
			kernel := PVKernelExamples matmulFor: elementType family: family.
			benchmark := PVBenchmark
				             on: ctx
				             order: 64
				             repeats: 1
				             kernel: kernel.
			self assert: benchmark kernelMethod equals: kernel.
			self assert: benchmark elementType equals: elementType.
			self assert: benchmark workgroupWidth equals: 16 ] ].
	self
		assert: (PVBenchmark on: ctx order: 64 repeats: 1) kernelMethod
		equals: (PVKernelExamples
				 matmulFor: PVBenchmark defaultElementType
				 family: PVKernelExamples defaultMatmulFamily)
]

{ #category : 'tests - half precision' }
PVComputeTest >> testCompiledTiledMatmulF16MatchesTheReferenceAtOrder64 [
	"The half precision tiled kernel on the device, element by element. The tiles round the
	 inputs to half and the stored result is a half, while the dot product itself accumulates
	 in float, so the distance from the reference is the one the storage format forces and no
	 more. Order 64 walks the tile loop four times rather than once."

	| n result |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	n := 64.
	result := self runCompiledTiledMatmulOfOrder: n elementType: #f16.
	self assert: result size equals: n * n.
	0 to: n - 1 do: [ :row |
		0 to: n - 1 do: [ :col |
			self
				assertHalf: (result at: row * n + col + 1)
				matchesReference: (self referenceAtRow: row col: col order: n) ] ]
]

{ #category : 'tests - matmul' }
PVComputeTest >> testCompiledTiledMatmulMatchesTheReferenceAtOrder64 [
	"The tiled kernel written in Pharo source, element by element. The hand-built module is
	 checked the same way at the same order, so a difference between the two shows up here
	 rather than in the timing."

	| n result |
	n := 64.
	result := self runCompiledTiledMatmulOfOrder: n.
	self assert: result size equals: n * n.
	0 to: n - 1 do: [ :r |
		0 to: n - 1 do: [ :c |
			self
				assert: ((result at: r * n + c + 1)
						 - (self referenceAtRow: r col: c order: n)) abs < 0.001
				description: 'Element ' , r printString , ',' , c printString
					, ' is ' , (result at: r * n + c + 1) printString ] ]
]

{ #category : 'tests' }
PVComputeTest >> testComputeAtMostZeroOnDeviceClampsZeroItself [
	"The f32 <= mapping of the selector table, dispatched: a value at or below zero answers
	 zero and a value above it stands. Written because SpvOpcode class >> opFOrdLessThanEqual
	 answered 186, which is OpFOrdGreaterThan, so the comparison ran the other way round and
	 spirv-val had nothing to object to."

	| n bufIn bufOut kernel input result |
	n := 64.
	bufIn := VkBuffer storageBuffer: n on: ctx device.
	bufOut := VkBuffer storageBuffer: n on: ctx device.
	[
	input := (0 to: n - 1) asArray collect: [ :i | i - 32 ].
	bufIn putF32s: (input collect: [ :each | each asFloat ]).
	bufOut putF32s: (Array new: n withAll: -1.0).
	kernel := PVComputeKernel
		          fromMethod: PVKernelExamples >> #clampNonPositives:data:out:
		          on: ctx.
	kernel bindBuffer: bufIn.
	kernel bindBuffer: bufOut.
	kernel prepare.
	kernel dispatch: 1 y: 1 z: 1.
	result := bufOut getF32s.
	1 to: n do: [ :i |
		| expected |
		expected := (input at: i) <= 0
			            ifTrue: [ 0.0 ]
			            ifFalse: [ (input at: i) asFloat ].
		self assert: (result at: i) closeTo: expected ].
	kernel destroy ] ensure: [
		bufIn destroy.
		bufOut destroy ]
]

{ #category : 'tests - kernel' }
PVComputeTest >> testComputeKernelDeclaresNoSlotNothingReads [
	"A slot that is written and never read is not merely unused, it is misleading: workgroupX,
	 workgroupY and workgroupZ read like the workgroup size, which actually lives in
	 PVTypeAnnotation, while dispatch:y:z: uses its own arguments. Stated as the rule rather
	 than as three names, this keeps catching dead state added later."

	| unread |
	unread := PVComputeKernel slots reject: [ :slot |
		          PVComputeKernel methods anySatisfy: [ :method |
			          slot isReadIn: method ] ].
	self
		assertCollection: (unread collect: [ :slot | slot name ])
		hasSameElements: #(  )
]

{ #category : 'tests - kernel' }
PVComputeTest >> testComputeKernelPipelineExampleReportsEveryBindingAfterItsContextIsGone [
	"The example destroys the kernel and its context, as every example here does, so the
	 pipeline report must carry the binding list and the SPIR-V module the instance keeps.
	 The module's own storage-buffer count is the cross-check: a buffer bound that the shader
	 does not declare would show up as two different numbers. The invocation count is read
	 back from the module's OpExecutionMode, so it cannot drift from the group the example
	 dispatches."
	| kernel rows bindings |
	kernel := PVComputeExamples vectorAddKernelOnThisMachine.
	rows := kernel pipelineReport.
	bindings := rows select: [ :each |
		            (each at: #name) beginsWith: PVComputeKernel bindingRowPrefix ].
	self assert: bindings size equals: PVComputeKernel exampleBufferCount.
	bindings doWithIndex: [ :each :index |
		self
			assert: (each at: #name)
			equals: PVComputeKernel bindingRowPrefix , (index - 1) printString ].
	self
		assert: (self valueOfRowNamed: PVComputeKernel moduleBindingRowName in: rows)
		equals: PVComputeKernel exampleBufferCount printString.
	self
		assert: (self valueOfRowNamed: PVComputeKernel invocationsRowName in: rows)
		equals: PVComputeKernel exampleElementCount printString.
	self
		assert: (self valueOfRowNamed: PVComputeKernel pipelineRowName in: rows)
		equals: PVComputeKernel pipelineAbsentLabel
]

{ #category : 'tests - kernel' }
PVComputeTest >> testComputeKernelPipelineViewShowsAPreparedPipelineWithoutMutatingIt [
	"A kernel in the middle of a session is the interesting state: the pipeline is built and
	 the bindings are live. Building the tab must not change what the kernel reports, and a
	 kernel that has never been prepared must say so rather than reporting nothing."
	| buffers kernel before |
	buffers := (1 to: PVComputeKernel exampleBufferCount) collect: [ :each |
		           VkBuffer
			           storageBuffer: PVComputeKernel exampleElementCount
			           on: ctx device ].
	kernel := PVComputeKernel
		          fromMethod: PVComputeKernel exampleKernelMethod
		          on: ctx.
	[
	buffers do: [ :each | kernel bindBuffer: each ].
	kernel prepare.
	before := kernel pipelineReport.
	self
		assert: (self valueOfRowNamed: PVComputeKernel pipelineRowName in: before)
		equals: PVComputeKernel pipelineBuiltLabel.
	kernel inspectorPipeline: SpPresenter new.
	self
		assertCollection: (kernel pipelineReport collect: [ :each | each at: #value ])
		hasSameElements: (before collect: [ :each | each at: #value ]) ] ensure: [
		kernel destroy.
		buffers do: [ :each | each destroy ] ].
	self
		assert: (self
				 valueOfRowNamed: PVComputeKernel pipelineRowName
				 in: PVComputeKernel new pipelineReport)
		equals: PVComputeKernel pipelineAbsentLabel
]

{ #category : 'tests - kernel' }
PVComputeTest >> testComputeKernelUsesNoBareStageFlagLiteral [
	"prepare bound its descriptors with stageFlags: 32. A test asserting the value the layout
	 binds with would pass before the fix, because 32 is what VkShaderStage computeBit answers,
	 so it would prove nothing. The literal scan is the honest form of the no-magic-values rule."

	self deny:
		((PVComputeKernel >> #prepare) literals includes: VkShaderStage computeBit)
]

{ #category : 'tests - kernel' }
PVComputeTest >> testComputeKernelWithNoBuffersIsRefusedClearly [
	"A compute kernel taking only a work item and a shared tile is reachable, so prepare must
	 say what is missing. Observed on this device before the fix: a pool built for zero sets
	 was created happily, and the failure surfaced one call later out of allocateSet: as
	 VK_ERROR_OUT_OF_POOL_MEMORY, which named neither the kernel nor the buffers."
	| kernel raised |
	kernel := PVComputeKernel
		          fromMethod: PVComputeKernel exampleKernelMethod
		          on: ctx.
	raised := [
	          kernel prepare.
	          nil ]
		          on: VkError
		          do: [ :error | error messageText ].
	self assert: raised equals: PVComputeKernel noBuffersErrorMessage
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
PVComputeTest >> testComputePipelineRequestForARealModuleCarriesItsHandleAndLayout [
	"The declared request against a real driver: a shader module compiled from this project's
	 own SPIR-V and a pipeline layout created on the same device. The handles are read back
	 through the declared fields, so a field declared at the wrong offset or the wrong width
	 shows as a handle that is missing rather than as a driver that crashes later."

	| module setLayout pipelineLayout request rows |
	module := VkShaderModule
		          fromBytes: self buildVectorAddSpirv
		          device: ctx device.
	setLayout := VkDescriptorSetLayout on: ctx device.
	setLayout addStorageBufferBinding: 0 stageFlags: VkShaderStage computeBit.
	setLayout create.
	pipelineLayout := VkPipelineLayout
		                  on: ctx device
		                  setLayouts: (Array with: setLayout).
	[
	request := VkComputePipeline
		           createInfoForModule: module handle
		           entryPoint: VkShaderModule defaultEntryPoint
		           layout: pipelineLayout handle.
	rows := [ request computePipelineRows ] ensure: [
		        VkComputePipeline freeCreateInfo: request ].
	self assert: (rows at: #moduleGiven).
	self assert: (rows at: #layoutGiven).
	self
		assert: (rows at: #entryPoint)
		equals: VkShaderModule defaultEntryPoint.
	self
		assert: (rows at: #stageName)
		equals: (VkShaderStage nameForFlags: VkShaderStage computeBit).
	self deny: (rows at: #derivesFromAPipeline) ] ensure: [
		pipelineLayout destroy.
		setLayout destroy.
		module destroy ]
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

{ #category : 'tests - matmul' }
PVComputeTest >> testCooperativeMatrixKernelFromPharoSourceMatchesTheHandBuiltOne [
	"The DSL closes 7-H: the same product, compiled from Pharo source rather than built
	 instruction by instruction. Both modules are checked against the CPU reference, and
	 against each other, on the one device here that offers the extension. The two agree
	 exactly or not at all: they run the same instructions over the same halves, so any
	 difference would be a difference in what the emitter wrote, not rounding."

	| comparison coopContext |
	(PVCooperativeMatrixSurvey new setContext: ctx) availableSomewhere ifFalse: [
		^ self skip ].
	coopContext := VkContext cooperativeMatrixContext.
	comparison := [ (PVCooperativeMatrixComparison on: coopContext) run ]
		              ensure: [ coopContext destroy ].
	comparison referenceResult doWithIndex: [ :expected :index |
		self
			assertHalf: (comparison handBuiltResult at: index)
			matchesReference: expected.
		self
			assertHalf: (comparison compiledResult at: index)
			matchesReference: expected ].
	self assert: comparison compiledResult equals: comparison handBuiltResult
]

{ #category : 'tests - matmul' }
PVComputeTest >> testCooperativeMatrixKernelSourceRunsOnTheHost [
	"A kernel body has to mean the same thing in the image as on the device, which is what
	 makes the three selectors readable Pharo rather than markers for the compiler. On the
	 host there is one process and no subgroup, so a cooperative matrix is just an eight by
	 eight matrix of floats and the product is exact."

	| order left right output |
	order := PVCooperativeMatrixKernel matrixOrder.
	left := self flatMatrixOfOrder: order with: [ :r :c | self aAtRow: r col: c ].
	right := self flatMatrixOfOrder: order with: [ :r :c | self bAtRow: r col: c ].
	output := Array new: order * order withAll: 0.0.
	PVKernelExamples new coopMatrixProductOf: left by: right into: output.
	0 to: order - 1 do: [ :row |
		0 to: order - 1 do: [ :col |
			self
				assert: (output at: row * order + col + 1)
				closeTo: (self referenceAtRow: row col: col order: order) ] ]
]

{ #category : 'tests - matmul' }
PVComputeTest >> testCooperativeMatrixLoadThenStoreAnswersWhatWasLoaded [
	"The host load and store are each other's inverse, and the load copies: writing the
	 buffer afterwards must not change the matrix read out of it."

	| order buffer matrix destination |
	order := PVCooperativeMatrixKernel matrixOrder.
	buffer := (1 to: order * order) collect: [ :each | each asFloat ].
	matrix := buffer coopMatLoad: 0.
	buffer atAllPut: 0.0.
	destination := Array new: order * order withAll: 0.0.
	destination coopMatStore: matrix.
	self
		assert: destination
		equals: ((1 to: order * order) collect: [ :each | each asFloat ]) asArray.
	self assert: (matrix atRow: 1 col: 0) equals: order + 1.0
]

{ #category : 'tests - matmul' }
PVComputeTest >> testCooperativeMatrixMatmulOnDeviceMatchesTheReference [
	"The point of 7-H: a cooperative matrix multiply-accumulate that answers the same matrix
	 product the CPU does. The device is chosen by capability, not by position, because the
	 one device here that offers the extension is not the first enumerated. Half precision
	 inputs cannot carry the reference exactly, so the fact is the distance from it."

	| n result coopContext |
	(PVCooperativeMatrixSurvey new setContext: ctx) availableSomewhere ifFalse: [
		^ self skip ].
	coopContext := VkContext cooperativeMatrixContext.
	result := [ self runCooperativeMatrixMatmulOn: coopContext ] ensure: [
		          coopContext destroy ].
	n := PVCooperativeMatrixKernel matrixOrder.
	0 to: n - 1 do: [ :row |
		0 to: n - 1 do: [ :col |
			self
				assertHalf: (result at: row * n + col + 1)
				matchesReference: (self referenceAtRow: row col: col order: n) ] ]
]

{ #category : 'tests - matmul' }
PVComputeTest >> testCooperativeMatrixRefusesAnElementCountThatIsNotSquare [
	"A matrix built from the wrong number of elements would read past its own rows and
	 answer plausible nonsense, so it is refused where it is built."

	self
		should: [ PVCooperativeMatrix order: 8 elements: (Array new: 63 withAll: 0.0) ]
		raise: PVTypeError.
	self
		should: [
			(PVCooperativeMatrix order: 8 elements: (Array new: 64 withAll: 1.0))
				coopMatMulAdd:
					(PVCooperativeMatrix order: 4 elements: (Array new: 16 withAll: 1.0)) ]
		raise: PVTypeError
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
PVComputeTest >> testLocalInvocationIdOnDevice [
	"wi localX must read the LocalInvocationId built-in, which numbers an invocation inside
	 its own workgroup rather than inside the dispatch. The kernel uses it as an index, so
	 the output says which slot each invocation read: with two groups of eight, both groups
	 must read the first eight elements, which a global index could not do."

	| n groups bufIn bufOut kernel result |
	n := 16.
	groups := 2.
	bufIn := VkBuffer storageBuffer: n on: ctx device.
	bufOut := VkBuffer storageBuffer: n on: ctx device.
	[
	bufIn putF32s: ((0 to: n - 1) collect: [ :i | i asFloat ]).
	bufOut putF32s: (Array new: n withAll: -1.0).
	kernel := PVComputeKernel
		          fromMethod: PVKernelExamples >> #localIndexOf:data:out:
		          on: ctx.
	kernel bindBuffer: bufIn.
	kernel bindBuffer: bufOut.
	kernel prepare.
	kernel dispatch: groups y: 1 z: 1.
	result := bufOut getF32s.
	1 to: n do: [ :i |
		self assert: (result at: i) closeTo: ((i - 1) \\ 8) asFloat ].
	kernel destroy ] ensure: [
		bufIn destroy.
		bufOut destroy ]
]

{ #category : 'tests' }
PVComputeTest >> testMatmulF16OnDeviceHoldsAtTheBenchmarkSize [
	"The size the benchmark runs. A 512 term dot product is where accumulating in half would
	 drift far enough to fail, so this is what states the f32 accumulator earns its place."

	| n result |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	n := 512.
	result := self runMatmulOfOrder: n groups: n / 16 elementType: #f16.
	self matmulSamplePositions do: [ :row |
		self matmulSamplePositions do: [ :col |
			self
				assertHalf: (result at: row * n + col + 1)
				matchesReference: (self referenceAtRow: row col: col order: n) ] ]
]

{ #category : 'tests' }
PVComputeTest >> testMatmulF16OnDeviceMatchesTheReferenceWithinHalfTolerance [
	"Order 16 is one workgroup, so every output element is checked. Halves cannot carry the
	 reference exactly, so the fact to state is the distance from it, not equality."

	| n result |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	n := 16.
	result := self runMatmulOfOrder: n groups: 1 elementType: #f16.
	0 to: n - 1 do: [ :row |
		0 to: n - 1 do: [ :col |
			self
				assertHalf: (result at: row * n + col + 1)
				matchesReference: (self referenceAtRow: row col: col order: n) ] ]
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

{ #category : 'tests - control flow' }
PVComputeTest >> testNestedLoopsOnDevice [
	"A nested loop through the DSL, on the device. The inner loop runs twice per outer
	 iteration and the block the inner loop merges into adds one more element, so a dropped
	 outer loop, a dropped inner loop and a dropped merge block each give a different wrong
	 answer rather than all three giving the same one."

	| n bufIn bufOut kernel input expected result |
	n := 4.
	bufIn := VkBuffer storageBuffer: n on: ctx device.
	bufOut := VkBuffer storageBuffer: n on: ctx device.
	[
	input := #( 1.0 2.0 4.0 8.0 ).
	bufIn putF32s: input.
	bufOut putF32s: (Array new: n withAll: -1.0).
	expected := 4 * ((input at: 1) + (input at: 2))
	            + (input inject: 0.0 into: [ :a :b | a + b ]).
	kernel := PVComputeKernel
		          fromMethod: PVKernelExamples >> #nestedAccumulateOf:data:out:
		          on: ctx.
	kernel bindBuffer: bufIn.
	kernel bindBuffer: bufOut.
	kernel prepare.
	kernel dispatch: 1 y: 1 z: 1.
	result := bufOut getF32s.
	1 to: n do: [ :i | self assert: (result at: i) closeTo: expected ].
	kernel destroy ] ensure: [
		bufIn destroy.
		bufOut destroy ]
]

{ #category : 'tests' }
PVComputeTest >> testOpcodeProbeEmitsEveryInstructionItChecks [
	"The probe is only worth dispatching if its bytes really hold each instruction it was
	 written for: the twelve opcodes this unit added, the comparison whose constant was
	 wrong, and the multiply whose constant was wrong. The counts are read from the emitted
	 module, so an emitting method that stopped being called fails here."

	| rows |
	rows := PVOpcodeProbeKernel new instructionRows.
	#( #opConvertFToU #opConvertFToS #opUDiv #opUMod #opBitwiseAnd #opBitwiseOr
	   #opShiftLeftLogical #opShiftRightLogical #opLogicalAnd #opLogicalOr
	   #opLogicalNot #opSelect #opFOrdLessThanEqual #opVectorTimesMatrix )
		do: [ :each |
			self
				assert: (rows anySatisfy: [ :row | (row at: #name) = each ])
				description: each , ' is not in the module' ]
]

{ #category : 'tests' }
PVComputeTest >> testOpcodeProbeModuleIsValidSpirv [
	"The probe is hand-built, so the validator is what checks that each instruction takes the
	 operands its opcode expects: a constant holding another instruction's number is a type
	 error here even where the device would answer a number."

	| validator |
	PVSpirvValidator isAvailable ifFalse: [ ^ self skip ].
	validator := PVSpirvValidator on: PVOpcodeProbeKernel new spirv.
	self assert: validator isValid description: validator validationOutput
]

{ #category : 'tests' }
PVComputeTest >> testOpcodeProbeOnDeviceMatchesTheFormula [
	"Every opcode constant the probe sends, dispatched on the device and compared with the
	 formula the kernel states in Pharo. The constants of SpvOpcode are numbers nothing but
	 the device and the validator can check: three of them named another instruction than
	 their selector said, which is why the probe exists."

	| kernel inputs results |
	kernel := PVOpcodeProbeKernel new.
	inputs := PVOpcodeProbeKernel sampleInputs.
	results := kernel runOn: ctx.
	self assert: results size equals: inputs size.
	1 to: inputs size do: [ :each |
		self
			assert: (results at: each)
			closeTo: (PVOpcodeProbeKernel valueOf: (inputs at: each) at: each - 1) ]
]

{ #category : 'tests - benchmark' }
PVComputeTest >> testPrecisionComparisonOnTheTiledFamilyMeasuresTiledKernels [
	"The measurement half precision was missing: the naive matmul is bound by global memory
	 traffic, so a precision ratio taken there says little about the format. The tiled kernel
	 reads each tile from shared memory sixteen times, so narrowing the tiles is visible in
	 the time. Both precisions are measured in the one run, at one order and one repeat
	 count."

	| comparison |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	comparison := PVPrecisionComparison
		              on: ctx
		              order: 128
		              repeats: 2
		              family: PVKernelExamples tiledMatmulFamily.
	self
		assert: comparison family
		equals: PVKernelExamples tiledMatmulFamily.
	PVBenchmark elementTypes do: [ :elementType |
		| benchmark |
		benchmark := comparison benchmarkFor: elementType.
		self
			assert: benchmark kernelMethod
			equals: (PVKernelExamples tiledMatmulFor: elementType).
		self assert: benchmark result order equals: 128.
		self assert: benchmark result milliseconds >= 0 ]
]

{ #category : 'tests - benchmark' }
PVComputeTest >> testPrecisionComparisonReportNamesTheKernelBesideEachPrecision [
	"A precision table holds one row per precision, so the kernel belongs in the row rather
	 than in the title: the same comparison reads either family, and a row taken from the
	 benchmark that produced it cannot name the other one."

	| comparison rows |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	comparison := PVPrecisionComparison
		              on: ctx
		              order: 128
		              repeats: 1
		              family: PVKernelExamples tiledMatmulFamily.
	rows := comparison reportRows.
	PVBenchmark elementTypes doWithIndex: [ :elementType :index |
		self
			assert: ((rows at: index) at: #kernel)
			equals:
			(PVKernelExamples tiledMatmulFor: elementType) selector asString ]
]

{ #category : 'tests' }
PVComputeTest >> testPrecisionComparisonReportsOneRowPerElementType [
	"The table is read against the baseline, so it holds one row per precision in a fixed
	 order and the baseline's own speedup is one. Order 256 because a ratio needs a time the
	 host clock can see."

	| comparison rows |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	comparison := PVPrecisionComparison on: ctx order: 256 repeats: 2.
	rows := comparison reportRows.
	self
		assert: (rows collect: [ :row | row at: #name ]) asArray
		equals: (PVBenchmark elementTypes collect: [ :each | each asString ]) asArray.
	self
		assert: ((rows detect: [ :row |
				  (row at: #name) = PVBenchmark defaultElementType asString ]) at: #speedup)
		equals: '1.0'
]

{ #category : 'tests' }
PVComputeTest >> testPrecisionComparisonSpeedupNeedsTwoMeasuredTimes [
	"Half the time is twice the speed. A dispatch too quick for the host clock has no ratio,
	 and reporting one would be division by zero in one direction or a lie in the other."

	self
		assert: (PVPrecisionComparison speedupOfMilliseconds: 5 against: 10)
		closeTo: 2.0
		precision: 0.001.
	self assert: (PVPrecisionComparison speedupOfMilliseconds: 0 against: 10) isNil.
	self assert: (PVPrecisionComparison speedupOfMilliseconds: 5 against: 0) isNil
]

{ #category : 'tests' }
PVComputeTest >> testPrecisionComparisonTimesEveryElementTypeAtTheSameOrder [
	"The honest way to state a precision speedup: the same matrix order, the same repeat
	 count, one kernel per precision, measured in the one run."

	| comparison |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	comparison := PVPrecisionComparison on: ctx order: 128 repeats: 3.
	PVBenchmark elementTypes do: [ :each |
		| benchmark |
		benchmark := comparison benchmarkFor: each.
		self assert: benchmark elementType equals: each.
		self assert: benchmark result order equals: 128.
		self assert: benchmark result repeats equals: 3.
		self assert: benchmark result milliseconds >= 0 ]
]

{ #category : 'tests - shader module' }
PVComputeTest >> testShaderModuleReportsTheCodeItWasGiven [
	"The driver leg of the shader module create info: real SPIR-V, created on this machine's
	 device. The module keeps the byte count it was given, so the Module tab answers after the
	 handle has gone, and the word count is the byte count divided by the four bytes a SPIR-V
	 word takes."

	| bytes module rows |
	bytes := self buildVectorAddSpirv.
	module := VkShaderModule fromBytes: bytes device: ctx device.
	[
		self deny: module handle isNull.
		rows := module moduleRows.
		self assert: (rows at: #bytes) equals: bytes size.
		self
			assert: (rows at: #words)
			equals: bytes size // VkShaderModuleCreateInfo codeWordByteCount.
		self assert: (rows at: #wholeWords).
		self assert: (rows at: #live) ] ensure: [ module destroy ].
	self assert: (module moduleRows at: #bytes) equals: bytes size.
	self deny: (module moduleRows at: #live)
]

{ #category : 'tests' }
PVComputeTest >> testSharedMemoryBroadcastWithinWorkgroupOnDevice [
	"Shared memory and the barrier, through the DSL rather than through a hand-built module.
	 Each invocation copies its own element into its slot of the tile, waits at the barrier,
	 then reads slot zero — a slot another invocation filled. Every invocation of a workgroup
	 must therefore answer that workgroup's first element, which no private variable could
	 produce, and which would be a race without the barrier."

	| n width groups bufIn bufOut kernel input result |
	n := 32.
	width := 8.
	groups := n // width.
	bufIn := VkBuffer storageBuffer: n on: ctx device.
	bufOut := VkBuffer storageBuffer: n on: ctx device.
	[
	input := (1 to: n) collect: [ :i | i asFloat * 10.0 ].
	bufIn putF32s: input.
	bufOut putF32s: (Array new: n withAll: -1.0).
	kernel := PVComputeKernel
		          fromMethod: PVKernelExamples >> #broadcastFirstOf:data:out:tile:
		          on: ctx.
	kernel bindBuffer: bufIn.
	kernel bindBuffer: bufOut.
	kernel prepare.
	kernel dispatch: groups y: 1 z: 1.
	result := bufOut getF32s.
	1 to: n do: [ :i |
		self
			assert: (result at: i)
			closeTo: (input at: (i - 1) // width * width + 1) ].
	kernel destroy ] ensure: [
		bufIn destroy.
		bufOut destroy ]
]

{ #category : 'tests' }
PVComputeTest >> testSubgroupDotExampleReportsEveryRowAfterItsContextIsGone [
	"The example destroys the context it built, as every example here does, so a run must
	 carry the device facts it reports rather than asking a destroyed context for them."

	| run |
	ctx subgroupArithmeticAvailable ifFalse: [ ^ self skip ].
	run := PVComputeExamples subgroupDotOf1024Elements.
	self assert: run reportedSubgroupSize isInteger.
	self assert: (run reportRows anySatisfy: [ :each |
			 (each at: #name) = 'Subgroup width measured' ])
]

{ #category : 'tests' }
PVComputeTest >> testSubgroupDotMeasuresTheWidthTheShaderRanAt [
	"The width the kernel counts is not the width the device reports. A driver compiles a
	 shader to whichever subgroup width it likes, no wider than the one the device offers,
	 and this one picks half of it. Dividing by the reported width is what made the first
	 version of this run answer half the dot product."

	| run |
	ctx subgroupArithmeticAvailable ifFalse: [ ^ self skip ].
	run := PVSubgroupDotProduct on: ctx size: 1024.
	run run.
	self assert: run measuredSubgroupSize isPowerOfTwo.
	self assert: run measuredSubgroupSize <= run reportedSubgroupSize.
	self assert: (run laneCounts allSatisfy: [ :each |
			 each asInteger = run measuredSubgroupSize ])
]

{ #category : 'tests' }
PVComputeTest >> testSubgroupDotOnDeviceMatchesTheCpuSum [
	"A dot product over 1024 elements reduced in hardware. Every lane of a subgroup holds the
	 same partial sum, so the sum of all the slots counts each subgroup's total once per lane
	 and the subgroup size divides it out. That recovery needs no assumption about which lanes
	 share a subgroup, which the specification leaves to the implementation."

	| run |
	ctx subgroupArithmeticAvailable ifFalse: [ ^ self skip ].
	run := PVSubgroupDotProduct on: ctx size: 1024.
	run run.
	self assert: run gpuTotal closeTo: run cpuTotal
]

{ #category : 'tests' }
PVComputeTest >> testSubgroupDotRefusesADeviceWithoutTheArithmetic [
	"The degenerate device. A run that went ahead anyway would dispatch a kernel the driver
	 may reject, so the refusal has to name what is missing rather than return a wrong number."

	| run raised |
	run := PVNoSubgroupArithmeticStub on: ctx size: 64.
	raised := nil.
	[ run run ] on: PVTypeError do: [ :e | raised := e messageText ].
	self deny: raised isNil.
	self assert: (raised includesSubstring: 'subgroup')
]

{ #category : 'tests' }
PVComputeTest >> testSubgroupDotSlotsHoldMoreThanOneLaneProduct [
	"What proves the reduction ran rather than the multiplication alone: every product is
	 positive here, so a slot holding its own lane's product would be smaller than the
	 subgroup's total. A kernel that dropped the group operation would fail this and still
	 pass spirv-val."

	| run |
	ctx subgroupArithmeticAvailable ifFalse: [ ^ self skip ].
	run := PVSubgroupDotProduct on: ctx size: 1024.
	run run.
	run partialSums doWithIndex: [ :each :i |
		self assert: each > (run productAt: i) ]
]

{ #category : 'tests' }
PVComputeTest >> testTiledComparisonExampleReportsEveryRowAfterItsContextIsGone [
	"The example destroys the context it built, and a table is read long after that, so
	 every row has to come from what the run kept rather than from the device."

	| comparison rows |
	comparison := PVBenchmarkExamples tiledMatmulComparisonAtOrder256.
	rows := comparison reportRows.
	self assert: rows size > 1.
	rows do: [ :each |
		self deny: (each at: #value) isEmpty description: (each at: #name) ]
]

{ #category : 'tests' }
PVComputeTest >> testTiledComparisonRejectsAnOrderTheGridCannotCover [
	"Both kernels take the matrix order from the dispatch grid, so an order the tile width
	 does not divide has no grid and must be refused rather than timed."

	self
		should: [
			PVTiledMatmulComparison
				on: ctx
				order: PVTiledMatmulKernel tileWidth + 1
				repeats: 1 ]
		raise: PVTypeError
]

{ #category : 'tests' }
PVComputeTest >> testTiledComparisonReportBeforeAnyRun [
	"A table opened on a comparison that has not run says so, rather than showing a ratio
	 of nothing against nothing."

	| rows |
	rows := (PVTiledMatmulComparison on: ctx order: 64 repeats: 1) reportRows.
	self assert: rows size equals: 1.
	self assert: ((rows first at: #value) includesSubstring: 'not run')
]

{ #category : 'tests-compute' }
PVComputeTest >> testTiledComparisonReportNamesTheCompiledKernel [
	"A table that shows two kernels where three ran would hide the measurement the DSL
	 was added for."

	| names |
	names := ((PVTiledMatmulComparison on: ctx order: 64 repeats: 1) run
		          reportRows collect: [ :each | each at: #name ]) asArray.
	self assert: (names includes: 'Compiled milliseconds').
	self assert: (names includes: 'Compiled GFLOP/s').
	self assert: (names includes: 'Cost of going through the DSL').
	self assert:
		(names includes: 'Largest difference between compiled and hand-built')
]

{ #category : 'tests' }
PVComputeTest >> testTiledComparisonTimesBothKernelsOnTheSameData [
	"The comparison is only a comparison if both kernels ran at the same order on the same
	 buffers and agreed on the answer."

	| comparison |
	comparison := (PVTiledMatmulComparison on: ctx order: 128 repeats: 3) run.
	self assert: comparison tiledResult order equals: 128.
	self assert: comparison naiveResult order equals: 128.
	self assert: comparison tiledResult repeats equals: 3.
	self assert: comparison maximumDifference < 0.001.
	self assert: comparison speedup isNumber
]

{ #category : 'tests-compute' }
PVComputeTest >> testTiledComparisonTimesTheCompiledKernelBesideTheHandBuiltOne [
	"The comparison is the only place the cost of going through the DSL is visible, so it
	 has to time the compiled kernel on the same buffers as the other two and say whether
	 it agreed with them."

	| comparison |
	comparison := (PVTiledMatmulComparison on: ctx order: 128 repeats: 3) run.
	self assert: comparison compiledResult order equals: 128.
	self assert: comparison compiledResult repeats equals: 3.
	self assert: comparison maximumCompiledDifference < 0.001.
	self assert: comparison compiledCost isNumber
]

{ #category : 'tests' }
PVComputeTest >> testTiledMatmulAtOrder512MatchesTheNaiveKernelAtSampledPositions [
	"The benchmark size. Both kernels run on the same inputs, so the tiled one is read
	 against the kernel it is meant to replace as well as against the host reference."

	| n tiled naive |
	n := 512.
	tiled := self runTiledMatmulOfOrder: n.
	naive := self
		         runMatmulOfOrder: n
		         groups: n // (PVBenchmark workgroupWidthFor: #f32).
	self matmulSamplePositions do: [ :r |
		self matmulSamplePositions do: [ :c |
			| index |
			index := r * n + c + 1.
			self
				assert: ((tiled at: index) - (self referenceAtRow: r col: c order: n)) abs
						< 0.001
				description: 'Tiled element ' , r printString , ',' , c printString
					, ' is ' , (tiled at: index) printString.
			self
				assert: ((tiled at: index) - (naive at: index)) abs < 0.001
				description: 'Tiled and naive disagree at ' , r printString , ','
					, c printString ] ]
]

{ #category : 'tests' }
PVComputeTest >> testTiledMatmulMatchesTheReferenceAtOrder64 [
	"Every element, not a sample: a tiling bug shows up as a wrong tile, and at order 64
	 the whole matrix is cheap enough to check."

	| n result |
	n := 64.
	result := self runTiledMatmulOfOrder: n.
	self assert: result size equals: n * n.
	0 to: n - 1 do: [ :r |
		0 to: n - 1 do: [ :c |
			self
				assert: ((result at: r * n + c + 1)
						 - (self referenceAtRow: r col: c order: n)) abs < 0.001
				description: 'Element ' , r printString , ',' , c printString
					, ' is ' , (result at: r * n + c + 1) printString ] ]
]

{ #category : 'tests' }
PVComputeTest >> testTiledMatmulModuleDeclaresTwoSharedTilesAndTwoBarriers [
	"The shape of the tiled kernel, read back from the bytes it emits: one shared tile per
	 input matrix, a barrier on each side of the accumulation loop, and two nested loops."

	| module |
	module := PVSpirvValidator on: PVTiledMatmulKernel new spirv.
	self
		assert: (module variableCountInStorageClass: SpvStorageClass workgroup)
		equals: 2.
	self assert: (module countOfOpcode: SpvOpcode opControlBarrier) equals: 2.
	self assert: (module countOfOpcode: SpvOpcode opLoopMerge) equals: 2
]

{ #category : 'tests' }
PVComputeTest >> testTiledMatmulModuleIsValidSpirv [
	"The kernel is hand-built rather than compiled, so nothing but the validator checks its
	 structured control flow, its Workgroup variables and its barrier operands."

	| validator |
	PVSpirvValidator isAvailable ifFalse: [ ^ self skip ].
	validator := PVSpirvValidator on: PVTiledMatmulKernel new spirv.
	self assert: validator isValid description: validator validationOutput
]

{ #category : 'tests' }
PVComputeTest >> testTiledMatmulSharedTilesFitTheDeviceLimit [
	"A tile pair that does not fit is not a slow kernel, it is a pipeline the driver
	 refuses, so the size is read against the limit this device reports."

	| kernel |
	kernel := PVTiledMatmulKernel new.
	self assert: kernel sharedMemoryBytes > 0.
	self
		assert: kernel sharedMemoryBytes <= ctx physicalDevice maxComputeSharedMemorySize
		description: 'Tile pair of ' , kernel sharedMemoryBytes printString
			, ' bytes exceeds the device limit of '
			, ctx physicalDevice maxComputeSharedMemorySize printString
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
PVComputeTest >> testVectorAddF16OnDevice [
	"The half path end to end: halves in the buffers, halves out, with values small enough
	 that every input and every sum is an exact half, so the equality is the right fact to
	 state and no tolerance hides a wrong answer."

	| n bufA bufB bufC kernel result |
	ctx halfPrecisionAvailable ifFalse: [ ^ self skip ].
	n := 64.
	bufA := VkBuffer storageBufferOfHalves: n on: ctx device.
	bufB := VkBuffer storageBufferOfHalves: n on: ctx device.
	bufC := VkBuffer storageBufferOfHalves: n on: ctx device.
	[
	bufA putF16s: ((0 to: n - 1) collect: [ :i | i asFloat ]).
	bufB putF16s: ((0 to: n - 1) collect: [ :i | i asFloat ]).
	bufC putF16s: (Array new: n withAll: 0.0).
	kernel := PVComputeKernel
		          fromMethod: PVKernelExamples >> #vectorAddF16:a:b:out:
		          on: ctx.
	[
	kernel bindBuffer: bufA.
	kernel bindBuffer: bufB.
	kernel bindBuffer: bufC.
	kernel prepare.
	kernel dispatch: 1 y: 1 z: 1.
	result := bufC getF16s.
	0 to: n - 1 do: [ :i |
		self assert: (result at: i + 1) equals: (i * 2) asFloat ] ] ensure: [
		kernel destroy ] ] ensure: [
		bufA destroy.
		bufB destroy.
		bufC destroy ]
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

{ #category : 'support' }
PVComputeTest >> valueOfRowNamed: aString in: someRows [
	^ (someRows detect: [ :each | (each at: #name) = aString ]) at: #value
]
