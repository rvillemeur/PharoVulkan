"
Recognizes structured control-flow patterns (ifTrue:ifFalse:, whileTrue:) in the CFG and wraps them in PVSelectionNode or PVLoopNode. Signals an error on unrecognised shapes. Stage 7 of the pipeline.
"
Class {
	#name : 'PVStructuredCFGRecognizer',
	#superclass : 'Object',
	#instVars : [
		'blocks',
		'blockMap'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan',
	#tag : 'Compiler-Pipeline'
}

{ #category : 'examples' }
PVStructuredCFGRecognizer class >> exampleRecogniserOnLoopKernel [
	"A recogniser loaded with the control-flow graph of a kernel that holds one loop,
	 the shape PVLoopNode represents. Inspect it and open the Recognition tab to see
	 which blocks the answered node accounts for."

	<sampleInstance>
	| bytecodes |
	bytecodes := PVBytecodeDecoder decode: (PVKernelExamples >> #accumulateUpTo:).
	^ self new initialize: (PVCFGBuilder buildBytecodeBlocks: bytecodes)
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer class >> recognizeFrom: aBlockArray [
	^ self new initialize: aBlockArray; recognize
]

{ #category : 'accessing' }
PVStructuredCFGRecognizer >> blockMap [
^ blockMap
]

{ #category : 'accessing' }
PVStructuredCFGRecognizer >> blocks [
^ blocks
]

{ #category : 'accessing' }
PVStructuredCFGRecognizer >> blocks: c [
	blocks := c
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer >> covers: aNode [
	"Answer whether aNode accounts for every block in the graph. The pattern
	 recognisers match on the head of the block list and describe one construct with one
	 block per arm, so a graph holding a second construct — two selections in sequence,
	 or a loop followed by a selection — still matches at the head. Without this check
	 the tail was dropped silently: two sequential selections compiled to a module
	 byte-identical to the first selection alone, and a loop followed by a selection
	 emitted OpReturnValue with the loop condition, a bool, from a function declared to
	 return an int. Refusing here turns both into the Unrecognized CFG shape error that
	 nested shapes already raise."

	| covered |
	covered := IdentitySet newFrom: aNode coveredBlocks.
	^ blocks allSatisfy: [ :each | covered includes: each ]
]

{ #category : 'initialize-release' }
PVStructuredCFGRecognizer >> initialize: aBlockArray [
	blocks := aBlockArray.
	blockMap := Dictionary new.
	blocks do: [ :b | blockMap at: b id put: b ]
]

{ #category : 'inspecting' }
PVStructuredCFGRecognizer >> inspectorRecognition: aBuilder [
	"Show which blocks the recognised node covers. A graph the recogniser refuses shows
	 every row as false, which is what distinguishes a refusal from a partial match: a
	 partial match is exactly what used to be accepted, dropping the uncovered blocks."

	<inspectorPresentationOrder: 30 title: 'Recognition'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Block'
				   evaluated: [ :each | each key id printString ]);
		  addColumn: (SpStringTableColumn
				   title: 'Terminator'
				   evaluated: [ :each |
					   each key terminator
						   ifNil: [ '' ]
						   ifNotNil: [ :term | term opcode printString ] ]);
		  addColumn: (SpStringTableColumn
				   title: 'Covered'
				   evaluated: [ :each | each value printString ]);
		  items: self recognitionReport;
		  yourself
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer >> isTwoWayHeader: aBlock [
	"A loop header in the nested shape tests a condition, so it has a body and an exit and
	 nothing else."

	| term |
	term := aBlock terminator.
	^ (term notNil and: [ term opcode = #jumpIf ]) and: [
		  aBlock successors size = 2 ]
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer >> nestedLoopNodeAt: headerBlk preheader: preBlk innerPreheader: outerBody innerHeader: innerHeader [
	"The two back edges the shape needs: the inner body closes the inner loop, and the block
	 the inner loop merges into carries the outer increment and jumps back to the outer
	 header, which makes it the outer latch as well. Answer nil if either edge is missing."

	| innerBody innerMerge |
	innerBody := innerHeader successors first.
	innerMerge := innerHeader successors last.
	(innerBody successors includes: innerHeader) ifFalse: [ ^ nil ].
	(innerMerge successors includes: headerBlk) ifFalse: [ ^ nil ].
	^ PVNestedLoopNode new
		  preheaderBlock: preBlk;
		  headerBlock: headerBlk;
		  innerPreheaderBlock: outerBody;
		  innerHeaderBlock: innerHeader;
		  innerBodyBlocks: { innerBody };
		  innerMergeBlock: innerMerge;
		  exitBlock: headerBlk successors last;
		  yourself
]

{ #category : 'inspecting' }
PVStructuredCFGRecognizer >> recognitionReport [
	"One row per block, paired with whether the node this recogniser answers accounts
	 for that block. Calls recognize and reads the node own coveredBlocks instead of
	 restating either rule, so the report cannot drift from the recogniser. Both only
	 read the blocks, so asking does not change anything."

	| node covered |
	node := self recognize.
	covered := node
		           ifNil: [ IdentitySet new ]
		           ifNotNil: [ IdentitySet newFrom: node coveredBlocks ].
	^ blocks collect: [ :each | each -> (covered includes: each) ]
]

{ #category : 'recognition' }
PVStructuredCFGRecognizer >> recognize [
	"Try the patterns in order of how much of the graph they claim. The nested loop is
	 tried before the single loop, because a single-loop match on an outer header would
	 take the inner loop's preheader for the whole body and then be refused by the coverage
	 check, losing a shape that is in fact representable."

	| node |
	blocks size >= 2 ifFalse: [ ^ nil ].
	node := self recognizeSelectionAt: blocks first.
	node ifNil: [
		(blocks first successors size = 1 and: [
			 blocks first successors first == blocks second ]) ifTrue: [
			node := self
				        recognizeNestedLoopAt: blocks second
				        preheader: blocks first.
			node ifNil: [
				node := self recognizeLoopAt: blocks second preheader: blocks first ] ] ].
	node ifNil: [ ^ nil ].
	^ (self covers: node)
		  ifTrue: [ node ]
		  ifFalse: [ nil ]
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer >> recognizeLoopAt: headerBlk preheader: preBlk [
	| term bodyBlk exitBlk |
	term := headerBlk terminator.
	(term notNil and: [ term opcode = #jumpIf ]) ifFalse: [ ^ nil ].
	headerBlk successors size = 2 ifFalse: [ ^ nil ].
	bodyBlk := headerBlk successors first.
	exitBlk := headerBlk successors last.
	(bodyBlk successors includes: headerBlk) ifFalse: [ ^ nil ].
	^ PVLoopNode new
		preheaderBlock: preBlk; headerBlock: headerBlk;
		bodyBlocks: { bodyBlk }; exitBlock: exitBlk; yourself
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer >> recognizeNestedLoopAt: headerBlk preheader: preBlk [
	"An outer loop whose body is an inner loop. The outer body block is the inner loop's
	 preheader, so it has one successor and that successor is the inner header. Answer nil
	 for anything else, which leaves the shape to the single-loop recogniser or to refusal."

	| outerBody innerHeader |
	(self isTwoWayHeader: headerBlk) ifFalse: [ ^ nil ].
	outerBody := headerBlk successors first.
	outerBody successors size = 1 ifFalse: [ ^ nil ].
	innerHeader := outerBody successors first.
	(self isTwoWayHeader: innerHeader) ifFalse: [ ^ nil ].
	^ self
		  nestedLoopNodeAt: headerBlk
		  preheader: preBlk
		  innerPreheader: outerBody
		  innerHeader: innerHeader
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer >> recognizeSelectionAt: blk [

	| term trueBlk falseBlk merge |
	term := blk terminator.
	(term notNil and: [ term opcode = #jumpIf ]) ifFalse: [ ^ nil ].
	blk successors size = 2 ifFalse: [ ^ nil ].
	trueBlk := blk successors first.
	falseBlk := blk successors last.
	trueBlk successors isEmpty ifTrue: [ ^ nil ].
	merge := trueBlk successors first.
	(falseBlk successors isNotEmpty and: [
		 falseBlk successors first == merge ]) ifFalse: [
			(falseBlk isFallThrough and: [ falseBlk successors first == merge ])
				ifFalse: [ ^ nil ] ].
	^ PVSelectionNode new
		  condBlock: blk;
		  trueBlocks: { trueBlk };
		  falseBlocks: { falseBlk };
		  mergeBlock: merge;
		  yourself
]
