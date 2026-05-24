"
A SPIR-V function. Owns parameters and an ordered list of basic blocks.
The first block is the entry block. Allocated ids via module newId.
Key methods: addBlock, addParameter:, blocks, encodeInto:.
"
Class {
	#name : 'SpvFunction',
	#superclass : 'Object',
	#instVars : [
		'id',
		'module',
		'returnType',
		'functionType',
		'parameters',
		'blocks'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'instance creation' }
SpvFunction class >> on: aModule returnType: rt functionType: ft [
    ^ self new
        module: aModule;
        id: aModule newId;
        returnType: rt;
        functionType: ft;
        initialize;
        yourself
]

{ #category : 'building' }
SpvFunction >> addBlock [
    "Append a new empty block with a fresh label id. Returns the block."
    | blk |
    blk := SpvBlock new
        id: module newId;
        function: self;
        initialize;
        yourself.
    blocks add: blk.
    ^ blk
]

{ #category : 'building' }
SpvFunction >> addParameter: aType [
    "Append a function parameter of aType. Returns the parameter result id."
    | pid |
    pid := module newId.
    parameters add: (SpvInstruction
        opcode: SpvOpcode opFunctionParameter
        resultType: aType id
        resultId: pid
        operands: #()).
    ^ pid
]

{ #category : 'accessing' }
SpvFunction >> blocks [          ^ blocks
]

{ #category : 'accessing' }
SpvFunction >> functionType [    ^ functionType
]

{ #category : 'accessing' }
SpvFunction >> functionType: t [ functionType := t
]

{ #category : 'accessing' }
SpvFunction >> id [              ^ id
]

{ #category : 'accessing' }
SpvFunction >> id: x [           id := x
]

{ #category : 'initialization' }
SpvFunction >> initialize [

	super initialize.
	parameters := OrderedCollection new.
	blocks := OrderedCollection new
]

{ #category : 'accessing' }
SpvFunction >> module [          ^ module
]

{ #category : 'accessing' }
SpvFunction >> module: m [       module := m
]

{ #category : 'accessing' }
SpvFunction >> parameters [      ^ parameters
]

{ #category : 'accessing' }
SpvFunction >> returnType [      ^ returnType
]

{ #category : 'accessing' }
SpvFunction >> returnType: t [   returnType := t
]
