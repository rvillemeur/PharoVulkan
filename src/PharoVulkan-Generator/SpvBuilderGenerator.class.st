"
Generates SpvBuilder emit methods from SpvGrammarParser output.
One method per SPIR-V instruction. Re-running is idempotent (skips existing).
Key method: generateAll.
"
Class {
	#name : 'SpvBuilderGenerator',
	#superclass : 'Object',
	#instVars : [
		'parser'
	],
	#category : 'PharoVulkan-Generator',
	#package : 'PharoVulkan-Generator'
}

{ #category : 'generating' }
SpvBuilderGenerator >> generateAll [
    "Create one emit method on SpvBuilder per instruction in the grammar."
    parser instructions do: [:desc | self generateInstruction: desc]
]

{ #category : 'generating' }
SpvBuilderGenerator >> generateInstruction: anSpvInstructionDescriptor [
    "Emit one SpvBuilder method for the given instruction descriptor.
     Skips if the selector already exists (idempotent)."
    | selector src |
    selector := self selectorFor: anSpvInstructionDescriptor.
    (SpvBuilder includesSelector: selector asSymbol) ifTrue: [^self].
    src := self methodSourceFor: anSpvInstructionDescriptor selector: selector.
    SpvBuilder compile: src classified: 'generated-instructions'
]

{ #category : 'generating' }
SpvBuilderGenerator >> methodSourceFor: anSpvInstructionDescriptor selector: selector [
	"Generate the method source string for one SPIR-V builder method."

	| buf ops hasResult hasResultType params |
	ops := anSpvInstructionDescriptor operands.
	hasResultType := ops anySatisfy: [ :op | op kind = 'IdResultType' ].
	hasResult := ops anySatisfy: [ :op | op kind = 'IdResult' ].
	params := ops select: [ :op |
			          op quantifier = #required and: [
				          (op kind = 'IdResultType' or: [ op kind = 'IdResult' ])
					          not ] ].
	buf := WriteStream on: String new.
	buf nextPutAll: selector.
	params do: [ :op |
			| pname |
			pname := op name
				         ifNil: [
						         op kind first asLowercase asString
						         , (op kind copyFrom: 2 to: op kind size) ]
				         ifNotNil: [ :n |
				         n first asLowercase asString , (n copyFrom: 2 to: n size) ].
			buf nextPutAll: ' a' , pname first asUppercase asString
				, (pname copyFrom: 2 to: pname size) ].
	buf nextPutAll: (String with: Character cr).
	buf nextPutAll: '    | instr'.
	hasResult ifTrue: [ buf nextPutAll: ' resultId' ].
	buf nextPutAll: ' |' , (String with: Character cr).
	hasResult ifTrue: [
			buf nextPutAll:
				'    resultId := module newId.' , (String with: Character cr) ].
	buf nextPutAll:
		'    instr := SpvInstruction new' , (String with: Character cr).
	buf nextPutAll:
		'        opcode: SpvOpcode ' , anSpvInstructionDescriptor opname
		, ';' , (String with: Character cr).
	hasResultType ifTrue: [
			buf
				nextPutAll: '        resultType: aIdResultType;';
				nextPutAll: (String with: Character cr) ].
	hasResult ifTrue: [
			buf nextPutAll:
				'        resultId: resultId;' , (String with: Character cr) ].
	buf nextPutAll: '        operands: {'.
	params do: [ :op |
			| pname |
			pname := op name
				         ifNil: [
						         op kind first asLowercase asString
						         , (op kind copyFrom: 2 to: op kind size) ]
				         ifNotNil: [ :n |
				         n first asLowercase asString , (n copyFrom: 2 to: n size) ].
			buf nextPutAll: 'a' , pname first asUppercase asString
				, (pname copyFrom: 2 to: pname size) , '. ' ].
	buf nextPutAll: '};' , (String with: Character cr).
	buf nextPutAll: '    self currentBlock addInstruction: instr.'
		, (String with: Character cr).
	hasResult ifTrue: [ buf nextPutAll: '    ^ resultId' ].
	^ buf contents
]

{ #category : 'accessing' }
SpvBuilderGenerator >> parser: aSpvGrammarParser [
    parser := aSpvGrammarParser
]

{ #category : 'generating' }
SpvBuilderGenerator >> selectorFor: anSpvInstructionDescriptor [
	"Convert OpFAdd -> emitFAdd:left:right: based on operand names."

	| opname base required parts |
	opname := anSpvInstructionDescriptor opname.
	base := 'emit' , (opname copyFrom: 3 to: opname size).
	required := anSpvInstructionDescriptor operands select: [ :op |
			            op quantifier = #required and: [
				            (#( 'IdResultType' 'IdResult' ) includes: op kind) not ] ].
	required isEmpty ifTrue: [ ^ base ].
	parts := WriteStream on: String new.
	required doWithIndex: [ :op :i |
			| paramName |
			paramName := op name
				             ifNil: [
						             op kind first asLowercase asString
						             , (op kind copyFrom: 2 to: op kind size) ]
				             ifNotNil: [ :n |
				             n first asLowercase asString
				             , (n copyFrom: 2 to: n size) ].
			i = 1
				ifTrue: [
						parts
							nextPutAll: base;
							nextPutAll: ': ' ]
				ifFalse: [
						parts
							nextPutAll: paramName;
							nextPutAll: ': ' ] ].
	^ parts contents trimmed
]
