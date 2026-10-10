Class {
	#name : 'PVWorkItem',
	#superclass : 'Object',
	#instVars : [
		'x',
		'y',
		'z',
		'gridWidth',
		'localX',
		'localY',
		'localZ'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'examples' }
PVWorkItem class >> exampleWorkItemInA512Grid [
	<sampleInstance>
	^ self x: 3 y: 7 z: 0 gridWidth: 512
]

{ #category : 'examples' }
PVWorkItem class >> exampleWorkItemInsideItsWorkgroup [
	"An invocation whose position in the dispatch and position in its workgroup differ: slot
	 5 of a workgroup 16 wide, which is global invocation 21. Inspect it and read the
	 Dispatch tab to see the two indices side by side."

	<sampleInstance>
	^ self
		  x: 21
		  y: 0
		  z: 0
		  localX: 5
		  localY: 0
		  localZ: 0
		  gridWidth: 512
]

{ #category : 'constants' }
PVWorkItem class >> workItemTypeSuffix [
	"The key suffix PVSelectorTable gives every mapping whose receiver is a WorkItem."

	^ ':workItem'
]

{ #category : 'instance creation' }
PVWorkItem class >> x: anX y: aY z: aZ gridWidth: aWidth [
	^ self new setX: anX y: aY z: aZ gridWidth: aWidth

]

{ #category : 'instance creation' }
PVWorkItem class >> x: anX y: aY z: aZ localX: aLocalX localY: aLocalY localZ: aLocalZ gridWidth: aWidth [
	"The full set of coordinates a kernel can ask for: where the invocation sits in the
	 dispatch, where it sits inside its own workgroup, and how wide the grid is."

	^ self new
		  setX: anX y: aY z: aZ gridWidth: aWidth;
		  setLocalX: aLocalX localY: aLocalY localZ: aLocalZ;
		  yourself
]

{ #category : 'synchronising' }
PVWorkItem >> barrier [
	"On the GPU this is OpControlBarrier: every invocation of the workgroup waits here and
	 the writes to shared memory made before it become visible to all of them. On the host
	 there is one invocation and no shared memory, so there is nothing to wait for and
	 nothing to publish, which is why answering the receiver is the honest answer rather
	 than a missing method."

	^ self
]

{ #category : 'reporting' }
PVWorkItem >> dispatchReport [
	"One row per selector the compiler maps for a WorkItem, with what this item answers
	 for it. A mapping added to the table without a method here shows up as a missing
	 answer rather than silently working on the GPU only."

	^ self kernelSelectors collect: [ :selector |
		  Dictionary new
			  at: #selector put: selector;
			  at: #value put: (self valueForSelector: selector);
			  yourself ]
]

{ #category : 'accessing' }
PVWorkItem >> gridWidth [
	"Width of the dispatch grid in invocations: groupCountX times localSizeX. A kernel that
	 must know the problem size reads it from here, since the ABI passes no scalars."

	^ gridWidth
]

{ #category : 'inspector' }
PVWorkItem >> inspectorDispatch: aBuilder [
	"The kernel's own vocabulary, read off the selector table rather than listed here, so a
	 selector the compiler gains without a host-side method is visible at a glance."

	<inspectorPresentationOrder: 10 title: 'Dispatch'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Selector' evaluated: [ :each |
					   each at: #selector ]);
		  addColumn:
			  (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each at: #value ]);
		  items: self dispatchReport;
		  yourself
]

{ #category : 'accessing' }
PVWorkItem >> kernelSelectors [
	"The selectors a compute kernel may send to its WorkItem, asked of the table that maps
	 them to SPIR-V, so this answer cannot drift from the compiler."

	| suffix |
	suffix := self class workItemTypeSuffix.
	^ (PVSelectorTable standard table keys
		   select: [ :each | each endsWith: suffix ]
		   thenCollect: [ :each |
		   (each copyFrom: 1 to: each size - suffix size) asSymbol ])
		  asSortedCollection asArray
]

{ #category : 'accessing' }
PVWorkItem >> localX [
	"Position inside the workgroup along x. Unlike x, which counts across the whole dispatch,
	 this is the index a kernel uses to address a slot of shared memory."

	^ localX
]

{ #category : 'accessing' }
PVWorkItem >> localY [
	^ localY
]

{ #category : 'accessing' }
PVWorkItem >> localZ [
	^ localZ
]

{ #category : 'printing' }
PVWorkItem >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPut: $(;
		print: x;
		nextPutAll: ', ';
		print: y;
		nextPutAll: ', ';
		print: z;
		nextPutAll: ' of ';
		print: gridWidth;
		nextPut: $)
]

{ #category : 'initialization' }
PVWorkItem >> setLocalX: aLocalX localY: aLocalY localZ: aLocalZ [
	localX := aLocalX.
	localY := aLocalY.
	localZ := aLocalZ
]

{ #category : 'initialization' }
PVWorkItem >> setX: anX y: aY z: aZ gridWidth: aWidth [
	"A work item built without workgroup coordinates stands for one of a single workgroup,
	 where the position in the dispatch and the position in the workgroup coincide."

	x := anX.
	y := aY.
	z := aZ.
	gridWidth := aWidth.
	self setLocalX: anX localY: aY localZ: aZ
]

{ #category : 'reporting' }
PVWorkItem >> valueForSelector: aSelector [
	"Keyword mappings carry operands the host side cannot invent, and a selector the table
	 maps but nobody implements must read as missing, not raise."

	aSelector numArgs > 0 ifTrue: [ ^ 'takes arguments' ].
	(self class canUnderstand: aSelector) ifFalse: [ ^ 'not implemented' ].
	^ (self perform: aSelector) printString
]

{ #category : 'accessing' }
PVWorkItem >> x [
	^ x
]

{ #category : 'accessing' }
PVWorkItem >> y [
	^ y
]

{ #category : 'accessing' }
PVWorkItem >> z [
	^ z
]
