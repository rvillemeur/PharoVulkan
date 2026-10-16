"
Examples that measure rather than demonstrate: matmul benchmarks at order 64 in single and half precision, the tiled half benchmark at order 256, the precision comparisons at order 256 and tiled at order 512, and the tiled against untiled comparison at order 256.

Each of these dispatches real work and times it, so a click takes seconds rather than milliseconds and the numbers it answers belong to the machine it ran on. They are the examples to open when a change is meant to make something faster.
"
Class {
	#name : 'PVBenchmarkExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Compute',
	#package : 'PharoVulkan-Examples',
	#tag : 'Compute'
}

{ #category : 'examples' }
PVBenchmarkExamples class >> benchmarkOnOrder64Matmul [
	"One click: the baseline matmul timed at a size small enough to be cheap. The
	 Benchmark tab holds the numbers; a 64 by 64 dispatch may well be quicker than the
	 host clock, which the table reports as such rather than inventing a rate."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ (PVBenchmark on: context order: 64 repeats: 10)
		    run;
		    yourself ] ensure: [ context destroy ]

]

{ #category : 'examples' }
PVBenchmarkExamples class >> halfBenchmarkOnOrder64Matmul [
	"One click: the half precision matmul timed on its own, so the Benchmark tab names f16 in
	 its first row. PVPrecisionComparison is the one to open for a ratio against float."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ (PVBenchmark on: context order: 64 repeats: 10 elementType: #f16)
		    run;
		    yourself ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVBenchmarkExamples class >> precisionComparisonOnOrder256Matmul [
	"One click: the same matmul timed in every precision the compiler can emit. The Precision
	 tab holds the two times and the ratio between them. Order 256 is large enough for the
	 host clock to see and small enough to finish while you watch."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ PVPrecisionComparison on: context order: 256 repeats: 10 ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVBenchmarkExamples class >> tiledHalfBenchmarkOnOrder256Matmul [
	"One click: the tiled half precision kernel timed on its own, so the Benchmark tab names
	 both the precision and the kernel that produced the rate under it. PVPrecisionComparison
	 on the tiled family is the one to open for a ratio against float."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  (PVBenchmark
		   on: context
		   order: 256
		   repeats: 10
		   kernel: (PVKernelExamples tiledMatmulFor: #f16))
		  run;
		  yourself ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVBenchmarkExamples class >> tiledMatmulComparisonAtOrder256 [
	"One click: the three matmul kernels timed against each other at an order big enough to
	 show the difference and small enough to be quick. The Comparison tab holds the
	 numbers, and the last two rows say the three kernels agree."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ (PVTiledMatmulComparison on: context order: 256 repeats: 10) run ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
PVBenchmarkExamples class >> tiledPrecisionComparisonOnOrder512Matmul [
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
	  PVPrecisionComparison
		  on: context
		  order: 512
		  repeats: 10
		  family: PVKernelExamples tiledMatmulFamily ] ensure: [ context destroy ]
]
