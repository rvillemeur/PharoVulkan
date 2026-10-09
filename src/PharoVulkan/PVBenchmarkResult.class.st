Class {
	#name : 'PVBenchmarkResult',
	#superclass : 'Object',
	#instVars : [
		'order',
		'milliseconds',
		'repeats'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
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
