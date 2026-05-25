"
Deduplicates SPIR-V constant declarations within a module.
Key methods: constantBool:, constantInt32:, constantUInt32:, constantFloat32:, constantNull:.
"
Class {
	#name : 'SpvConstantPool',
	#superclass : 'Object',
	#instVars : [
		'module',
		'constants'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'instance creation' }
SpvConstantPool class >> on: aModule [
    ^ self new module: aModule; yourself
]

{ #category : 'accessing' }
SpvConstantPool >> allConstants [ ^ constants values
]

{ #category : 'constants' }
SpvConstantPool >> constantBool: aBoolean [
    | key typeId opcode id instr |
    key := Array with: #bool with: aBoolean.
    ^ (constants at: key ifAbsent: [
        typeId := module typeRegistry boolType id.
        opcode := aBoolean ifTrue: [SpvOpcode opConstantTrue] ifFalse: [SpvOpcode opConstantFalse].
        id := module newId.
        instr := SpvInstruction opcode: opcode resultType: typeId resultId: id operands: #().
        self register: instr key: key]) resultId
]

{ #category : 'constants' }
SpvConstantPool >> constantFloat32: aFloat [
    | key typeId id instr bits |
    key := Array with: #float32 with: aFloat.
    ^ (constants at: key ifAbsent: [
        typeId := (module typeRegistry floatType: 32) id.
        id := module newId.
        bits := aFloat isNaN
            ifTrue: [ 16r7FC00000 ]
            ifFalse: [ aFloat asIEEE32BitWord ].
        instr := SpvInstruction opcode: SpvOpcode opConstant
            resultType: typeId resultId: id
            operands: { bits }.
        self register: instr key: key]) resultId
]

{ #category : 'constants' }
SpvConstantPool >> constantInt32: anInteger [
    | key typeId id instr |
    key := Array with: #int32 with: anInteger.
    ^ (constants at: key ifAbsent: [
        typeId := (module typeRegistry intType: 32 signed: true) id.
        id := module newId.
        instr := SpvInstruction opcode: SpvOpcode opConstant
            resultType: typeId resultId: id
            operands: { anInteger bitAnd: 16rFFFFFFFF }.
        self register: instr key: key]) resultId
]

{ #category : 'constants' }
SpvConstantPool >> constantUInt32: anInteger [
    | key typeId id instr |
    key := Array with: #uint32 with: anInteger.
    ^ (constants at: key ifAbsent: [
        typeId := (module typeRegistry intType: 32 signed: false) id.
        id := module newId.
        instr := SpvInstruction opcode: SpvOpcode opConstant
            resultType: typeId resultId: id
            operands: { anInteger bitAnd: 16rFFFFFFFF }.
        self register: instr key: key]) resultId
]

{ #category : 'initialization' }
SpvConstantPool >> initialize [

	super initialize.
	constants := Dictionary new
]

{ #category : 'accessing' }
SpvConstantPool >> module: m [   module := m
]

{ #category : 'private' }
SpvConstantPool >> register: anInstruction key: aKey [
    "Store instruction by key. Returns the instruction (caller extracts resultId)."
    constants at: aKey put: anInstruction.
    ^ anInstruction
]
