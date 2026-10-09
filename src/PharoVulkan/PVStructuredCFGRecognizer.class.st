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

{ #category : 'initialize-release' }
PVStructuredCFGRecognizer >> initialize: aBlockArray [
	blocks := aBlockArray.
	blockMap := Dictionary new.
	blocks do: [ :b | blockMap at: b id put: b ]
]

{ #category : 'recognizing' }
PVStructuredCFGRecognizer >> recognize [
	| node |
	blocks size >= 2 ifFalse: [ ^ nil ].
	node := self recognizeSelectionAt: blocks first.
	node ifNotNil: [ ^ node ].
	(blocks first successors size = 1 and: [
	 blocks first successors first == blocks second]) ifTrue: [
		node := self recognizeLoopAt: blocks second preheader: blocks first.
		node ifNotNil: [ ^ node ] ].
	^ nil
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
