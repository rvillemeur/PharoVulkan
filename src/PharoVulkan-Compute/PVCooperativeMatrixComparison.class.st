"
One 8 by 8 cooperative matrix product, run twice on the same context: once from the module PVCooperativeMatrixKernel builds instruction by instruction, and once from the module the DSL compiles out of PVKernelExamples >> #coopMatrixProductOf:by:into:. It answers both results, the CPU reference for the same inputs, and how long each dispatch took.

The timings exist only to show that the kernel runs. The one device here that offers VK_KHR_cooperative_matrix is lavapipe, a CPU implementation, so no number from it can carry a speedup claim; 7-G's tiled matmul is where this project's performance claims come from.

Send `on:` with a context whose device offers the extension, then `run`. `referenceResult`, `handBuiltResult` and `compiledResult` are flat row-major arrays of 64 floats. The two device results agree exactly where the emitter wrote the same instructions, so a difference between them is an emitter bug rather than rounding.
"
Class {
	#name : 'PVCooperativeMatrixComparison',
	#superclass : 'Object',
	#instVars : [
		'context',
		'handBuiltResult',
		'compiledResult',
		'referenceResult',
		'handBuiltMilliseconds',
		'compiledMilliseconds'
	],
	#category : 'PharoVulkan-Compute-CooperativeMatrix',
	#package : 'PharoVulkan-Compute',
	#tag : 'CooperativeMatrix'
}

{ #category : 'constants' }
PVCooperativeMatrixComparison class >> compiledKernelSelector [
	"The DSL kernel the comparison compiles. Named here so the inspector view and the
	 dispatch cannot name two different methods."

	^ #coopMatrixProductOf:by:into:
]

{ #category : 'constants' }
PVCooperativeMatrixComparison class >> leftAtRow: aRow col: aColumn [
	"Deliberately asymmetric, so a row and column swap inside the kernel cannot pass
	 unnoticed, and small enough that half precision carries it."

	^ ((aRow + (2 * aColumn)) \\ 7) / 7.0
]

{ #category : 'instance creation' }
PVCooperativeMatrixComparison class >> on: aVkContext [
	"The context must already have the extension and its features enabled, which
	 VkContext class >> cooperativeMatrixContext does."

	^ self new setContext: aVkContext; yourself
]

{ #category : 'constants' }
PVCooperativeMatrixComparison class >> order [
	"The one M, N, K combination the device reports, held once by the hand-built kernel."

	^ PVCooperativeMatrixKernel matrixOrder
]

{ #category : 'constants' }
PVCooperativeMatrixComparison class >> rightAtRow: aRow col: aColumn [
	^ ((3 * aRow + aColumn) \\ 5) / 5.0
]

{ #category : 'accessing' }
PVCooperativeMatrixComparison >> compiledMilliseconds [
	^ compiledMilliseconds
]

{ #category : 'accessing' }
PVCooperativeMatrixComparison >> compiledResult [
	^ compiledResult
]

{ #category : 'private' }
PVCooperativeMatrixComparison >> compiledSpirv [
	"The module the DSL compiles out of the Pharo source of the kernel. Compiled on every
	 run rather than cached, so the comparison cannot report a module older than the
	 emitter it is testing."

	^ PVKernelCompiler new
		  method: PVKernelExamples >> self class compiledKernelSelector;
		  compile
]

{ #category : 'private' }
PVCooperativeMatrixComparison >> cpuReference [
	"The product in float on the CPU, from the same inputs. It is the fact both device
	 results are measured against, since half precision inputs cannot carry it exactly."

	| order |
	order := self class order.
	^ self flatMatrixWith: [ :row :column |
		  (0 to: order - 1) inject: 0.0 into: [ :accumulated :k |
			  accumulated + ((self class leftAtRow: row col: k)
				   * (self class rightAtRow: k col: column)) ] ]
]

{ #category : 'private' }
PVCooperativeMatrixComparison >> flatMatrixWith: aBlock [
	"Row-major flattening, the layout both modules read with the row-major cooperative
	 matrix layout and a stride of one order."

	| order matrix |
	order := self class order.
	matrix := Array new: order * order.
	0 to: order - 1 do: [ :row |
		0 to: order - 1 do: [ :column |
			matrix
				at: row * order + column + 1
				put: (aBlock value: row value: column) ] ].
	^ matrix
]

{ #category : 'accessing' }
PVCooperativeMatrixComparison >> handBuiltMilliseconds [
	^ handBuiltMilliseconds
]

{ #category : 'accessing' }
PVCooperativeMatrixComparison >> handBuiltResult [
	^ handBuiltResult
]

{ #category : 'inspector' }
PVCooperativeMatrixComparison >> inspectorComparison: aBuilder [
	"Both timings beside both distances from the CPU reference. The timings alone would
	 invite a speedup reading the device cannot support, so the agreement rows sit in the
	 same table."

	<inspectorPresentationOrder: 10 title: 'Comparison'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Quantity'
				   evaluated: [ :each | each at: #name ]);
		  addColumn: (SpStringTableColumn
				   title: 'Value'
				   evaluated: [ :each | each at: #value ]);
		  items: self reportRows;
		  yourself
]

{ #category : 'reporting' }
PVCooperativeMatrixComparison >> largestDifferenceBetween: aResult and: anotherResult [
	"The worst element-by-element distance between two flat results, which is the only
	 honest summary: an average hides the one element a wrong layout moved."

	^ (aResult with: anotherResult collect: [ :left :right |
		   (left - right) abs ]) inject: 0.0 into: [ :worst :each |
		  worst max: each ]
]

{ #category : 'private' }
PVCooperativeMatrixComparison >> leftMatrix [
	^ self flatMatrixWith: [ :row :column |
		  self class leftAtRow: row col: column ]
]

{ #category : 'accessing' }
PVCooperativeMatrixComparison >> referenceResult [
	^ referenceResult
]

{ #category : 'reporting' }
PVCooperativeMatrixComparison >> reportRows [
	"One row per fact about the two runs. Every number is asked of a result rather than
	 restated, so the table cannot disagree with what ran. No speedup row: the device that
	 offers the extension here runs on the CPU, and a ratio from it would mean nothing."

	handBuiltResult ifNil: [
		^ { (self rowNamed: 'State' value: 'not run yet') } ].
	^ {
		  (self rowNamed: 'Matrix order' value: self class order printString).
		  (self
			   rowNamed: 'Compiled from'
			   value: self class compiledKernelSelector asString).
		  (self
			   rowNamed: 'Hand-built milliseconds'
			   value: handBuiltMilliseconds printString).
		  (self
			   rowNamed: 'Compiled milliseconds'
			   value: compiledMilliseconds printString).
		  (self
			   rowNamed: 'Largest difference, hand-built against the CPU'
			   value: (self
					    largestDifferenceBetween: handBuiltResult
					    and: referenceResult) printString).
		  (self
			   rowNamed: 'Largest difference, compiled against the CPU'
			   value: (self
					    largestDifferenceBetween: compiledResult
					    and: referenceResult) printString).
		  (self
			   rowNamed: 'Largest difference, compiled against hand-built'
			   value: (self
					    largestDifferenceBetween: compiledResult
					    and: handBuiltResult) printString) }
]

{ #category : 'private' }
PVCooperativeMatrixComparison >> rightMatrix [
	^ self flatMatrixWith: [ :row :column |
		  self class rightAtRow: row col: column ]
]

{ #category : 'reporting' }
PVCooperativeMatrixComparison >> rowNamed: aName value: aValue [
	^ Dictionary new
		  at: #name put: aName;
		  at: #value put: aValue;
		  yourself
]

{ #category : 'measuring' }
PVCooperativeMatrixComparison >> run [
	"Fill in the CPU reference and both device results, answering self. Each dispatch is
	 timed once, which is enough for the only claim made about the timing: that the kernel
	 runs. The buffers live and die inside each dispatch."

	| left right kernel |
	left := self leftMatrix.
	right := self rightMatrix.
	kernel := PVCooperativeMatrixKernel new.
	referenceResult := self cpuReference.
	handBuiltMilliseconds := [
	                         handBuiltResult := kernel
		                                            productOf: left
		                                            by: right
		                                            on: context ] timeToRun
		                        asMilliSeconds.
	compiledMilliseconds := [
	                        compiledResult := kernel
		                                          productOf: left
		                                          by: right
		                                          on: context
		                                          spirv: self compiledSpirv ] timeToRun
		                       asMilliSeconds.
	^ self
]

{ #category : 'initialization' }
PVCooperativeMatrixComparison >> setContext: aVkContext [
	context := aVkContext
]
