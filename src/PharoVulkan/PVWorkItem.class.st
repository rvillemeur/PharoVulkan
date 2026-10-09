Class {
	#name : 'PVWorkItem',
	#superclass : 'Object',
	#instVars : [
		'x',
		'y',
		'z',
		'gridWidth'
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

{ #category : 'constants' }
PVWorkItem class >> workItemTypeSuffix [
	"The key suffix PVSelectorTable gives every mapping whose receiver is a WorkItem."

	^ ':workItem'
]

{ #category : 'instance creation' }
PVWorkItem class >> x: anX y: aY z: aZ gridWidth: aWidth [
	^ self new setX: anX y: aY z: aZ gridWidth: aWidth

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
PVWorkItem >> setX: anX y: aY z: aZ gridWidth: aWidth [
	x := anX.
	y := aY.
	z := aZ.
	gridWidth := aWidth
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
