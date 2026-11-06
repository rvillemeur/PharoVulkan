"
Runs the subgroup-reduced dot product of PVKernelExamples >> #subgroupDotOf:a:b:out: on a device and holds what came back. Each lane of a subgroup receives the same partial sum, so gpuTotal divides the sum of every slot by the subgroup size the device reports, and cpuTotal computes the same dot product in the image for comparison. Key methods: on:size:, run, gpuTotal, cpuTotal, partialSums. A device that does not report subgroup arithmetic makes run refuse, naming what is missing, rather than dispatch a kernel the driver may reject.
"
Class {
	#name : 'PVSubgroupDotProduct',
	#superclass : 'PVDeviceRun',
	#instVars : [
		'size',
		'partialSums',
		'laneCounts',
		'reportedWidth'
	],
	#category : 'PharoVulkan-Compute-Benchmarks',
	#package : 'PharoVulkan-Compute',
	#tag : 'Benchmarks'
}

{ #category : 'constants' }
PVSubgroupDotProduct class >> factorPeriod [
	"The first input repeats 1.0 up to this many values. Every product is then a small
	 positive whole number, which a float holds exactly, so a difference between the device
	 total and the host total is the reduction and never the rounding."

	^ 8
]

{ #category : 'accessing' }
PVSubgroupDotProduct class >> kernelMethod [
	"The one kernel this class dispatches. Asked here so the workgroup width below and the
	 module that runs come from the same method."

	^ PVKernelExamples >> #subgroupDotOf:a:b:out:lanes:
]

{ #category : 'instance creation' }
PVSubgroupDotProduct class >> on: aContext size: n [
	"The grid has one invocation per element, so a size the workgroup does not divide would
	 leave a tail of slots no lane writes and a total nobody can check."

	n \\ self workgroupWidth = 0 ifFalse: [
		PVTypeError signal: 'Size ' , n printString
			, ' is not a multiple of the kernel workgroup width '
			, self workgroupWidth printString ].
	^ self new setContext: aContext size: n
]

{ #category : 'constants' }
PVSubgroupDotProduct class >> secondFactor [
	"The second input is this value everywhere. A constant factor keeps the products
	 positive, which is what lets a test tell a lane's own product from its subgroup's total."

	^ 2.0
]

{ #category : 'accessing' }
PVSubgroupDotProduct class >> workgroupWidth [
	"Asked of the kernel's own annotation, so the dispatch cannot disagree with the module
	 it dispatches."

	^ (PVTypeAnnotation fromMethod: self kernelMethod) localSize first
]

{ #category : 'querying' }
PVSubgroupDotProduct >> available [
	"Asked of the context, which asks the driver. A kernel sending subgroupSum needs the
	 arithmetic subset of the subgroup operations, not merely a subgroup."

	^ context subgroupArithmeticAvailable
]

{ #category : 'computing' }
PVSubgroupDotProduct >> cpuTotal [
	"The same dot product computed in the image, from the same two inputs the device was
	 given, so the comparison is against this run and not against a remembered number."

	^ (1 to: size) inject: 0.0 into: [ :acc :i | acc + (self productAt: i) ]
]

{ #category : 'computing' }
PVSubgroupDotProduct >> gpuTotal [
	"Each subgroup's total appears once per lane of that subgroup, so the sum of every slot is
	 the dot product multiplied by the subgroup width. Dividing by the width the kernel
	 measured needs no assumption about which lanes share a subgroup, which the specification
	 leaves to the implementation."

	partialSums ifNil: [ PVTypeError signal: 'The reduction has not run yet' ].
	^ (partialSums inject: 0.0 into: [ :acc :each | acc + each ])
	  / self measuredSubgroupSize
]

{ #category : 'accessing' }
PVSubgroupDotProduct >> groupCount [
	"One invocation per element."

	^ size // self class workgroupWidth
]

{ #category : 'inputs' }
PVSubgroupDotProduct >> inputA [
	"Deterministic, positive and small: a repeating run of whole numbers."

	^ (0 to: size - 1) asArray collect: [ :i |
		  (i \\ self class factorPeriod + 1) asFloat ]
]

{ #category : 'inputs' }
PVSubgroupDotProduct >> inputB [
	^ Array new: size withAll: self class secondFactor
]

{ #category : 'inspector' }
PVSubgroupDotProduct >> inspectorReduction: aBuilder [
	"The two widths, the two totals and the difference between them. The table asks the run
	 for every number, including whether it has run at all, so an unrun reduction says so
	 instead of showing stale figures."

	<inspectorPresentationOrder: 10 title: 'Reduction'>
	^ PVFactRow
		  tableOf: self reportRows
		  nameColumn: 'Quantity'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing' }
PVSubgroupDotProduct >> laneCounts [
	"The lane count each invocation's own subgroup had, as the kernel measured it. Nil until
	 run has dispatched."

	^ laneCounts
]

{ #category : 'querying' }
PVSubgroupDotProduct >> measuredSubgroupSize [
	"The width the dispatched shader really ran at, counted by the kernel adding one per lane.
	 This is not reportedSubgroupSize: the device reports the widest subgroup it offers, and
	 the driver is free to compile a shader to a narrower one, which this driver does."

	laneCounts ifNil: [ PVTypeError signal: 'The reduction has not run yet' ].
	^ laneCounts first asInteger
]

{ #category : 'private' }
PVSubgroupDotProduct >> newBuffers [
	"Two inputs, the slot per lane and the lane count the kernel measures. The outputs start
	 at zero rather than at a sentinel, because every slot is written by its own lane and a
	 leftover sentinel would read as a partial sum."

	| a b out lanes |
	a := VkBuffer storageBuffer: size on: context device.
	b := VkBuffer storageBuffer: size on: context device.
	out := VkBuffer storageBuffer: size on: context device.
	lanes := VkBuffer storageBuffer: size on: context device.
	a putF32s: self inputA.
	b putF32s: self inputB.
	out putF32s: (Array new: size withAll: 0.0).
	lanes putF32s: (Array new: size withAll: 0.0).
	^ {
		  a.
		  b.
		  out.
		  lanes }
]

{ #category : 'accessing' }
PVSubgroupDotProduct >> partialSums [
	"One slot per invocation, as the device left them. Nil until run has dispatched."

	^ partialSums
]

{ #category : 'computing' }
PVSubgroupDotProduct >> productAt: anIndex [
	"The product one lane holds, which is what its slot would carry if the reduction had not
	 happened."

	^ (self inputA at: anIndex) * (self inputB at: anIndex)
]

{ #category : 'reporting' }
PVSubgroupDotProduct >> reportRows [
	"One row per fact about the reduction. The two subgroup widths sit beside each other
	 because the difference between them is the whole point: the device reports the widest
	 subgroup it offers, and the shader ran at whatever width the driver chose. Every number
	 is asked of the run rather than restated here, so the table cannot drift from the code."

	partialSums ifNil: [
		^ { (PVFactRow name: 'State' value: 'not run yet') } ].
	^ {
		  (PVFactRow name: 'Elements' value: self size).
		  (PVFactRow
			   name: 'Workgroup width'
			   value: self class workgroupWidth).
		  (PVFactRow name: 'Workgroups dispatched' value: self groupCount).
		  (PVFactRow
			   name: 'Subgroup width reported'
			   value: self reportedSubgroupSize).
		  (PVFactRow
			   name: 'Subgroup width measured'
			   value: self measuredSubgroupSize).
		  (PVFactRow name: 'Dot product on the device' value: self gpuTotal).
		  (PVFactRow name: 'Dot product on the host' value: self cpuTotal).
		  (PVFactRow
			   name: 'Difference'
			   value: (self gpuTotal - self cpuTotal) abs) }
]

{ #category : 'accessing' }
PVSubgroupDotProduct >> reportedSubgroupSize [
	"What VkPhysicalDeviceSubgroupProperties said when the run was built, which is the widest
	 subgroup the device offers rather than the width any given shader runs at."

	^ reportedWidth
]

{ #category : 'running' }
PVSubgroupDotProduct >> run [
	"Guard before the inherited run: with no subgroup arithmetic on the device the dispatch
	 would answer partial sums that mean nothing."

	self available ifFalse: [ PVTypeError signal: self unavailableReason ].
	^ super run
]

{ #category : 'private' }
PVSubgroupDotProduct >> runWithBuffers: buffers [
	| kernel |
	kernel := PVComputeKernel fromMethod: self class kernelMethod on: context.
	buffers do: [ :each | kernel bindBuffer: each ].
	kernel prepare.
	^ [
	  kernel dispatch: self groupCount y: 1 z: 1.
	  partialSums := (buffers at: 3) getF32s.
	  laneCounts := (buffers at: 4) getF32s ] ensure: [ kernel destroy ]
]

{ #category : 'initialization' }
PVSubgroupDotProduct >> setContext: aContext size: n [
	"The reported subgroup width is read once, here, because a run outlives the context an
	 example builds for it: the example destroys the context and then shows the table."

	context := aContext.
	size := n.
	reportedWidth := aContext physicalDevice subgroupSize
]

{ #category : 'accessing' }
PVSubgroupDotProduct >> size [
	^ size
]

{ #category : 'querying' }
PVSubgroupDotProduct >> unavailableReason [
	"What to say instead of a number on a device that cannot run this. Named rather than
	 raised inline so the inspector can show the same sentence a refused run raises."

	^ 'This device does not report subgroup arithmetic, so the reduction cannot run'
]
