"
Runs the spirv-val command-line validator over a SPIR-V ByteArray. Finds the executable by searching PATH rather than assuming a fixed location, so a tool installed anywhere on PATH is used and an absent tool is reported as unavailable instead of silently skipped. Key methods: class-side findExecutable and isAvailable, instance-side isValid and validationOutput.
"
Class {
	#name : 'PVSpirvValidator',
	#superclass : 'Object',
	#instVars : [
		'spirv',
		'exitCode',
		'output'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'reporting' }
PVSpirvValidator class >> builtInNameFor: aNumber [
	"Reflect over SpvBuiltIn rather than keeping a second table that could drift from it."

	^ (SpvBuiltIn class selectors detect: [ :each | (SpvBuiltIn perform: each) = aNumber ]
		   ifNone: [ nil ])
		  ifNil: [ aNumber printString ]
		  ifNotNil: [ :selector | selector asString ]

]

{ #category : 'constants' }
PVSpirvValidator class >> byteMask [
	"The low eight bits of a word, for reading one packed byte of a literal string."

	^ 16rFF
]

{ #category : 'constants' }
PVSpirvValidator class >> bytesPerWord [
	^ 4
]

{ #category : 'constants' }
PVSpirvValidator class >> bytesPerWordIndices [
	"The byte positions inside a 32-bit word, used to look for a string's null terminator."

	^ 0 to: self bytesPerWord - 1
]

{ #category : 'constants' }
PVSpirvValidator class >> controlFlowOpcodeNames [
	"The merge and terminator opcodes the control-flow report names. Every other opcode
	 counts as ordinary work inside its block."
	^ Dictionary newFrom: {
		  SpvOpcode opLoopMerge -> 'OpLoopMerge'.
		  SpvOpcode opSelectionMerge -> 'OpSelectionMerge'.
		  SpvOpcode opBranch -> 'OpBranch'.
		  SpvOpcode opBranchConditional -> 'OpBranchConditional'.
		  SpvOpcode opReturn -> 'OpReturn'.
		  SpvOpcode opReturnValue -> 'OpReturnValue' }
]

{ #category : 'constants' }
PVSpirvValidator class >> decorationLiteralOffset [
	"OpDecorate: target, decoration, then the decoration's literals."

	^ 3

]

{ #category : 'constants' }
PVSpirvValidator class >> entryPointNameOffset [
	"OpEntryPoint: opcode word, execution model, function id, then the first word of the
	 null-terminated name. The interface ids follow the word that holds the terminator, so
	 their position depends on the name's length and cannot be a fixed offset."

	^ 3
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnComputeLoopKernel [
	"One click: the compute kernel whose body is a whileTrue:. spirv-val cannot see a
	 dropped loop, so read the Module tab for the OpLoopMerge as well as the verdict."
	<sampleInstance>
	^ self on: (PVKernelCompiler compile: (PVKernelExamples >> #sumFirst16:data:out:))
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnComputeSelectionKernel [
	"One click: the compute kernel whose body is an ifTrue:ifFalse:."
	<sampleInstance>
	^ self on: (PVKernelCompiler compile: (PVKernelExamples >> #clampNegatives:data:out:))
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnHalfVectorAddKernel [
	"One click: the half precision vector add. spirv-val refuses a 16-bit float in a
	 storage buffer unless the module declares Float16 and StorageBuffer16BitAccess, so the
	 verdict is what tells the two capabilities reached the module."

	<sampleInstance>
	^ self on:
		  (PVKernelCompiler compile:
			   (PVKernelExamples >> #vectorAddF16:a:b:out:))
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnMatmulKernel [
	"One click: the Phase 7 baseline matmul. The Entry point tab shows the 16 by 16
	 workgroup from the kernel's pragma and the numWorkgroups built-in it reads for N."

	<sampleInstance>
	^ self on: (PVKernelCompiler compile: (PVKernelExamples >> #matmulF32:a:b:out:))

]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnScalarKernel [
	"One click on the failing path: a scalar <gpu> method compiles to a SPIR-V function
	 with no OpEntryPoint, which spirv-val must refuse as a standalone module."
	<sampleInstance>
	^ self on: (PVKernelCompiler compile: (PVKernelExamples >> #relu:))
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnSharedBroadcastKernel [
	"One click: shared memory and a barrier compiled from Pharo source rather than
	 assembled through the builder. The entry point view shows whether the tile reached the
	 interface list, which is the one thing the DSL path can lose."

	<sampleInstance>
	^ self on:
		  (PVKernelCompiler compile:
			   (PVKernelExamples >> #broadcastFirstOf:data:out:tile:))
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnSubgroupDotKernel [
	"One click: the kernel that adds the lanes of a subgroup. The verdict is what tells the
	 two group capabilities and the Subgroup scope reached the module, because spirv-val
	 refuses the instruction without them."

	<sampleInstance>
	^ self on:
		  (PVKernelCompiler compile:
			   (PVKernelExamples >> #subgroupDotOf:a:b:out:lanes:))
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnTiledMatmulKernel [
	"One click: the hand-built tiled matmul. Nothing else checks this module's structured
	 control flow, its Workgroup variables or its barrier operands, because it is assembled
	 through the builder rather than compiled from a Pharo method."

	<sampleInstance>
	^ self on: PVTiledMatmulKernel new spirv
]

{ #category : 'examples' }
PVSpirvValidator class >> exampleValidatorOnVectorAddKernel [
	"One click: the compute kernel that must pass spirv-val."
	<sampleInstance>
	^ self on: (PVKernelCompiler compile: (PVKernelExamples >> #vectorAdd:a:b:out:))
]

{ #category : 'lookup' }
PVSpirvValidator class >> executableIn: aPathString [
	"Answer the first entry of a PATH-shaped string holding a runnable executableName,
	 or nil. Empty entries and files without an executable bit are no match."
	^ ((aPathString substrings: (String with: self pathSeparator))
		collect: [ :each | each asFileReference / self executableName ])
			detect: [ :candidate | candidate exists and: [ candidate isExecutable ] ]
			ifNone: [ nil ]
]

{ #category : 'constants' }
PVSpirvValidator class >> executableName [
	^ 'spirv-val'
]

{ #category : 'constants' }
PVSpirvValidator class >> executionModeLiteralOffset [
	"An OpExecutionMode names its entry point and its mode before any literal."

	^ 3

]

{ #category : 'lookup' }
PVSpirvValidator class >> findExecutable [
	^ self executableIn: self pathEnvironment
]

{ #category : 'constants' }
PVSpirvValidator class >> headerWordCount [
	"magic, version, generator, bound, schema"
	^ 5
]

{ #category : 'testing' }
PVSpirvValidator class >> isAvailable [
	^ self findExecutable isNotNil
]

{ #category : 'constants' }
PVSpirvValidator class >> mergeOpcodes [
	^ { SpvOpcode opLoopMerge. SpvOpcode opSelectionMerge }
]

{ #category : 'instance creation' }
PVSpirvValidator class >> on: aByteArray [
	| validator |
	validator := self new.
	validator spirv: aByteArray.
	^ validator
]

{ #category : 'constants' }
PVSpirvValidator class >> opcodeMask [
	"An instruction word is (wordCount << 16) | opcode."
	^ 16rFFFF
]

{ #category : 'lookup' }
PVSpirvValidator class >> pathEnvironment [
	^ OSEnvironment current at: 'PATH' ifAbsent: [ '' ]
]

{ #category : 'constants' }
PVSpirvValidator class >> pathSeparator [
	^ $:
]

{ #category : 'constants' }
PVSpirvValidator class >> targetEnv [
	^ 'vulkan1.3'
]

{ #category : 'constants' }
PVSpirvValidator class >> variableResultIdOffset [
	"OpVariable: opcode word, result type, then the result id."

	^ 2
]

{ #category : 'constants' }
PVSpirvValidator class >> variableStorageClassOffset [
	"OpVariable: opcode word, result type, result id, then the storage class."

	^ 3
]

{ #category : 'reading - instructions' }
PVSpirvValidator class >> wordHoldsStringTerminator: aWord [
	"A SPIR-V literal string packs four bytes to a word and ends at the first zero byte, so
	 the word holding the terminator is the name's last word whatever the name's length."

	^ self bytesPerWordIndices anySatisfy: [ :byteIndex |
		  ((aWord bitShift: byteIndex * -8) bitAnd: self byteMask) = 0 ]
]

{ #category : 'reporting' }
PVSpirvValidator >> builtInsFromWords [
	"Which built-ins the module reads, decoded from its OpDecorate instructions."

	| words index found |
	words := self spirvWords.
	found := OrderedCollection new.
	index := self class headerWordCount + 1.
	[ index <= words size ] whileTrue: [
		| word |
		word := words at: index.
		((word bitAnd: self class opcodeMask) = SpvOpcode opDecorate and: [
			 (words at: index + 2) = SpvDecoration builtIn ]) ifTrue: [
			found add: (self class builtInNameFor:
					 (words at: index + self class decorationLiteralOffset)) ].
		index := index + (word bitShift: -16) ].
	^ found asArray
]

{ #category : 'reporting' }
PVSpirvValidator >> controlFlowReport [
	"One row per basic block of the module: how many instructions it holds, the merge
	 instruction that declares its shape, and the terminator that leaves it. Decoded from
	 the bytes, so it states what the emitter really produced, not what it was asked for.
	 A compute kernel that lost its loop shows a single row with no merge, and spirv-val
	 still calls that module valid."

	| words rows index current |
	words := self spirvWords.
	rows := OrderedCollection new.
	current := nil.
	index := self class headerWordCount + 1.
	[ index <= words size ] whileTrue: [
		| word opcode |
		word := words at: index.
		opcode := word bitAnd: self class opcodeMask.
		opcode = SpvOpcode opLabel ifTrue: [
			current := self newControlFlowRowForBlock: (words at: index + 1).
			rows add: current ].
		opcode = SpvOpcode opFunctionEnd ifTrue: [ current := nil ].
		(current notNil and: [ opcode ~= SpvOpcode opLabel ]) ifTrue: [
			self record: opcode inControlFlowRow: current ].
		index := index + (word bitShift: -16) ].
	^ rows
]

{ #category : 'reporting' }
PVSpirvValidator >> countOfOpcode: anOpcode [
	"How many instructions of that opcode the module holds, walked the way every other
	 report here walks it: the first word of an instruction carries the opcode in its low
	 half and the instruction's word count in its high half."

	| count |
	count := 0.
	self instructionWordIndicesDo: [ :index :opcode |
		opcode = anOpcode ifTrue: [ count := count + 1 ] ].
	^ count
]

{ #category : 'reading - instructions' }
PVSpirvValidator >> entryPointInterfaceIds [
	"The variable ids the entry points name in their interface lists. Under SPIR-V 1.5 the
	 list must name every module-scope variable an entry point touches, so this is what a
	 missing Workgroup tile or a missing built-in shows up as."

	| words found |
	words := self spirvWords.
	found := OrderedCollection new.
	self instructionWordIndicesDo: [ :index :opcode |
		opcode = SpvOpcode opEntryPoint ifTrue: [
			| last nameEnd |
			last := index + ((words at: index) bitShift: -16) - 1.
			nameEnd := index + self class entryPointNameOffset.
			[ nameEnd <= last and: [
			  (self class wordHoldsStringTerminator: (words at: nameEnd)) not ] ]
				whileTrue: [ nameEnd := nameEnd + 1 ].
			nameEnd + 1 to: last do: [ :i | found add: (words at: i) ] ] ].
	^ found asArray
]

{ #category : 'reporting' }
PVSpirvValidator >> entryPointReport [
	"One row per fact about the entry point's interface with the dispatch: the declared
	 workgroup shape, the built-ins it reads, the shared tiles it declares and how many of
	 them the entry point names. The last two are read back from the instruction stream
	 rather than restated, because a tile missing from the interface list is invalid under
	 SPIR-V 1.5 and is otherwise invisible."

	| localSize tiles named |
	localSize := self localSizeFromWords.
	tiles := self variableIdsInStorageClass: SpvStorageClass workgroup.
	named := tiles count: [ :id | self entryPointInterfaceIds includes: id ].
	^ {
		  (Dictionary newFrom: {
				   (#setting -> 'Local size').
				   (#value -> localSize printString) }).
		  (Dictionary newFrom: {
				   (#setting -> 'Invocations per group').
				   (#value -> (localSize inject: 1 into: [ :a :b | a * b ]) printString) }).
		  (Dictionary newFrom: {
				   (#setting -> 'Built-ins read').
				   (#value -> (', ' join: self builtInsFromWords)) }).
		  (Dictionary newFrom: {
				   (#setting -> 'Shared tiles').
				   (#value -> tiles size printString) }).
		  (Dictionary newFrom: {
				   (#setting -> 'Tiles named by entry point').
				   (#value -> named printString) }) }
]

{ #category : 'validating' }
PVSpirvValidator >> exitCode [
	exitCode ifNil: [ self runValidator ].
	^ exitCode
]

{ #category : 'inspector' }
PVSpirvValidator >> inspectorControlFlow: aBuilder [
	"The basic-block structure of the module under validation. One row means the kernel is
	 straight-line code; a loop must show an OpLoopMerge and a selection an
	 OpSelectionMerge. Reading this is the only way to see a dropped loop, because the
	 Validation tab says valid either way."

	<inspectorPresentationOrder: 40 title: 'Control flow'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Block'
				   evaluated: [ :each | (each at: #block) printString ]);
		  addColumn: (SpStringTableColumn
				   title: 'Instructions'
				   evaluated: [ :each | (each at: #instructions) printString ]);
		  addColumn:
			  (SpStringTableColumn title: 'Merge' evaluated: [ :each |
					   each at: #merge ]);
		  addColumn: (SpStringTableColumn
				   title: 'Terminator'
				   evaluated: [ :each | each at: #terminator ]);
		  items: self controlFlowReport;
		  yourself
]

{ #category : 'inspector' }
PVSpirvValidator >> inspectorEntryPoint: aBuilder [
	"What the module tells the driver about its dispatch. A <localSize:> pragma that never
	 reached the emitter shows up here as 64, 1, 1, and a kernel that reads the grid shows
	 numWorkgroups among its built-ins."

	<inspectorPresentationOrder: 50 title: 'Entry point'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Setting' evaluated: [ :each |
					   each at: #setting ]);
		  addColumn:
			  (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each at: #value ]);
		  items: self entryPointReport;
		  yourself
]

{ #category : 'inspector' }
PVSpirvValidator >> inspectorValidation: aBuilder [
	<inspectorPresentationOrder: 30 title: 'Validation'>
	"Reports on a copy: asking for a verdict caches it, and a view must not change the
	 object being inspected."
	^ aBuilder newTable
		addColumn: (SpStringTableColumn title: 'Property' evaluated: [ :each | each key ]);
		addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each | each value printString ]);
		items: self copy validationReport;
		yourself
]

{ #category : 'private' }
PVSpirvValidator >> instructionWordIndicesDo: aBlock [
	"Walk the instruction stream once, handing each instruction's first word index and its
	 opcode to the block. The header is not an instruction, so the walk starts after it."

	| words index |
	words := self spirvWords.
	index := self class headerWordCount + 1.
	[ index <= words size ] whileTrue: [
		| word |
		word := words at: index.
		aBlock value: index value: (word bitAnd: self class opcodeMask).
		index := index + (word bitShift: -16) ]
]

{ #category : 'validating' }
PVSpirvValidator >> isValid [
	^ self exitCode = 0
]

{ #category : 'reporting' }
PVSpirvValidator >> localSizeFromWords [
	"The workgroup shape the module really declares, read from its OpExecutionMode. A
	 kernel's <localSize:> pragma is only a request until this says the same numbers."

	| words index |
	words := self spirvWords.
	index := self class headerWordCount + 1.
	[ index <= words size ] whileTrue: [
		| word wordCount |
		word := words at: index.
		wordCount := word bitShift: -16.
		((word bitAnd: self class opcodeMask) = SpvOpcode opExecutionMode and: [
			 (words at: index + 2) = SpvExecutionMode localSize ]) ifTrue: [
			^ ((index + self class executionModeLiteralOffset)
			   to: index + wordCount - 1) asArray collect: [ :each |
				  words at: each ] ].
		index := index + wordCount ].
	^ #( )
]

{ #category : 'reporting' }
PVSpirvValidator >> newControlFlowRowForBlock: anId [
	^ Dictionary new
		  at: #block put: anId;
		  at: #instructions put: 0;
		  at: #merge put: '';
		  at: #terminator put: '';
		  yourself
]

{ #category : 'reporting' }
PVSpirvValidator >> record: anOpcode inControlFlowRow: aRow [
	"A merge or terminator opcode names the block's shape; anything else is work inside it."

	| names |
	names := self class controlFlowOpcodeNames.
	(names includesKey: anOpcode) ifFalse: [
		^ aRow at: #instructions put: (aRow at: #instructions) + 1 ].
	aRow
		at: ((self class mergeOpcodes includes: anOpcode)
				 ifTrue: [ #merge ]
				 ifFalse: [ #terminator ])
		put: (names at: anOpcode)
]

{ #category : 'validating' }
PVSpirvValidator >> runValidator [
	"spirv-val writes its diagnostics to stderr, so both streams are captured together.
	 The temporary file is unique per run: two validators must not race on one name."
	| executable spirvFile outputFile command |
	executable := self class findExecutable
		ifNil: [ ^ Error signal: self class executableName , ' was not found on PATH' ].
	spirvFile := FileLocator temp / ('pv-' , UUID new asString36 , '.spv').
	outputFile := spirvFile , 'log'.
	[ spirvFile binaryWriteStreamDo: [ :stream | stream nextPutAll: spirv ].
	  command := executable fullName , ' --target-env ' , self class targetEnv , ' '
		, spirvFile fullName , ' > ' , outputFile fullName , ' 2>&1'.
	  exitCode := LibC system: command.
	  output := outputFile exists ifTrue: [ outputFile contents ] ifFalse: [ '' ] ]
		ensure: [ spirvFile ensureDelete. outputFile ensureDelete ]
]

{ #category : 'accessing' }
PVSpirvValidator >> spirv [
	^ spirv
]

{ #category : 'accessing' }
PVSpirvValidator >> spirv: aByteArray [
	spirv := aByteArray.
	exitCode := nil.
	output := nil
]

{ #category : 'reporting' }
PVSpirvValidator >> spirvWords [
	"SPIR-V is a little-endian stream of 32-bit words."

	| bytesPerWord |
	bytesPerWord := self class bytesPerWord.
	^ (1 to: spirv size by: bytesPerWord) collect: [ :each |
		  (spirv at: each) + ((spirv at: each + 1) bitShift: 8)
		  + ((spirv at: each + 2) bitShift: 16)
		  + ((spirv at: each + 3) bitShift: 24) ]
]

{ #category : 'validating' }
PVSpirvValidator >> validationOutput [
	output ifNil: [ self runValidator ].
	^ output
]

{ #category : 'validating' }
PVSpirvValidator >> validationReport [
	"Facts asked of the real lookup and the real tool, never restated, so the report cannot
	 drift from what validation actually does."
	| executable |
	executable := self class findExecutable.
	executable ifNil: [
		^ { 'executable' -> (self class executableName , ' not found on PATH') } ].
	^ { 'executable' -> executable fullName.
		'target environment' -> self class targetEnv.
		'module bytes' -> (spirv ifNil: [ 0 ] ifNotNil: [ spirv size ]).
		'exit code' -> self exitCode.
		'verdict' -> (self isValid ifTrue: [ 'valid' ] ifFalse: [ 'invalid' ]).
		'output' -> (self validationOutput ifEmpty: [ '(none)' ] ifNotEmpty: [ :text | text trimBoth ]) }
]

{ #category : 'reading - instructions' }
PVSpirvValidator >> variableCountInStorageClass: aStorageClass [
	"How many module-scope variables the module declares in that storage class."

	^ (self variableIdsInStorageClass: aStorageClass) size
]

{ #category : 'reading - instructions' }
PVSpirvValidator >> variableIdsInStorageClass: aStorageClass [
	"The result ids of the module-scope variables declared in that storage class. OpVariable
	 names its storage class in the operand after the result id, so this needs no access to
	 the type table."

	| words found |
	words := self spirvWords.
	found := OrderedCollection new.
	self instructionWordIndicesDo: [ :index :opcode |
		(opcode = SpvOpcode opVariable and: [
			 (words at: index + self class variableStorageClassOffset) = aStorageClass ])
			ifTrue: [
			found add: (words at: index + self class variableResultIdOffset) ] ].
	^ found asArray
]
