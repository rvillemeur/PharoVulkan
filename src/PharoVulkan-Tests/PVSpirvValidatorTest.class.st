"
Tests PVSpirvValidator: the PATH lookup for the spirv-val executable, the verdict it reports for valid and invalid modules, the validation report and its inspector view. The example-kernel tests compile a PVKernelExamples method and ask spirv-val for a verdict; they skip when spirv-val is not installed. Only kernels with an entry point are validated — scalar <gpu> methods compile to SPIR-V functions, and testScalarGpuMethodHasNoEntryPoint pins that.
"
Class {
	#name : 'PVSpirvValidatorTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Compiler',
	#package : 'PharoVulkan-Tests',
	#tag : 'Compiler'
}

{ #category : 'tests' }
PVSpirvValidatorTest >> testBuiltInsFromWordsNamesWhatTheKernelReads [
	"The matmul reads its invocation index and the grid it was dispatched over; the loop
	 kernel reads only the index."

	self
		assert: PVSpirvValidator exampleValidatorOnMatmulKernel builtInsFromWords asSet
		equals: #( 'globalInvocationId' 'numWorkgroups' ) asSet.
	self
		assert: PVSpirvValidator exampleValidatorOnComputeLoopKernel builtInsFromWords asSet
		equals: #( 'globalInvocationId' ) asSet
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testCountOfOpcodeCountsEveryInstructionOfThatOpcode [
	"Counted from the bytes, so the figure is what the module holds rather than what the
	 emitter was asked for. The tiled matmul is the module with barriers in it."

	| validator |
	validator := PVSpirvValidator on: PVTiledMatmulKernel new spirv.
	self assert: (validator countOfOpcode: SpvOpcode opControlBarrier) equals: 2.
	self assert: (validator countOfOpcode: SpvOpcode opLoopMerge) equals: 2.
	self
		assert: (validator countOfOpcode: SpvOpcode opGroupNonUniformFAdd)
		equals: 0
]

{ #category : 'tests - reporting' }
PVSpirvValidatorTest >> testEntryPointReportOnAModuleWithoutAWorkgroup [
	"A vertex shader declares no local size. The report must say so with an empty shape
	 rather than failing or inventing the compute default. It declares no shared tile
	 either, which is the degenerate case for the two tile rows."

	| validator rows |
	validator := PVSpirvValidator on:
		             (PVKernelCompiler compile:
			              PVKernelExamples >> #triVertex:color:).
	self assert: validator localSizeFromWords equals: #( ).
	rows := validator entryPointReport.
	self
		assert: (rows collect: [ :each | each at: #setting ])
		equals: #( 'Local size' 'Invocations per group' 'Built-ins read'
			   'Shared tiles' 'Tiles named by entry point' ).
	self assert: (rows first at: #value) equals: '#()'.
	self assert: ((rows at: 4) at: #value) equals: '0'.
	self assert: ((rows at: 5) at: #value) equals: '0'
]

{ #category : 'tests - compute' }
PVSpirvValidatorTest >> testEveryWorkgroupVariableIsNamedByTheEntryPoint [
	"Under SPIR-V 1.5 the entry point's interface list must name every module-scope
	 variable the entry point touches, Workgroup tiles included. A module that leaves a
	 tile out validates nowhere and is the mistake this reads back. The plain matmul is the
	 degenerate case: no tiles, and the list still names its buffers."

	| shared plain tiles |
	shared := PVSpirvValidator on: (PVKernelCompiler compile:
			           (PVKernelExamples >> #broadcastFirstOf:data:out:tile:)).
	plain := PVSpirvValidator exampleValidatorOnMatmulKernel.
	tiles := shared variableIdsInStorageClass: SpvStorageClass workgroup.
	self assert: tiles size equals: 1.
	self assert: (tiles allSatisfy: [ :id |
			 shared entryPointInterfaceIds includes: id ]).
	self
		assertEmpty: (plain variableIdsInStorageClass: SpvStorageClass workgroup).
	self deny: plain entryPointInterfaceIds isEmpty
]

{ #category : 'tests - report' }
PVSpirvValidatorTest >> testExamplesCoverBothVerdicts [
	"The two one-click examples must stay on opposite sides of the verdict."
	PVSpirvValidator isAvailable ifFalse: [ self skip ].
	self assert: PVSpirvValidator exampleValidatorOnVectorAddKernel isValid.
	self deny: PVSpirvValidator exampleValidatorOnScalarKernel isValid
]

{ #category : 'tests - lookup' }
PVSpirvValidatorTest >> testExecutableInAnswersNilForDegeneratePaths [
	"An unset PATH arrives as an empty string; a PATH may also hold empty entries."
	self assert: (PVSpirvValidator executableIn: '') isNil.
	self assert: (PVSpirvValidator executableIn: '::') isNil
]

{ #category : 'tests - lookup' }
PVSpirvValidatorTest >> testExecutableInAnswersNilWhenNameIsAbsent [
	self withExecutableDirectoryDo: [ :dir |
		self writeExecutableNamed: 'something-else' in: dir.
		self assert: (PVSpirvValidator executableIn: dir fullName) isNil ]
]

{ #category : 'tests - lookup' }
PVSpirvValidatorTest >> testExecutableInFindsExecutableOnPath [
	self withExecutableDirectoryDo: [ :dir |
		| written found |
		written := self writeExecutableNamed: PVSpirvValidator executableName in: dir.
		found := PVSpirvValidator executableIn: dir fullName.
		self assert: found isNotNil description: 'an executable on PATH must be found'.
		self assert: found fullName equals: written fullName ]
]

{ #category : 'tests - lookup' }
PVSpirvValidatorTest >> testExecutableInIgnoresNonExecutableFile [
	"A file of the right name that nobody can run is not the tool."
	self withExecutableDirectoryDo: [ :dir |
		(dir / PVSpirvValidator executableName)
			writeStreamDo: [ :stream | stream nextPutAll: 'not a program' ].
		self assert: (PVSpirvValidator executableIn: dir fullName) isNil ]
]

{ #category : 'tests - lookup' }
PVSpirvValidatorTest >> testExecutableInSearchesEveryPathEntry [
	"A tool in the last entry must be found, not only one in the first."
	self withExecutableDirectoryDo: [ :dir |
		| empty written found |
		empty := (dir / 'empty') ensureCreateDirectory.
		written := self writeExecutableNamed: PVSpirvValidator executableName in: dir.
		found := PVSpirvValidator executableIn: empty fullName , ':' , dir fullName.
		self assert: found isNotNil description: 'later PATH entries must be searched too'.
		self assert: found fullName equals: written fullName ]
]

{ #category : 'tests - validating' }
PVSpirvValidatorTest >> testGarbageBytesAreReportedInvalid [
	"The validator must fail a module, not only run. Four bytes that are not even a
	 header are the cheapest proof that a verdict is really being read back."
	| validator |
	validator := self validatorFor: #[ 1 2 3 4 ].
	self deny: validator isValid.
	self deny: validator validationOutput isEmpty description: 'spirv-val must say why'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testGlslTriFragment [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #glslTriFragment:)) description: 'glslTriFragment:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testGlslTriVertex [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:)) description: 'glslTriVertex:color:'
]

{ #category : 'tests - report' }
PVSpirvValidatorTest >> testInspectorValidationViewLeavesTheInspectedValidatorUntouched [
	| bytes validator view |
	bytes := PVKernelCompiler compile: (PVKernelExamples >> #vectorAdd:a:b:out:).
	validator := self validatorFor: bytes.
	view := validator inspectorValidation: SpPresenter new.
	self assert: (validator instVarNamed: 'exitCode') isNil
		description: 'building the view must not cache a verdict on the inspected object'.
	self assert: view items size equals: (PVSpirvValidator on: bytes) validationReport size
]

{ #category : 'tests - compute' }
PVSpirvValidatorTest >> testLocalIndexKernelValidates [
	"The DSL path to LocalInvocationId. The built-in is created on demand by the kernel
	 body rather than by a parameter, so its decoration and its place in the interface list
	 are the thing at risk."

	self
		validateSpirv:
		(PVKernelCompiler compile: (PVKernelExamples >> #localIndexOf:data:out:))
		description: 'localIndexOf:data:out:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testLocalSizeFromWordsReadsTheDeclaredWorkgroup [
	"Decoded from the module, not asked of the annotation: this is what the driver sees."

	self
		assert: PVSpirvValidator exampleValidatorOnMatmulKernel localSizeFromWords
		equals: #( 16 16 1 ).
	self
		assert: PVSpirvValidator exampleValidatorOnComputeLoopKernel localSizeFromWords
		equals: PVTypeAnnotation defaultLocalSize
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testMatmulF16 [
	"The half matmul mixes both float widths in one module, so spirv-val is what says the
	 OpFConvert operands and the two OpTypeFloat declarations line up."

	self
		validateSpirv:
			(PVKernelCompiler compile:
				 (PVKernelExamples >> #matmulF16:a:b:out:))
		description: 'matmulF16:a:b:out:'
]

{ #category : 'tests - validating' }
PVSpirvValidatorTest >> testScalarGpuMethodHasNoEntryPoint [
	"Pins the documented rule: a <gpu> method whose parameters are all scalars compiles
	 to a SPIR-V function, so spirv-val must refuse it as a standalone module. This is
	 why only the kernels with a WorkItem and the shaders are validated here."
	| validator |
	validator := self validatorFor: (PVKernelCompiler compile: (PVKernelExamples >> #relu:)).
	self deny: validator isValid.
	self assert: (validator validationOutput includesSubstring: 'No OpEntryPoint')
]

{ #category : 'tests - compute' }
PVSpirvValidatorTest >> testSharedBroadcastKernelDeclaresOneWorkgroupVariable [
	"The tile must land in the Workgroup storage class. A tile emitted as Private would
	 validate and would still pass a single-invocation reading of the kernel, while giving
	 every invocation its own copy and silently losing the broadcast."

	| validator |
	validator := PVSpirvValidator on: (PVKernelCompiler compile:
			              (PVKernelExamples >> #broadcastFirstOf:data:out:tile:)).
	self
		assert: (validator variableCountInStorageClass: SpvStorageClass workgroup)
		equals: 1.
	self
		assert: (validator countOfOpcode: SpvOpcode opControlBarrier)
		equals: 1
]

{ #category : 'tests - compute' }
PVSpirvValidatorTest >> testSharedBroadcastKernelValidates [
	"The DSL path to shared memory. A Workgroup variable missing from the entry point's
	 interface list is invalid under SPIR-V 1.5, and spirv-val is what catches it."

	self
		validateSpirv:
		(PVKernelCompiler compile:
			 (PVKernelExamples >> #broadcastFirstOf:data:out:tile:))
		description: 'broadcastFirstOf:data:out:tile:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testSubgroupDotKernelValidates [
	"spirv-val refuses OpGroupNonUniformFAdd unless the module declares GroupNonUniform and
	 GroupNonUniformArithmetic and gives the instruction a Subgroup scope, so the verdict is
	 what states the reduction was encoded the way the specification asks."

	PVSpirvValidator isAvailable ifFalse: [ ^ self skip ].
	self assert: PVSpirvValidator exampleValidatorOnSubgroupDotKernel isValid
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testTriFragment [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #triFragment:)) description: 'triFragment:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testTriVertex [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #triVertex:color:)) description: 'triVertex:color:'
]

{ #category : 'tests - report' }
PVSpirvValidatorTest >> testValidationReportNamesTheToolAndTheVerdict [
	| validator report |
	validator := self validatorFor: (PVKernelCompiler compile: (PVKernelExamples >> #vectorAdd:a:b:out:)).
	report := validator validationReport.
	self assert: (report collect: [ :each | each key ]) asArray
		equals: #( 'executable' 'target environment' 'module bytes' 'exit code' 'verdict' 'output' ).
	self assert: ((report detect: [ :each | each key = 'executable' ]) value endsWith: PVSpirvValidator executableName).
	self assert: (report detect: [ :each | each key = 'verdict' ]) value equals: 'valid'
]

{ #category : 'tests - report' }
PVSpirvValidatorTest >> testValidationReportSaysSoWhenTheToolIsMissing [
	"On a machine without spirv-val the report must state the absence, not a verdict."
	| report |
	report := (PVMissingToolValidatorStub on: #[ 1 2 3 4 ]) validationReport.
	self assert: report size equals: 1.
	self assert: (report first value includesSubstring: 'not found on PATH')
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testVariableCountInStorageClassSeesTheSharedTiles [
	"A shared tile is an OpVariable in the Workgroup storage class. A kernel without tiling
	 has none, which is the degenerate case that makes the count mean something."

	| tiled plain |
	tiled := PVSpirvValidator on: PVTiledMatmulKernel new spirv.
	plain := PVSpirvValidator exampleValidatorOnMatmulKernel.
	self
		assert: (tiled variableCountInStorageClass: SpvStorageClass workgroup)
		equals: PVTiledMatmulKernel tileCount.
	self
		assert: (plain variableCountInStorageClass: SpvStorageClass workgroup)
		equals: 0.
	self
		assert: (tiled variableCountInStorageClass: SpvStorageClass storageBuffer)
		equals: PVTiledMatmulKernel bufferBindings size
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testVectorAdd [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #vectorAdd:a:b:out:)) description: 'vectorAdd:a:b:out:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testVectorAddF16 [
	"Half precision is where a missing capability shows up: spirv-val refuses OpTypeFloat 16
	 in a storage buffer unless the module declares Float16 and StorageBuffer16BitAccess."

	self
		validateSpirv:
			(PVKernelCompiler compile:
				 (PVKernelExamples >> #vectorAddF16:a:b:out:))
		description: 'vectorAddF16:a:b:out:'
]

{ #category : 'private' }
PVSpirvValidatorTest >> validateSpirv: bytes description: aDescription [
	| validator |
	validator := self validatorFor: bytes.
	self
		assert: validator isValid
		description: aDescription , ' produced invalid SPIR-V: ' , validator validationOutput
]

{ #category : 'private' }
PVSpirvValidatorTest >> validatorFor: bytes [
	PVSpirvValidator isAvailable ifFalse: [ self skip ].
	^ PVSpirvValidator on: bytes
]

{ #category : 'private' }
PVSpirvValidatorTest >> withExecutableDirectoryDo: aBlock [
	"The lookup has to be tested against a directory this test controls, never against
	 whatever the machine happens to have installed."
	| dir |
	dir := (FileLocator temp / 'pv-spirv-val-lookup') ensureCreateDirectory.
	^ [ aBlock value: dir ] ensure: [ dir ensureDeleteAll ]
]

{ #category : 'private' }
PVSpirvValidatorTest >> writeExecutableNamed: aName in: aDirectory [
	| file |
	file := aDirectory / aName.
	file writeStreamDo: [ :stream | stream nextPutAll: '#!/bin/sh' ].
	LibC system: 'chmod +x ' , file fullName.
	^ file
]
