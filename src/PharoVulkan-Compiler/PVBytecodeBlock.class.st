"
A contiguous range of Sista bytecodes forming one CFG block. Holds start PC, end PC, successor PCs, and the list of decoded PVBytecodeOp instructions. Produced by PVCFGBuilder.
"
Class {
	#name : 'PVBytecodeBlock',
	#superclass : 'Object',
	#instVars : [
		'id',
		'startPc',
		'ops',
		'successors',
		'predecessors'
	],
	#category : 'PharoVulkan-Compiler-Bytecode',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Bytecode'
}

{ #category : 'accessing' }
PVBytecodeBlock >> id [
^ id
]

{ #category : 'accessing' }
PVBytecodeBlock >> id: n [
	id := n
]

{ #category : 'initialization' }
PVBytecodeBlock >> initialize [

	super initialize.
	ops := OrderedCollection new.
	successors := OrderedCollection new.
	predecessors := OrderedCollection new
]

{ #category : 'testing' }
PVBytecodeBlock >> isFallThrough [
	^ self terminator isNil
]

{ #category : 'accessing' }
PVBytecodeBlock >> ops [
^ ops
]

{ #category : 'accessing' }
PVBytecodeBlock >> predecessors [
^ predecessors
]

{ #category : 'accessing' }
PVBytecodeBlock >> predecessors: c [
	predecessors := c
]

{ #category : 'accessing' }
PVBytecodeBlock >> startPc: n [
	startPc := n
]

{ #category : 'accessing' }
PVBytecodeBlock >> successors [
^ successors
]

{ #category : 'accessing' }
PVBytecodeBlock >> successors: c [
	successors := c
]

{ #category : 'accessing' }
PVBytecodeBlock >> terminator [

	| last |
	ops isEmpty ifTrue: [ ^ nil ].
	last := ops last.
	^ (#( #jump #jumpIf #returnTop #returnSelf ) includes: last opcode)
		  ifTrue: [ last ]
]
