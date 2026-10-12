"
Times one matmul kernel per precision at the same matrix order, on the same device, in the one run, and reads each time against the float baseline. Build it with on:order:repeats: for the naive kernels or on:order:repeats:family: to compare precisions on another family, such as the tiled kernels, then read reportRows or the Precision tab. The family is fixed for the whole comparison, because a ratio between two precisions measured on two different kernels says nothing about either; each row names the kernel it was measured on. PVBenchmark holds one measurement.
"
Class {
	#name : 'PVPrecisionComparison',
	#superclass : 'Object',
	#instVars : [
		'order',
		'repeats',
		'benchmarks',
		'family'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'examples' }
PVPrecisionComparison class >> examplePrecisionComparisonOnOrder256Matmul [
	"One click: the same matmul timed in every precision the compiler can emit. The Precision
	 tab holds the two times and the ratio between them. Order 256 is large enough for the
	 host clock to see and small enough to finish while you watch."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ self on: context order: 256 repeats: 10 ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVPrecisionComparison class >> exampleTiledPrecisionComparisonOnOrder512Matmul [
	"One click: the tiled matmul timed in every precision the compiler can emit, which is the
	 comparison half precision is worth making. The naive kernel is bound by global memory
	 traffic, so the ratio measured there sits near one whatever the storage format; the tiled
	 kernel reads each tile sixteen times out of shared memory, so a narrower tile reaches the
	 time. Order 512 with ten dispatches is the configuration Phase 7-G measured the float
	 kernel at, so the Precision tab reads against a number already recorded."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  self
		  on: context
		  order: 512
		  repeats: 10
		  family: PVKernelExamples tiledMatmulFamily ] ensure: [ context destroy ]
]

{ #category : 'instance creation' }
PVPrecisionComparison class >> on: aContext order: n repeats: count [
	^ self
		  on: aContext
		  order: n
		  repeats: count
		  family: PVKernelExamples defaultMatmulFamily
]

{ #category : 'instance creation' }
PVPrecisionComparison class >> on: aContext order: n repeats: count family: aFamilySymbol [
	"Runs one benchmark per element type straight away: a comparison of times measured
	 minutes apart on a shared device is not a comparison. The family is fixed for the whole
	 comparison, because a ratio between two precisions measured on two different kernels
	 says nothing about either. An unknown family raises here, before anything is dispatched."

	| benchmarks |
	benchmarks := Dictionary new.
	PVBenchmark elementTypes do: [ :each |
		| benchmark |
		benchmark := PVBenchmark
			             on: aContext
			             order: n
			             repeats: count
			             kernel:
			             (PVKernelExamples matmulFor: each family: aFamilySymbol).
		benchmark run.
		benchmarks at: each put: benchmark ].
	^ self new
		  setOrder: n
		  repeats: count
		  benchmarks: benchmarks
		  family: aFamilySymbol
]

{ #category : 'computing' }
PVPrecisionComparison class >> speedupOfMilliseconds: aTime against: aBaselineTime [
	"How many times quicker than the baseline. Answers nil rather than a number when either
	 dispatch measured zero, because one direction divides by zero and the other invents a
	 ratio out of a clock tick."

	(aTime = 0 or: [ aBaselineTime = 0 ]) ifTrue: [ ^ nil ].
	^ (aBaselineTime / aTime) asFloat
]

{ #category : 'accessing' }
PVPrecisionComparison >> benchmarkFor: anElementTypeSymbol [
	^ benchmarks at: anElementTypeSymbol ifAbsent: [
		  PVTypeError signal: 'Nothing was measured for ' , anElementTypeSymbol ]
]

{ #category : 'accessing' }
PVPrecisionComparison >> family [
	^ family
]

{ #category : 'inspector' }
PVPrecisionComparison >> inspectorPrecision: aBuilder [
	"Time, rate and ratio for each precision, beside the kernel each one was measured on.
	 The kernel column is read off the benchmark that produced the row and the speedup column
	 is asked of the comparison, so neither can drift from the times beside them."

	<inspectorPresentationOrder: 10 title: 'Precision'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Element type' evaluated: [ :each |
					   each at: #name ]);
		  addColumn: (SpStringTableColumn title: 'Kernel' evaluated: [ :each |
					   each at: #kernel ]);
		  addColumn: (SpStringTableColumn title: 'Milliseconds' evaluated: [ :each |
					   each at: #milliseconds ]);
		  addColumn: (SpStringTableColumn title: 'GFLOP/s' evaluated: [ :each |
					   each at: #rate ]);
		  addColumn: (SpStringTableColumn title: 'Speedup' evaluated: [ :each |
					   each at: #speedup ]);
		  items: self reportRows;
		  yourself
]

{ #category : 'reporting' }
PVPrecisionComparison >> millisecondsFor: anElementTypeSymbol [
	^ (self benchmarkFor: anElementTypeSymbol) result milliseconds
]

{ #category : 'accessing' }
PVPrecisionComparison >> order [
	^ order
]

{ #category : 'accessing' }
PVPrecisionComparison >> repeats [
	^ repeats
]

{ #category : 'reporting' }
PVPrecisionComparison >> reportRows [
	"One row per precision, in the order PVBenchmark lists them, so the table reads the same
	 way every run."

	^ PVBenchmark elementTypes collect: [ :each | self rowFor: each ]
]

{ #category : 'reporting' }
PVPrecisionComparison >> rowFor: anElementTypeSymbol [
	| benchmark |
	benchmark := self benchmarkFor: anElementTypeSymbol.
	^ Dictionary newFrom: {
			  (#name -> anElementTypeSymbol asString).
			  (#kernel -> benchmark kernelMethod selector asString).
			  (#milliseconds
			   -> (self millisecondsFor: anElementTypeSymbol) printString).
			  (#rate -> (benchmark result gigaflopsPerSecond
				    ifNil: [ 'too quick to measure' ]
				    ifNotNil: [ :rate | rate printString ])).
			  (#speedup -> ((self speedupOf: anElementTypeSymbol)
					 ifNil: [ 'too quick to measure' ]
					 ifNotNil: [ :ratio | ratio printString ])) }
]

{ #category : 'initialization' }
PVPrecisionComparison >> setOrder: n repeats: count benchmarks: aDictionary family: aFamilySymbol [
	order := n.
	repeats := count.
	benchmarks := aDictionary.
	family := aFamilySymbol
]

{ #category : 'reporting' }
PVPrecisionComparison >> speedupOf: anElementTypeSymbol [
	"Read against the baseline precision, so the baseline's own row answers one."

	^ self class
		  speedupOfMilliseconds: (self millisecondsFor: anElementTypeSymbol)
		  against: (self millisecondsFor: PVBenchmark defaultElementType)
]
