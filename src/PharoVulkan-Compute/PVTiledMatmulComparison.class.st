"
Times the tiled matmul of PVTiledMatmulKernel against the naive kernel of 7-C at one matrix order, on one pair of input matrices, and reports both times, the ratio between them and the largest difference between the two results. The ratio is the number Phase 7 item 7-G turns on: a tiled kernel that is not faster is not worth teaching the structured control flow recogniser.

Build it with on:order:repeats:, send run, and read the numbers through reportRows or the Comparison tab. Both kernels take the matrix order from the dispatch grid, so the order has to be a multiple of the tile width. Key methods: run, speedup, maximumDifference, reportRows.
"
Class {
	#name : 'PVTiledMatmulComparison',
	#superclass : 'Object',
	#instVars : [
		'context',
		'order',
		'repeats',
		'tiledResult',
		'naiveResult',
		'maximumDifference',
		'compiledResult',
		'maximumCompiledDifference'
	],
	#category : 'PharoVulkan-Compute-Benchmarks',
	#package : 'PharoVulkan-Compute',
	#tag : 'Benchmarks'
}

{ #category : 'constants' }
PVTiledMatmulComparison class >> compiledKernelMethod [
	"The tiled matmul written in Pharo source. It is named here rather than inline so the
	 comparison times the same method the compiler tests check against the CPU reference."

	^ PVKernelExamples >> #tiledMatmulF32:a:b:out:tileA:tileB:
]

{ #category : 'instance creation' }
PVTiledMatmulComparison class >> on: aContext order: n repeats: count [
	"Both kernels read the matrix order from the dispatch grid, so a grid has to exist that
	 covers the matrix exactly. The tile width is the coarser of the two workgroup widths,
	 so it is the one that decides."

	n \\ PVTiledMatmulKernel tileWidth = 0 ifFalse: [
		PVTypeError signal: 'Matrix order ' , n printString
			, ' is not a multiple of the tile width '
			, PVTiledMatmulKernel tileWidth printString ].
	^ self new
		  setContext: aContext
		  order: n
		  repeats: count
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> compiledCost [
	"What going through the DSL costs: the compiled kernel's time over the hand-built
	 kernel's, so 1.0 means the compiler gave away nothing. A dispatch too quick for the
	 host clock leaves no ratio to report, which is answered as nil rather than as a
	 division."

	(compiledResult isNil or: [ tiledResult isNil ]) ifTrue: [ ^ nil ].
	tiledResult milliseconds = 0 ifTrue: [ ^ nil ].
	^ compiledResult milliseconds / tiledResult milliseconds
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> compiledResult [
	^ compiledResult
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> elementType [
	"Float, the precision the 7-C baseline was measured in. Asked of the kernel's own
	 buffer type, so the buffers cannot be allocated at a width the kernel does not read."

	^ PVSPIRVEmitter elementTypeOf: PVTiledMatmulKernel bufferElementType
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> groupCount [
	"One invocation per output element, so the grid is the matrix divided by the tile."

	^ order // PVTiledMatmulKernel tileWidth
]

{ #category : 'private' }
PVTiledMatmulComparison >> inputMatrixWithOffset: anInteger [
	"Deterministic filler, and the two matrices differ: a kernel that swapped a row for a
	 column would otherwise agree with one that did not."

	^ (1 to: order * order) collect: [ :i | ((i + anInteger) \\ 7) / 7.0 ]
]

{ #category : 'inspector' }
PVTiledMatmulComparison >> inspectorComparison: aBuilder [
	"Both measurements and the ratio between them, beside the largest difference between
	 the two results: a speedup without the agreement beside it says nothing."

	<inspectorPresentationOrder: 10 title: 'Comparison'>
	^ PVFactRow
		  tableOf: self reportRows
		  nameColumn: 'Quantity'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> maximumCompiledDifference [
	^ maximumCompiledDifference
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> maximumDifference [
	^ maximumDifference
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> naiveResult [
	^ naiveResult
]

{ #category : 'private' }
PVTiledMatmulComparison >> newBuffers [
	"One set of buffers for both kernels: the comparison is only fair if the data and the
	 memory it sits in are the same for each."

	| a b out |
	a := VkBuffer storageBuffer: order * order of: self elementType on: context device.
	b := VkBuffer storageBuffer: order * order of: self elementType on: context device.
	out := VkBuffer
		       storageBuffer: order * order
		       of: self elementType
		       on: context device.
	a put: (self inputMatrixWithOffset: 0) as: self elementType.
	b put: (self inputMatrixWithOffset: 1) as: self elementType.
	out put: (Array new: order * order withAll: 0.0) as: self elementType.
	^ {
		  a.
		  b.
		  out }
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> order [
	^ order
]

{ #category : 'reporting' }
PVTiledMatmulComparison >> rateStringOf: aResult [
	^ aResult gigaflopsPerSecond
		  ifNil: [ 'too quick to measure' ]
		  ifNotNil: [ :rate | rate printString ]
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> repeats [
	^ repeats
]

{ #category : 'reporting' }
PVTiledMatmulComparison >> reportRows [
	"One row per fact about the three runs. Every number is asked of a result or of the
	 kernel itself, so the table cannot disagree with what ran."

	tiledResult ifNil: [
		^ { (PVFactRow name: 'State' value: 'not run yet') } ].
	^ {
		  (PVFactRow name: 'Matrix order' value: order).
		  (PVFactRow name: 'Tile width' value: PVTiledMatmulKernel tileWidth).
		  (PVFactRow
			   name: 'Shared memory bytes per group'
			   value: PVTiledMatmulKernel new sharedMemoryBytes).
		  (PVFactRow name: 'Dispatches timed' value: repeats).
		  (PVFactRow
			   name: 'Tiled milliseconds'
			   value: tiledResult milliseconds).
		  (PVFactRow
			   name: 'Naive milliseconds'
			   value: naiveResult milliseconds).
		  (PVFactRow
			   name: 'Compiled milliseconds'
			   value: compiledResult milliseconds).
		  (PVFactRow
			   name: 'Tiled GFLOP/s'
			   value: (self rateStringOf: tiledResult)).
		  (PVFactRow
			   name: 'Naive GFLOP/s'
			   value: (self rateStringOf: naiveResult)).
		  (PVFactRow
			   name: 'Compiled GFLOP/s'
			   value: (self rateStringOf: compiledResult)).
		  (PVFactRow name: 'Speedup' value: (self speedup
				    ifNil: [ 'too quick to measure' ]
				    ifNotNil: [ :ratio | ratio asFloat printString ])).
		  (PVFactRow
			   name: 'Cost of going through the DSL'
			   value: (self compiledCost
					    ifNil: [ 'too quick to measure' ]
					    ifNotNil: [ :ratio | ratio asFloat printString ])).
		  (PVFactRow
			   name: 'Largest difference between tiled and naive'
			   value: maximumDifference).
		  (PVFactRow
			   name: 'Largest difference between compiled and hand-built'
			   value: maximumCompiledDifference) }
]

{ #category : 'measuring' }
PVTiledMatmulComparison >> run [
	"Answer self, with both measurements and the difference between the two results filled
	 in. The buffers are built and destroyed around the pair of runs, so repeated
	 comparisons do not accumulate device memory."

	| buffers |
	buffers := self newBuffers.
	^ [ self runWithBuffers: buffers ] ensure: [
		  buffers do: [ :each | each destroy ] ]
]

{ #category : 'running' }
PVTiledMatmulComparison >> runWithBuffers: buffers [
	"The hand-built tiled kernel first, then the naive one, then the tiled kernel compiled
	 from Pharo source, all three over the same buffers. Each output is read back before
	 the next kernel overwrites it, which is what makes the differences between them
	 measurable at all."

	| tiledOutput naiveOutput compiledOutput |
	tiledResult := self
		               time: (PVComputeKernel
				                on: context
				                spirv: PVTiledMatmulKernel new spirv)
		               on: buffers.
	tiledOutput := buffers last elementsAs: self elementType.
	naiveResult := self
		               time: (PVComputeKernel
				                fromMethod: (PVKernelExamples matmulFor: self elementType)
				                on: context)
		               on: buffers.
	naiveOutput := buffers last elementsAs: self elementType.
	compiledResult := self
		                  time: (PVComputeKernel
				                   fromMethod: self class compiledKernelMethod
				                   on: context)
		                  on: buffers.
	compiledOutput := buffers last elementsAs: self elementType.
	maximumDifference := self worstDifferenceBetween: tiledOutput and: naiveOutput.
	maximumCompiledDifference := self
		                             worstDifferenceBetween: compiledOutput
		                             and: tiledOutput.
	^ self
]

{ #category : 'initialization' }
PVTiledMatmulComparison >> setContext: aContext order: n repeats: count [
	context := aContext.
	order := n.
	repeats := count
]

{ #category : 'reporting' }
PVTiledMatmulComparison >> speedup [
	"How many times faster the tiled kernel is. A dispatch too quick for the host clock
	 leaves no ratio to report, which is answered as nil rather than as a division."

	(tiledResult isNil or: [ naiveResult isNil ]) ifTrue: [ ^ nil ].
	tiledResult milliseconds = 0 ifTrue: [ ^ nil ].
	^ naiveResult milliseconds / tiledResult milliseconds
]

{ #category : 'accessing' }
PVTiledMatmulComparison >> tiledResult [
	^ tiledResult
]

{ #category : 'private' }
PVTiledMatmulComparison >> time: aKernel on: buffers [
	"The first dispatch is thrown away: it carries pipeline warm-up and the first touch of
	 the buffers. dispatch:y:z: waits on the queue, so the host clock around the repeats
	 measures whole dispatches and nothing finer."

	| groups total |
	groups := self groupCount.
	^ [
	  buffers do: [ :each | aKernel bindBuffer: each ].
	  aKernel prepare.
	  aKernel dispatch: groups y: groups z: 1.
	  total := Time millisecondsToRun: [
		           repeats timesRepeat: [ aKernel dispatch: groups y: groups z: 1 ] ].
	  PVBenchmarkResult
		  order: order
		  milliseconds: (total / repeats) asFloat
		  repeats: repeats ] ensure: [ aKernel destroy ]
]

{ #category : 'private' }
PVTiledMatmulComparison >> worstDifferenceBetween: someElements and: otherElements [
	"The largest single disagreement between two readings of the output buffer. A mean
	 would hide one wrong element among thousands of right ones."

	^ (1 to: someElements size) inject: 0.0 into: [ :worst :i |
		  worst max: ((someElements at: i) - (otherElements at: i)) abs ]
]
