"
Builds the control-flow graph from a flat list of PVBytecodeOp instructions. Identifies basic block boundaries at jump targets, wires successor edges, and returns an array of PVBytecodeBlock. Stage 4 of the pipeline.
"
Class {
	#name : 'PVCFGBuilder',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'building' }
PVCFGBuilder class >> buildBytecodeBlocks: bytecodeOps [
	"Split flat bytecodeOps into PVBytecodeBlocks."
	| leaders blockMap blocks sorted |
	leaders := Set new.
	bytecodeOps isEmpty ifTrue: [ ^ #() ].
	leaders add: (bytecodeOps first) pc.
	bytecodeOps doWithIndex: [ :op :i |
		(#(#jump #jumpIf) includes: op opcode) ifTrue: [
			leaders add: op operands first.
			(i < bytecodeOps size) ifTrue: [
				leaders add: (bytecodeOps at: i + 1) pc ] ] ].
	sorted := leaders asSortedCollection.
	blockMap := Dictionary new.
	sorted doWithIndex: [ :pc :i |
		| blk |
		blk := PVBytecodeBlock new initialize.
		blk id: i.
		blk startPc: pc.
		blockMap at: pc put: blk ].
	"Assign each op to the block whose startPc is highest but <= op.pc"
	bytecodeOps do: [ :op |
		| blkPc blk |
		blkPc := sorted detect: [ :pc | pc <= op pc ] ifNone: [ sorted first ].
		"Find largest leader <= op.pc"
		blkPc := (sorted select: [ :pc | pc <= op pc ]) last.
		blk := blockMap at: blkPc.
		blk ops add: op ].
	blocks := sorted collect: [ :pc | blockMap at: pc ].
	"Wire successors and predecessors"
	blocks doWithIndex: [ :blk :i |
		| term |
		term := blk terminator.
		term isNil ifTrue: [
			"Fall-through to next block"
			(i < blocks size) ifTrue: [
				| next |
				next := blocks at: i + 1.
				blk successors add: next.
				next predecessors add: blk ] ].
		(term notNil and: [ term opcode = #jump ]) ifTrue: [
			| target |
			target := blockMap at: term operands first ifAbsent: [ nil ].
			target ifNotNil: [
				blk successors add: target.
				target predecessors add: blk ] ].
		(term notNil and: [ term opcode = #jumpIf ]) ifTrue: [
			| ftTarget jTarget |
			"Fall-through: next block in sorted order"
			(i < blocks size) ifTrue: [
				ftTarget := blocks at: i + 1.
				blk successors add: ftTarget.
				ftTarget predecessors add: blk ].
			"Jump target"
			jTarget := blockMap at: term operands first ifAbsent: [ nil ].
			jTarget ifNotNil: [
				blk successors add: jTarget.
				jTarget predecessors add: blk ] ] ].
	^ blocks asArray
]

{ #category : 'building' }
PVCFGBuilder class >> buildFrom: aRegisterOpArray [
	| blk cfg |
	blk := PVBasicBlock new.
	blk id: 0.
	blk ops: aRegisterOpArray.
	blk successors: #().
	blk predecessors: #().
	cfg := PVControlFlowGraph new.
	cfg entry: blk.
	cfg blocks: { blk }.
	^ cfg
]
