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

{ #category : 'constants' }
PVSpirvValidator class >> bytesPerWord [
	^ 4
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
PVSpirvValidator class >> exampleValidatorOnScalarKernel [
	"One click on the failing path: a scalar <gpu> method compiles to a SPIR-V function
	 with no OpEntryPoint, which spirv-val must refuse as a standalone module."
	<sampleInstance>
	^ self on: (PVKernelCompiler compile: (PVKernelExamples >> #relu:))
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

{ #category : 'validating' }
PVSpirvValidator >> isValid [
	^ self exitCode = 0
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
