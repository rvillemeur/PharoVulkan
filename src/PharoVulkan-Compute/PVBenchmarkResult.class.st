"
One timed matmul run: the matrix order, the milliseconds it took and how many repeats that time covers.

The rate is derived rather than stored. floatingPointOperations counts two operations per element of each dot product, which is what a square matmul does, and gigaflopsPerSecond divides that by the measured time — answering nil when the dispatch was quicker than the host clock can measure, because the rate is then unknown rather than zero or infinite. Every benchmark and comparison in this package reports through one of these, so a reader comparing two runs compares the same arithmetic.

Build one with the class-side order:milliseconds:repeats:.
"
Class {
	#name : 'PVBenchmarkResult',
	#superclass : 'Object',
	#instVars : [
		'order',
		'milliseconds',
		'repeats'
	],
	#category : 'PharoVulkan-Compute-Benchmarks',
	#package : 'PharoVulkan-Compute',
	#tag : 'Benchmarks'
}

{ #category : 'constants' }
PVBenchmarkResult class >> flopsPerGigaflop [

	^ 1e9

]

{ #category : 'constants' }
PVBenchmarkResult class >> flopsPerMultiplyAdd [
	"A multiply-add counts as two floating point operations, the convention every
	 published GFLOP/s figure for matmul uses."

	^ 2

]

{ #category : 'constants' }
PVBenchmarkResult class >> millisecondsPerSecond [

	^ 1000.0

]

{ #category : 'instance creation' }
PVBenchmarkResult class >> order: n milliseconds: ms repeats: count [
	^ self new setOrder: n milliseconds: ms repeats: count

]

{ #category : 'deriving' }
PVBenchmarkResult >> floatingPointOperations [
	"A square matmul does one multiply and one add per element of each dot product."

	^ self class flopsPerMultiplyAdd * (order * order * order)
]

{ #category : 'deriving' }
PVBenchmarkResult >> gigaflopsPerSecond [
	"Answer nil rather than a number when the dispatch was quicker than the host clock can
	 measure: the rate is unknown, not zero and not infinite."

	milliseconds isZero ifTrue: [ ^ nil ].
	^ self floatingPointOperations
	  / (milliseconds / self class millisecondsPerSecond)
	  / self class flopsPerGigaflop
]

{ #category : 'accessing' }
PVBenchmarkResult >> milliseconds [
	^ milliseconds
]

{ #category : 'accessing' }
PVBenchmarkResult >> order [
	^ order
]

{ #category : 'printing' }
PVBenchmarkResult >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: '(N=';
		print: order;
		nextPutAll: ', ';
		print: milliseconds;
		nextPutAll: ' ms'.
	self gigaflopsPerSecond ifNotNil: [ :rate |
		aStream
			nextPutAll: ', ';
			print: rate rounded;
			nextPutAll: ' GFLOP/s' ].
	aStream nextPut: $)
]

{ #category : 'accessing' }
PVBenchmarkResult >> repeats [
	^ repeats
]

{ #category : 'initialization' }
PVBenchmarkResult >> setOrder: n milliseconds: ms repeats: count [
	order := n.
	milliseconds := ms.
	repeats := count
]
