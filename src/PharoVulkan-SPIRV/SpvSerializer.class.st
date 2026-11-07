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
	#category : 'PharoVulkan-SPIRV-Emitter',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Emitter'
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

{ #category : 'constants' }
SpvSerializer class >> initialWordCapacity [
"How many words the stream a module is serialised into starts at. A WriteStream grows on its
	 own, so this is a first guess at the size of a module and nothing a reader of the bytes can
	 depend on; it is named here rather than written into serializeModule: so that guess is
	 visible and adjustable in one place."

^ 256
]

{ #category : 'constants' }
SpvSerializer class >> sectionSelectorPrefix [
	"What every section method of a module is named for, which is how serializeModule: is read
	 for its sections."

	^ 'emit'
]

{ #category : 'reflection' }
SpvSerializer class >> sectionSelectors [
	"The sections of a module, in the order serializeModule: sends them. Read from that
	 method's own syntax tree rather than listed again, so a section added, removed or moved
	 cannot leave the Sections view behind."

	^ ((self >> #serializeModule:) ast body statements select: [ :each |
		   each isMessage and: [
			   each receiver isSelfVariable and: [
				   each selector beginsWith: self sectionSelectorPrefix ] ] ]) collect: [ :each |
		  each selector ]
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
	"Each annotation answers the instruction it emits, so this section decides only where the
	 annotations go."

	module decorations do: [ :each | self emit: each instruction ]
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

{ #category : 'inspector' }
SpvSerializer >> inspectorSections: aBuilder [
	"The sections of the module this serializer wrote, in the order SPIR-V asks for them, with
	 the words each one contributed. A module spirv-val refuses is read here first: a section
	 of zero words says what the module never declared."

	<inspectorPresentationOrder: 10 title: 'Sections'>
	^ PVFactRow
		  tableOf: self sectionRows
		  nameColumn: 'Section'
		  valueColumn: 'Words'
		  in: aBuilder
]

{ #category : 'inspector' }
SpvSerializer >> sectionRows [
	"One row per section of the module, naming the words that section wrote. The counts are
	 measured by replaying the sections on a serializer of this class's own making, so reading a
	 serializer never writes into the one being read. A serializer that has serialized nothing
	 has no sections to show."

	| replay rows |
	module ifNil: [ ^ #(  ) ].
	replay := self class new.
	replay startOn: module.
	rows := OrderedCollection new.
	self class sectionSelectors do: [ :each |
		| before |
		before := replay wordCount.
		replay perform: each.
		rows add: (PVFactRow name: each value: replay wordCount - before) ].
	^ rows asArray
]

{ #category : 'api' }
SpvSerializer >> serializeModule: aSpvModule [
	self startOn: aSpvModule.
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
SpvSerializer >> startOn: aSpvModule [
	"The one place a serializer is readied for a module: the module it writes and the word
	 stream it writes into. serializeModule: sends it before the first section, and the
	 Sections view sends it to a serializer of its own, so the two cannot disagree about what
	 a section starts from."

	module := aSpvModule.
	words := WriteStream on: (Array new: self class initialWordCapacity)
]

{ #category : 'accessing' }
SpvSerializer >> wordCount [
	"How many words have been written so far. A serializer that has not started answers none."

	^ words ifNil: [ 0 ] ifNotNil: [ words position ]
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
