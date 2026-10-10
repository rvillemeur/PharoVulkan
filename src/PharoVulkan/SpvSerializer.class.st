"
Serializes a SpvModule into a SPIR-V binary ByteArray in the correct section order.
Use SpvSerializer serialize: aModule to produce the bytes.
Key methods: serialize: (class-side).
"
Class {
	#name : 'SpvSerializer',
	#superclass : 'Object',
	#instVars : [
		'module',
		'words'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvSerializer class >> capabilityTable [
    "Maps symbolic capability names to SPIR-V integer values."
    ^ Dictionary newFrom: {
        #Matrix          -> 0.
        #Shader          -> 1.
        #Geometry        -> 2.
        #Tessellation    -> 3.
        #Addresses       -> 4.
        #Int64           -> 11.
        #Float64         -> 10.
        #Float16         -> 9.
        #StorageBuffer16BitAccess -> 4423 }
]

{ #category : 'constants' }
SpvSerializer class >> generatorId [   ^ 16r50485600
]

{ #category : 'api' }
SpvSerializer class >> serialize: aModule [
    ^ self new serializeModule: aModule
]

{ #category : 'constants' }
SpvSerializer class >> spirvMagic [    ^ 16r07230203
]

{ #category : 'constants' }
SpvSerializer class >> spirvVersion [  ^ 16r00010500
]

{ #category : 'private' }
SpvSerializer >> emit: anInstruction [
    anInstruction encodeInto: words
]

{ #category : 'emit-sections' }
SpvSerializer >> emitAnnotations [
    module decorations do: [:d |
        | kind ops instr |
        kind := d at: 1.
        kind = #decorate ifTrue: [
            ops := OrderedCollection with: (d at: 2) with: (d at: 3).
            (d at: 4) do: [:l | ops add: l].
            instr := SpvInstruction opcode: SpvOpcode opDecorate operands: ops asArray ].
        kind = #memberDecorate ifTrue: [
            ops := OrderedCollection with: (d at: 2) with: (d at: 3) with: (d at: 4).
            (d at: 5) do: [:l | ops add: l].
            instr := SpvInstruction opcode: SpvOpcode opMemberDecorate operands: ops asArray ].
        instr ifNotNil: [ self emit: instr ] ]
]

{ #category : 'emit-sections' }
SpvSerializer >> emitCapabilities [
    | table |
    table := self class capabilityTable.
    module capabilities do: [:cap |
        | value |
        value := cap isInteger
            ifTrue: [cap]
            ifFalse: [table at: cap ifAbsent: [Error signal: 'Unknown capability: ' , cap]].
        self emit: (SpvInstruction
            opcode: SpvOpcode opCapability
            operands: { value }) ]
]

{ #category : 'emit-sections' }
SpvSerializer >> emitEntryPoints [
    module entryPoints do: [:ep |
        | func modelInt name interfaces ops |
        func := ep at: 1. modelInt := ep at: 2.
        name := ep at: 3. interfaces := ep at: 4.
        ops := OrderedCollection new.
        ops add: modelInt.
        ops add: func id.
        (self encodeString: name) do: [:w | ops add: w].
        interfaces do: [:v | ops add: v id].
        self emit: (SpvInstruction
            opcode: SpvOpcode opEntryPoint
            operands: ops asArray) ]
]

{ #category : 'emit-sections' }
SpvSerializer >> emitExecutionModes [
    module executionModes do: [:em |
        | func modeInt literals ops |
        func := em at: 1. modeInt := em at: 2. literals := em at: 3.
        ops := OrderedCollection with: func id with: modeInt.
        literals do: [:l | ops add: l].
        self emit: (SpvInstruction
            opcode: SpvOpcode opExecutionMode
            operands: ops asArray) ]
]

{ #category : 'emit-sections' }
SpvSerializer >> emitExtInstImports [
    module extInstSets keysAndValuesDo: [:name :id |
        self emit: (SpvInstruction
            opcode: SpvOpcode opExtInstImport
            resultType: nil
            resultId: id
            operands: (self encodeString: name)) ]
]

{ #category : 'emit-sections' }
SpvSerializer >> emitExtensions [
    module extensions do: [:ext |
        self emit: (SpvInstruction
            opcode: SpvOpcode opExtension
            operands: (self encodeString: ext)) ]
]

{ #category : 'emit-sections' }
SpvSerializer >> emitFunctions [
    module functions do: [:func |
        "OpFunction"
        self emit: (SpvInstruction
            opcode: SpvOpcode opFunction
            resultType: func returnType id
            resultId: func id
            operands: { 0. func functionType id }).
        "OpFunctionParameter*"
        func parameters do: [:p | self emit: p].
        "Blocks"
        func blocks do: [:blk |
            self emit: (SpvInstruction
                opcode: SpvOpcode opLabel
                resultType: nil
                resultId: blk id
                operands: #()).
            blk instructions do: [:i | self emit: i].
            blk terminator ifNotNil: [:t | self emit: t]].
        "OpFunctionEnd"
        self emit: (SpvInstruction opcode: SpvOpcode opFunctionEnd operands: #()) ]
]

{ #category : 'emit-sections' }
SpvSerializer >> emitHeader [
    "5-word SPIR-V header — no magic numbers, all values from named class methods."
    words nextPut: self class spirvMagic.
    words nextPut: self class spirvVersion.
    words nextPut: self class generatorId.
    words nextPut: module bound.
    words nextPut: 0
]

{ #category : 'emit-sections' }
SpvSerializer >> emitMemoryModel [
    self emit: (SpvInstruction
        opcode: SpvOpcode opMemoryModel
        operands: { module addressingModel. module memoryModel })
]

{ #category : 'emit-sections' }
SpvSerializer >> emitTypesConstantsGlobals [
	"Types, constants and global variables share one section of the module, and inside it a
	 definition must precede every use of its id. Emitting all types and only then all
	 constants broke that for a fixed-size array, whose length is the id of a constant.
	 Result ids come from one counter in creation order, and nothing can be built before the
	 things it is built from, so ascending id is a dependency order."

	| items |
	items := OrderedCollection new.
	module typeRegistry allTypes do: [ :each |
		items add: each id -> each instruction ].
	module constantPool allConstants do: [ :each |
		items add: each resultId -> each ].
	module globalVariables do: [ :each |
		items add: each id -> each instruction ].
	(items asSortedCollection: [ :a :b | a key <= b key ]) do: [ :each |
		self emit: each value ]
]

{ #category : 'private' }
SpvSerializer >> encodeString: aString [
    "Encode a null-terminated string as an array of 32-bit words, padded to 4 bytes."
    | bytes wordCount result byteStream |
    bytes := aString utf8Encoded.
    wordCount := (bytes size + 1 + 3) // 4.
    result := Array new: wordCount withAll: 0.
    byteStream := bytes copyWith: 0.
    1 to: byteStream size do: [:i |
        | wordIndex byteIndex |
        wordIndex := (i - 1) // 4 + 1.
        byteIndex := (i - 1) \\ 4.
        result at: wordIndex put: ((result at: wordIndex) bitOr: ((byteStream at: i) bitShift: byteIndex * 8))].
    ^ result
]

{ #category : 'serialization' }
SpvSerializer >> serializeModule: aSpvModule [
    module := aSpvModule.
    words := WriteStream on: (Array new: 256).
    self emitHeader.
    self emitCapabilities.
    self emitExtensions.
    self emitExtInstImports.
    self emitMemoryModel.
    self emitEntryPoints.
    self emitExecutionModes.
    self emitAnnotations.
    self emitTypesConstantsGlobals.
    self emitFunctions.
    ^ self wordsToBytes
]

{ #category : 'private' }
SpvSerializer >> wordsToBytes [
    | wordArray bytes |
    wordArray := words contents.
    bytes := ByteArray new: wordArray size * 4.
    wordArray doWithIndex: [:word :wi |
        | base |
        base := (wi - 1) * 4 + 1.
        bytes at: base     put: (word bitAnd: 16rFF).
        bytes at: base + 1 put: ((word bitShift: -8)  bitAnd: 16rFF).
        bytes at: base + 2 put: ((word bitShift: -16) bitAnd: 16rFF).
        bytes at: base + 3 put: ((word bitShift: -24) bitAnd: 16rFF)].
    ^ bytes
]
