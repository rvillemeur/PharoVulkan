"
One entry of a module's annotation section: a target id, a decoration number and the decoration's literals. Abstract. A kind of annotation answers the opcode and the operands of the instruction it emits, and instruction builds that instruction, so the serializer writes the section without knowing what kinds exist. Key methods: instruction, opcode, operands.
"
Class {
	#name : 'SpvAnnotation',
	#superclass : 'Object',
	#instVars : [
		'target',
		'decoration',
		'literals'
	],
	#category : 'PharoVulkan-SPIRV-Builder',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Builder'
}

{ #category : 'instance creation' }
SpvAnnotation class >> target: anId decoration: aDecorationNumber literals: aCollection [
"An annotation of this id, with the literals its decoration asks for. Shared by both kinds,
	 since the member index is all the second one adds."

^ self new
	  setTarget: anId decoration: aDecorationNumber literals: aCollection;
	  yourself
]

{ #category : 'inspecting' }
SpvAnnotation >> annotationRows [
	"Name and value pairs read by inspectorAnnotation:. The instruction and the decoration are
	 named through the reverse lookups of the constant classes, and fall back to the number,
	 because a module may carry a decoration this binding's constants do not cover. The operand
	 row is the operands of the instruction this annotation emits, so the row cannot drift from
	 what is written into the module."

	^ {
		  ('instruction' -> self opcodeName).
		  ('target' -> target printString) } , self memberRows , {
		  ('decoration' -> self decorationName).
		  ('literals' -> literals asArray printString).
		  ('operands' -> self instruction operands asArray printString) }
]

{ #category : 'accessing' }
SpvAnnotation >> decoration [
	^ decoration
]

{ #category : 'inspecting' }
SpvAnnotation >> decorationName [
	^ (SpvDecoration nameOfDecoration: decoration)
		  ifNil: [ decoration printString ]
		  ifNotNil: [ :each | each asString ]
]

{ #category : 'inspecting' }
SpvAnnotation >> inspectorAnnotation: aBuilder [
	"What this annotation writes into the module: the instruction and the decoration by name,
	 the target, the member where there is one, the literals, and the operand words. Reads
	 annotationRows and mutates nothing it shows."

	<inspectorPresentationOrder: 10 title: 'Annotation'>
	^ PVFactRow
		  tableOf: (self annotationRows collect: [ :each |
				   PVFactRow name: each key value: each value ])
		  nameColumn: 'Property'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'emitting' }
SpvAnnotation >> instruction [
	"The one instruction this annotation emits, built from the opcode and the operands its own
	 kind answers. An annotation carries no result id."

	^ SpvInstruction opcode: self opcode operands: self operands
]

{ #category : 'accessing' }
SpvAnnotation >> literals [
	^ literals
]

{ #category : 'inspecting' }
SpvAnnotation >> memberRows [
	"The rows a kind of annotation carrying a member index adds between the target and the
	 decoration. A plain decoration names no member, so it adds none."

	^ #(  )
]

{ #category : 'emitting' }
SpvAnnotation >> opcode [
	^ self subclassResponsibility
]

{ #category : 'inspecting' }
SpvAnnotation >> opcodeName [
	^ (SpvOpcode nameOfOpcode: self opcode)
		  ifNil: [ self opcode printString ]
		  ifNotNil: [ :each | each asString ]
]

{ #category : 'emitting' }
SpvAnnotation >> operands [
	^ self subclassResponsibility
]

{ #category : 'initialization' }
SpvAnnotation >> setTarget: anId decoration: aDecorationNumber literals: aCollection [
	target := anId.
	decoration := aDecorationNumber.
	literals := aCollection
]

{ #category : 'accessing' }
SpvAnnotation >> target [
	^ target
]
