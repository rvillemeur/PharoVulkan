"
Maps a (selector, receiverType, argTypes) triple to a SPIR-V opcode or emit strategy. One entry in the PVSelectorTable dispatch table.
"
Class {
	#name : 'PVSelectorMapping',
	#superclass : 'Object',
	#instVars : [
		'spirvOp',
		'resultTypeSymbol'
	],
	#category : 'PharoVulkan-Compiler-Selectors',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Selectors'
}

{ #category : 'constants' }
PVSelectorMapping class >> emitterSelectors [
"The method of PVSPIRVEmitter that emits each operation this table names. An operation
 absent from here compiles to the plain SPIR-V opcode of its own name, which is what every
 arithmetic and comparison mapping does. A selector of three keywords takes the result
 type as its middle argument: only the mapping holding it can answer that, which is why
 this table lives here and not on the emitter."

^ Dictionary newFrom: {
(#bufferLoad -> #emitBufferLoad:block:).
(#bufferStore -> #emitBufferStore:block:).
(#sharedLoad -> #emitSharedLoad:block:).
(#sharedStore -> #emitSharedStore:block:).
(#coopMatrixLoad -> #emitCooperativeMatrixLoad:resultTypeSymbol:block:).
(#coopMatrixMulAdd -> #emitCooperativeMatrixMulAdd:resultTypeSymbol:block:).
(#coopMatrixStore -> #emitCooperativeMatrixStore:block:).
(#subgroupReduceSum -> #emitSubgroupReduceSum:resultTypeSymbol:block:).
(#workgroupBarrier -> #emitWorkgroupBarrier:block:).
(#workItemGridWidth -> #emitGridWidth:block:).
(#compositeConstruct -> #emitCompositeConstruct:block:).
(#workItemX -> #emitWorkItemX:block:).
(#workItemY -> #emitWorkItemY:block:).
(#workItemZ -> #emitWorkItemZ:block:).
(#workItemLocalX -> #emitWorkItemLocalX:block:).
(#workItemLocalY -> #emitWorkItemLocalY:block:).
(#workItemLocalZ -> #emitWorkItemLocalZ:block:).
(#vecExtractX -> #emitVecExtractX:block:).
(#vecExtractY -> #emitVecExtractY:block:).
(#vecExtractZ -> #emitVecExtractZ:block:).
(#vecExtractW -> #emitVecExtractW:block:).
(#glslNormalize -> #emitGlslNormalize:block:).
(#glslLength -> #emitGlslLength:block:).
(#glslFMix -> #emitGlslFMix:block:).
(#glslFClamp -> #emitGlslFClamp:block:).
(#glslSqrt -> #emitGlslSqrt:block:) }
]

{ #category : 'instance creation' }
PVSelectorMapping class >> spirvOp: op resultType: rt [
	^ self new spirvOp: op; resultTypeSymbol: rt; yourself
]

{ #category : 'emitting' }
PVSelectorMapping >> emitOn: anEmitter op: anOp block: aBlock [
	"Have the emitter emit this mapping's operation, and answer whether it did. A mapping with
	 no emitter method of its own answers false, which is the emitter's signal to emit the plain
	 opcode. The three-keyword emitters take the result type between the op and the block: this
	 mapping is the only object that holds it."

	| selector |
	selector := self emitterSelector ifNil: [ ^ false ].
	selector numArgs = 3
		ifTrue: [
			anEmitter
				perform: selector
				with: anOp
				with: resultTypeSymbol
				with: aBlock ]
		ifFalse: [ anEmitter perform: selector with: anOp with: aBlock ].
	^ true
]

{ #category : 'emitting' }
PVSelectorMapping >> emitterSelector [
	"The method of the emitter that emits this mapping, or nil when it is emitted as the plain
	 opcode of its own name."

	^ self class emitterSelectors at: spirvOp ifAbsent: [ nil ]
]

{ #category : 'inspector' }
PVSelectorMapping >> inspectorEmitting: aBuilder [
	"How this mapping is emitted, asked of the dispatch rather than restated: the emitter method
	 it names, or the plain opcode its own name spells when it names none, and whether that
	 method is handed the result type. A reader of one mapping sees the branch the emitter will
	 take without reading the emitter."

	<inspectorPresentationOrder: 10 title: 'Emitting'>
	| selector |
	selector := self emitterSelector.
	^ PVFactRow
		  tableOf: {
				  (PVFactRow name: 'spirvOp' value: spirvOp printString).
				  (PVFactRow name: 'result type' value: resultTypeSymbol printString).
				  (PVFactRow
					   name: 'emitted by'
					   value: (selector
							    ifNil: [ 'plain opcode ' , spirvOp asString uncapitalized ]
							    ifNotNil: [ :each | each printString ])).
				  (PVFactRow
					   name: 'takes the result type'
					   value: (selector notNil and: [ selector numArgs = 3 ]) printString) }
		  nameColumn: 'Property'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing' }
PVSelectorMapping >> resultTypeSymbol [
^ resultTypeSymbol
]

{ #category : 'accessing' }
PVSelectorMapping >> resultTypeSymbol: aSymbol [
	resultTypeSymbol := aSymbol
]

{ #category : 'accessing' }
PVSelectorMapping >> spirvOp [
^ spirvOp
]

{ #category : 'accessing' }
PVSelectorMapping >> spirvOp: aSymbol [
	spirvOp := aSymbol
]
