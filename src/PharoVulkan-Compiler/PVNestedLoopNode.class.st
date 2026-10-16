"
The one nesting shape PVStructuredCFGRecognizer matches: an outer loop whose body is an inner loop, which is the shape a tiled kernel needs — walk the tiles, and inside each tile walk the elements of the tile.

The outer loop's continue target is innerMergeBlock, the block the inner loop merges into: in the bytecode that block holds the outer loop's increment and jumps back to the outer header, so it is both the inner construct's merge block and the outer construct's latch. PVSPIRVEmitter emits the outer latch as a block of its own, because a block may not be the merge block of one construct and the continue target of another.

Key methods: coveredBlocks, which the recogniser's coverage check reads to refuse a graph holding anything beyond this shape.
"
Class {
	#name : 'PVNestedLoopNode',
	#superclass : 'Object',
	#instVars : [
		'preheaderBlock',
		'headerBlock',
		'innerPreheaderBlock',
		'innerHeaderBlock',
		'innerBodyBlocks',
		'innerMergeBlock',
		'exitBlock'
	],
	#category : 'PharoVulkan-Compiler-Graph',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Graph'
}

{ #category : 'accessing' }
PVNestedLoopNode >> coveredBlocks [
	"Every bytecode block this node accounts for. See PVSelectionNode >> coveredBlocks."

	^ ({
		   preheaderBlock.
		   headerBlock.
		   innerPreheaderBlock.
		   innerHeaderBlock } , innerBodyBlocks , {
		   innerMergeBlock.
		   exitBlock }) reject: [ :each | each isNil ]
]

{ #category : 'accessing' }
PVNestedLoopNode >> exitBlock [
	^ exitBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> exitBlock: aBlock [
	exitBlock := aBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> headerBlock [
	^ headerBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> headerBlock: aBlock [
	headerBlock := aBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerBodyBlocks [
	^ innerBodyBlocks
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerBodyBlocks: aBlock [
	innerBodyBlocks := aBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerHeaderBlock [
	^ innerHeaderBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerHeaderBlock: aBlock [
	innerHeaderBlock := aBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerMergeBlock [
	^ innerMergeBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerMergeBlock: aBlock [
	innerMergeBlock := aBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerPreheaderBlock [
	^ innerPreheaderBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> innerPreheaderBlock: aBlock [
	innerPreheaderBlock := aBlock
]

{ #category : 'inspector' }
PVNestedLoopNode >> inspectorRoles: aBuilder [
	"Which bytecode block fills each role, read off the node's own slots rather than off a
	 list written here, so a role added to the class shows up without this view changing.
	 The successors column is what tells the inner merge apart from the outer latch: it
	 branches back to the outer header."

	<inspectorPresentationOrder: 10 title: 'Roles'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Role' evaluated: [ :each |
					   each at: #role ]);
		  addColumn: (SpStringTableColumn title: 'Block' evaluated: [ :each |
					   each at: #block ]);
		  addColumn: (SpStringTableColumn title: 'Ops' evaluated: [ :each |
					   each at: #ops ]);
		  addColumn: (SpStringTableColumn title: 'Branches to' evaluated: [ :each |
					   each at: #successors ]);
		  items: self roleRows;
		  yourself
]

{ #category : 'accessing' }
PVNestedLoopNode >> preheaderBlock [
	^ preheaderBlock
]

{ #category : 'accessing' }
PVNestedLoopNode >> preheaderBlock: aBlock [
	preheaderBlock := aBlock
]

{ #category : 'inspector' }
PVNestedLoopNode >> roleRowNamed: aRoleName for: aBlockOrNil [
	"A row reads the block, it never moves or renumbers it: the node is shown as the
	 recogniser left it."

	^ Dictionary newFrom: {
			  (#role -> aRoleName).
			  (#block -> (aBlockOrNil
				    ifNil: [ 'none' ]
				    ifNotNil: [ :blk | blk id printString ])).
			  (#ops -> (aBlockOrNil
				    ifNil: [ '' ]
				    ifNotNil: [ :blk | blk ops size printString ])).
			  (#successors -> (aBlockOrNil
				    ifNil: [ '' ]
				    ifNotNil: [ :blk |
					    ', ' join:
							    (blk successors collect: [ :each | each id printString ]) ])) }
]

{ #category : 'inspector' }
PVNestedLoopNode >> roleRows [
	"One row per slot of this class, in slot order. A slot holding a collection of blocks
	 contributes one row per block, so innerBodyBlocks does not print as a collection."

	| rows |
	rows := OrderedCollection new.
	self class slotNames do: [ :slotName |
		| value |
		value := self instVarNamed: slotName.
		(value isCollection and: [ value isString not ])
			ifTrue: [
				value doWithIndex: [ :each :i |
					rows add: (self
							 roleRowNamed: slotName , ' ' , i printString
							 for: each) ] ]
			ifFalse: [ rows add: (self roleRowNamed: slotName for: value) ] ].
	^ rows
]
