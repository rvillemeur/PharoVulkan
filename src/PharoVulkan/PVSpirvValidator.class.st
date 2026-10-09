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

{ #category : 'instance creation' }
PVSpirvValidator class >> on: aByteArray [
	| validator |
	validator := self new.
	validator spirv: aByteArray.
	^ validator
]

{ #category : 'validating' }
PVSpirvValidator >> exitCode [
	exitCode ifNil: [ self runValidator ].
	^ exitCode
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
