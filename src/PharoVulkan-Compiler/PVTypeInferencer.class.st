"
Infers SPIR-V types for each SSA register and resolves message sends to SPIR-V operations via PVSelectorTable. Stage 6 of the pipeline.
"
Class {
	#name : 'PVTypeInferencer',
	#superclass : 'Object',
	#instVars : [
		'annotation',
		'typeMap'
	],
	#category : 'PharoVulkan-Compiler-Pipeline',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Pipeline'
}

{ #category : 'accessing' }
PVTypeInferencer >> annotation [
^ annotation
]

{ #category : 'accessing' }
PVTypeInferencer >> annotation: ann [
	annotation := ann
]

{ #category : 'inferring' }
PVTypeInferencer >> inferAll: regOps selectorTable: st [
	"Seed param types from annotation"
	annotation params doWithIndex: [ :p :i |
		typeMap at: i put: p type ].
	regOps do: [ :op |
		(#(return returnSelf self pop) includes: op opcode) ifFalse: [
			self inferOp: op selectorTable: st ] ].
	^ typeMap
]

{ #category : 'inferring' }
PVTypeInferencer >> inferOp: op selectorTable: st [
	| recvType mapping resultType |
	op opcode = #const ifTrue: [
		"Infer from literal: Float -> f32, SmallInt -> i32"
		resultType := op literal isFloat ifTrue: [ #f32 ] ifFalse: [ #i32 ].
		self setType: op result forReg: op result.
		typeMap at: op result put: resultType.
		^ self ].
	op opcode = #send ifTrue: [
		recvType := typeMap at: (op inputs first) ifAbsent: [ nil ].
		recvType ifNil: [ PVTypeError signal: 'Cannot infer type for recv of ' , op literal ].
		mapping := st at: op literal receiverType: recvType.
		mapping ifNil: [ PVTypeError signal: 'No SPIR-V mapping for ' , op literal , ' on ' , recvType ].
		typeMap at: op result put: mapping resultTypeSymbol.
		^ self ].
	op opcode = #move ifTrue: [
		typeMap at: op result put: (typeMap at: op inputs first).
		^ self ]
]

{ #category : 'initialization' }
PVTypeInferencer >> initialize [

	super initialize.
	typeMap := Dictionary new
]

{ #category : 'inspector' }
PVTypeInferencer >> inspectorTypes: aBuilder [
	"The type of every register this inferencer reached, which is what a PVTypeError is read
	 against: a register missing here is the one the emitter could not type."

	<inspectorPresentationOrder: 10 title: 'Types'>
	^ PVFactRow
		  tableOf: self typeRows
		  nameColumn: 'Register'
		  valueColumn: 'Type'
		  in: aBuilder
]

{ #category : 'inspector' }
PVTypeInferencer >> parameterSuffixFor: aRegister in: aCollectionOfParams [
	"How a seeded register is named: the declared parameter whose position it is. A register
	 past the parameters was inferred from an operation and names nothing."

	^ (aRegister between: 1 and: aCollectionOfParams size)
		  ifTrue: [ ' (' , (aCollectionOfParams at: aRegister) name asString , ')' ]
		  ifFalse: [ '' ]
]

{ #category : 'private' }
PVTypeInferencer >> setType: aTypeSymbol forReg: regId [
	typeMap at: regId put: aTypeSymbol
]

{ #category : 'accessing' }
PVTypeInferencer >> typeMap [
^ typeMap
]

{ #category : 'accessing' }
PVTypeInferencer >> typeOf: regId [
	^ typeMap at: regId ifAbsent: [ PVTypeError signal: 'Unknown register: ' , regId printString ]
]

{ #category : 'inspector' }
PVTypeInferencer >> typeRows [
	"One row per register this inferencer typed, in register order. A register a declared
	 parameter seeded is named for that parameter: the inferencer seeds the register of each
	 parameter's own position, so the rule is counted here rather than restated."

	| params |
	params := annotation
		          ifNil: [ #(  ) ]
		          ifNotNil: [ annotation params ].
	^ (typeMap keys asSortedCollection collect: [ :key |
		   PVFactRow
			   name: key printString , (self parameterSuffixFor: key in: params)
			   value: (typeMap at: key) ]) asArray
]
