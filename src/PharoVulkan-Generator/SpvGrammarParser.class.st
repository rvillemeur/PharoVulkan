"
Parses spirv.core.grammar.json and produces instruction and operand descriptors.
Output drives the SPIR-V builder API and the emitter.
Key methods: parseFile: aFilePath, instructions, operandKinds.
"
Class {
	#name : 'SpvGrammarParser',
	#superclass : 'Object',
	#instVars : [
		'grammar',
		'instructions',
		'operandKinds'
	],
	#category : 'PharoVulkan-Generator-SPIRV',
	#package : 'PharoVulkan-Generator',
	#tag : 'SPIRV'
}

{ #category : 'accessing' }
SpvGrammarParser >> instructions [
    ^ instructions
]

{ #category : 'parsing' }
SpvGrammarParser >> parseFile: aFilePath [
    "Load and parse the SPIR-V grammar JSON file at aFilePath."
    | json |
    json := NeoJSONReader fromString: aFilePath asFileReference contents.
    grammar := json.
    self parseInstructions.
    self parseOperandKinds
]

{ #category : 'parsing' }
SpvGrammarParser >> parseInstructions [
    "Build instructions dictionary from the grammar instruction list."
    instructions := Dictionary new.
    (grammar at: 'instructions') do: [:entry |
        | desc |
        desc := SpvInstructionDescriptor new.
        desc opname: (entry at: 'opname').
        desc opcode: (entry at: 'opcode').
        desc capabilities: ((entry at: 'capabilities' ifAbsent: [#()]) asArray).
        desc operands: ((entry at: 'operands' ifAbsent: [#()]) collect: [:op |
            | od quant |
            od := SpvOperandDescriptor new.
            od kind: (op at: 'kind').
            od name: (op at: 'name' ifAbsent: [nil]).
            quant := op at: 'quantifier' ifAbsent: [nil].
            od quantifier: (quant
                ifNil: [#required]
                ifNotNil: [
                    quant = '?' ifTrue: [#optional] ifFalse: [#variadic]]).
            od]) asArray.
        instructions at: desc opname put: desc]
]

{ #category : 'parsing' }
SpvGrammarParser >> parseOperandKinds [
    "Build operandKinds dictionary from the grammar operand_kinds list."
    operandKinds := Dictionary new.
    (grammar at: 'operand_kinds' ifAbsent: [#()]) do: [:entry |
        operandKinds at: (entry at: 'kind') put: entry]
]
