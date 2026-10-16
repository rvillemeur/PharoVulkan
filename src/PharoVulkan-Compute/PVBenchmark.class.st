"
Times one matmul kernel on the device. Build it with on:order:repeats:kernel: to name the kernel, on:order:repeats:elementType: for the naive matmul of one precision, or on:order:repeats: for the float baseline; send run to measure, and read the numbers through reportRows or the Benchmark tab. The element type, the workgroup width and the kernel row of the report are all read off the kernel's own pragmas, so the benchmark cannot fill buffers of one width and dispatch a module of another. A kernel whose buffers mix widths is refused at creation. PVPrecisionComparison runs one of these per precision at the same order.
"
Class {
	#name : 'PVBenchmark',
	#superclass : 'Object',
	#instVars : [
		'context',
		'order',
		'repeats',
		'result',
		'kernelMethod'
	],
	#category : 'PharoVulkan-Compute-Benchmarks',
	#package : 'PharoVulkan-Compute',
	#tag : 'Benchmarks'
}

{ #category : 'constants' }
PVBenchmark class >> defaultElementType [
	"Float is the baseline every other precision is read against."

	^ #f32
]

{ #category : 'accessing' }
PVBenchmark class >> elementTypeOfKernel: aCompiledMethod [
	"The precision a kernel's storage buffers hold, read off its own <param:> pragmas, so the
	 buffers a benchmark fills hold the width the module loads. A kernel whose buffers mix
	 widths is refused rather than measured at one of them: three buffers of one width is the
	 only shape this benchmark fills."

	| widths |
	widths := (((PVTypeAnnotation fromMethod: aCompiledMethod) params
		            collect: [ :each | each type ])
		           select: [ :each |
			           PVSPIRVEmitter bufferElementTypes includesKey: each ])
		          collect: [ :each | PVSPIRVEmitter elementTypeOf: each ].
	widths asSet size = 1 ifFalse: [
		PVTypeError signal: 'A benchmark fills buffers of one width, and '
			, aCompiledMethod selector , ' declares ' , widths asSet size printString ].
	^ widths anyOne
]

{ #category : 'accessing' }
PVBenchmark class >> elementTypes [
	"Every precision a matmul kernel exists for, so a comparison covers what the compiler can
	 dispatch rather than a list kept here by hand."

	^ PVKernelExamples matmulKernels keys asSortedCollection asArray
]

{ #category : 'accessing' }
PVBenchmark class >> kernelMethodFor: anElementTypeSymbol [
	"The naive matmul of one precision. An unknown precision raises, because there is no
	 kernel to time and a float fallback would report the wrong number."

	^ PVKernelExamples matmulFor: anElementTypeSymbol
]

{ #category : 'instance creation' }
PVBenchmark class >> on: aContext order: n repeats: count [
	^ self
		  on: aContext
		  order: n
		  repeats: count
		  elementType: self defaultElementType
]

{ #category : 'instance creation' }
PVBenchmark class >> on: aContext order: n repeats: count elementType: anElementTypeSymbol [
	"The naive matmul of one precision: the family every other one is read against. Another
	 family is measured by naming its kernel with on:order:repeats:kernel:."

	^ self
		  on: aContext
		  order: n
		  repeats: count
		  kernel: (self kernelMethodFor: anElementTypeSymbol)
]

{ #category : 'instance creation' }
PVBenchmark class >> on: aContext order: n repeats: count kernel: aCompiledMethod [
	"The kernel takes N from the dispatch grid, so a grid must exist that covers the matrix
	 exactly. The width comes from the kernel itself, which is also what the element type and
	 the report's kernel row are read off."

	| width |
	"Asked for its refusal: a kernel whose buffers mix widths has nothing this benchmark can
	 fill, and finding that out at creation beats finding it out mid-measurement."
	self elementTypeOfKernel: aCompiledMethod.
	width := self workgroupWidthForKernel: aCompiledMethod.
	n \\ width = 0 ifFalse: [
		PVTypeError signal: 'Matrix order ' , n printString
			, ' is not a multiple of the kernel workgroup width ' , width printString ].
	^ self new
		  setContext: aContext
		  order: n
		  repeats: count
		  kernel: aCompiledMethod
]

{ #category : 'accessing' }
PVBenchmark class >> workgroupWidthFor: anElementTypeSymbol [
	^ self workgroupWidthForKernel:
		  (self kernelMethodFor: anElementTypeSymbol)
]

{ #category : 'accessing' }
PVBenchmark class >> workgroupWidthForKernel: aCompiledMethod [
	"Asked of the kernel's own <localSize:> pragma, so the benchmark cannot disagree with the
	 module it dispatches."

	^ (PVTypeAnnotation fromMethod: aCompiledMethod) localSize first
]

{ #category : 'accessing' }
PVBenchmark >> elementType [
	"Read off the kernel rather than carried beside it: the buffers filled here and the
	 buffers the module loads are then the same width by construction."

	^ self class elementTypeOfKernel: kernelMethod
]

{ #category : 'accessing' }
PVBenchmark >> groupCount [
	"One invocation per output element, so the grid is the matrix divided by the workgroup."

	^ order // self workgroupWidth
]

{ #category : 'private' }
PVBenchmark >> inputMatrixWithOffset: anInteger [
	"Deterministic filler. The benchmark does not check the result, so the only thing that
	 matters is that the values are finite and the two matrices differ."

	^ (1 to: order * order) collect: [ :i | ((i + anInteger) \\ 7) / 7.0 ]
]

{ #category : 'inspector' }
PVBenchmark >> inspectorBenchmark: aBuilder [
	"The measurement, and the configuration it belongs to. A rate without the matrix order
	 and the workgroup beside it is not a result anybody can repeat."

	<inspectorPresentationOrder: 10 title: 'Benchmark'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Quantity' evaluated: [ :each |
					   each at: #name ]);
		  addColumn:
			  (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each at: #value ]);
		  items: self reportRows;
		  yourself
]

{ #category : 'accessing' }
PVBenchmark >> kernelMethod [
	^ kernelMethod
]

{ #category : 'running' }
PVBenchmark >> newBuffers [
	"Three buffers of the precision under measurement, so the bytes moved per dispatch are
	 the bytes that precision actually moves."

	| a b out elementType |
	elementType := self elementType.
	a := VkBuffer storageBuffer: order * order of: elementType on: context device.
	b := VkBuffer storageBuffer: order * order of: elementType on: context device.
	out := VkBuffer
		       storageBuffer: order * order
		       of: elementType
		       on: context device.
	a put: (self inputMatrixWithOffset: 0) as: elementType.
	b put: (self inputMatrixWithOffset: 1) as: elementType.
	out put: (Array new: order * order withAll: 0.0) as: elementType.
	^ {
		  a.
		  b.
		  out }
]

{ #category : 'reporting' }
PVBenchmark >> reportRows [
	"One row per fact about the measurement. Every number is asked of the result or of the
	 kernel's own annotation, so the table cannot disagree with what ran."

	result ifNil: [
		^ { (Dictionary newFrom: {
				    (#name -> 'State').
				    (#value -> 'not run yet') }) } ].
	^ {
		  (self rowNamed: 'Element type' value: self elementType asString).
		  (self rowNamed: 'Kernel' value: self kernelMethod selector asString).
		  (self rowNamed: 'Matrix order' value: result order printString).
		  (self
			   rowNamed: 'Workgroup width'
			   value: self workgroupWidth printString).
		  (self rowNamed: 'Groups per side' value: self groupCount printString).
		  (self rowNamed: 'Dispatches timed' value: result repeats printString).
		  (self
			   rowNamed: 'Milliseconds per dispatch'
			   value: result milliseconds printString).
		  (self
			   rowNamed: 'Floating point operations'
			   value: result floatingPointOperations printString).
		  (self
			   rowNamed: 'GFLOP/s'
			   value: (result gigaflopsPerSecond
					    ifNil: [ 'too quick to measure' ]
					    ifNotNil: [ :rate | rate printString ])) }
]

{ #category : 'accessing' }
PVBenchmark >> result [
	^ result
]

{ #category : 'reporting' }
PVBenchmark >> rowNamed: aString value: aValueString [
	^ Dictionary newFrom: {
			  (#name -> aString).
			  (#value -> aValueString) }
]

{ #category : 'measuring' }
PVBenchmark >> run [
	"Answer a PVBenchmarkResult for this configuration. Buffers and pipeline are built and
	 destroyed around the measurement, so repeated runs do not accumulate device memory."

	| buffers |
	buffers := self newBuffers.
	^ [ self runWithBuffers: buffers ] ensure: [
		  buffers do: [ :each | each destroy ] ]
]

{ #category : 'private' }
PVBenchmark >> runWithBuffers: buffers [
	| kernel |
	kernel := PVComputeKernel fromMethod: self kernelMethod on: context.
	buffers do: [ :each | kernel bindBuffer: each ].
	kernel prepare.
	^ [ self timeDispatchesOf: kernel ] ensure: [ kernel destroy ]
]

{ #category : 'initialization' }
PVBenchmark >> setContext: aContext order: n repeats: count kernel: aCompiledMethod [
	context := aContext.
	order := n.
	repeats := count.
	kernelMethod := aCompiledMethod
]

{ #category : 'private' }
PVBenchmark >> timeDispatchesOf: aKernel [
	"The first dispatch is thrown away: it carries pipeline warm-up and first-touch of the
	 buffers. dispatch:y:z: waits on the queue, so the host clock around it measures the
	 whole dispatch and nothing finer."

	| groups total |
	groups := self groupCount.
	aKernel dispatch: groups y: groups z: 1.
	total := Time millisecondsToRun: [
		         repeats timesRepeat: [ aKernel dispatch: groups y: groups z: 1 ] ].
	result := PVBenchmarkResult
		          order: order
		          milliseconds: (total / repeats) asFloat
		          repeats: repeats.
	^ result
]

{ #category : 'accessing' }
PVBenchmark >> workgroupWidth [
	^ self class workgroupWidthForKernel: kernelMethod
]
