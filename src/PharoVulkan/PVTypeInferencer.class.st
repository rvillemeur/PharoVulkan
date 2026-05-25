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
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'instance creation' }
PVTypeInferencer class >> annotation: ann inferAll: regOps selectorTable: st [
	^ self new initialize annotation: ann; inferAll: regOps selectorTable: st; yourself
]

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
