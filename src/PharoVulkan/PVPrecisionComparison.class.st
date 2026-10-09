Class {
	#name : 'PVPrecisionComparison',
	#superclass : 'Object',
	#instVars : [
		'order',
		'repeats',
		'benchmarks'
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

{ #category : 'instance creation' }
PVPrecisionComparison class >> on: aContext order: n repeats: count [
	"Runs one benchmark per element type straight away: a comparison of times measured
	 minutes apart on a shared device is not a comparison."

	| benchmarks |
	benchmarks := Dictionary new.
	PVBenchmark elementTypes do: [ :each |
		| benchmark |
		benchmark := PVBenchmark
			             on: aContext
			             order: n
			             repeats: count
			             elementType: each.
		benchmark run.
		benchmarks at: each put: benchmark ].
	^ self new setOrder: n repeats: count benchmarks: benchmarks
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

{ #category : 'inspector' }
PVPrecisionComparison >> inspectorPrecision: aBuilder [
	"Time, rate and ratio for each precision. The speedup column is asked of the comparison
	 rather than written into the table, so it cannot drift from the times beside it."

	<inspectorPresentationOrder: 10 title: 'Precision'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Element type' evaluated: [ :each |
					   each at: #name ]);
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
			  (#milliseconds -> (self millisecondsFor: anElementTypeSymbol) printString).
			  (#rate -> (benchmark result gigaflopsPerSecond
				    ifNil: [ 'too quick to measure' ]
				    ifNotNil: [ :rate | rate printString ])).
			  (#speedup -> ((self speedupOf: anElementTypeSymbol)
					 ifNil: [ 'too quick to measure' ]
					 ifNotNil: [ :ratio | ratio printString ])) }
]

{ #category : 'initialization' }
PVPrecisionComparison >> setOrder: n repeats: count benchmarks: aDictionary [
	order := n.
	repeats := count.
	benchmarks := aDictionary
]

{ #category : 'reporting' }
PVPrecisionComparison >> speedupOf: anElementTypeSymbol [
	"Read against the baseline precision, so the baseline's own row answers one."

	^ self class
		  speedupOfMilliseconds: (self millisecondsFor: anElementTypeSymbol)
		  against: (self millisecondsFor: PVBenchmark defaultElementType)
]
