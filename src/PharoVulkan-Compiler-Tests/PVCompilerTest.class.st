"
SUnit test suite for the Pharo→SPIR-V compiler pipeline. Covers each stage: bytecode decode, stack simulation, CFG build, SSA construction, type inference, structured-CFG recognition, and SPIR-V emission. All 12 tests must pass.
"
Class {
	#name : 'PVCompilerTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Compiler-Tests-Tests',
	#package : 'PharoVulkan-Compiler-Tests',
	#tag : 'Tests'
}

{ #category : 'dsl surface' }
PVCompilerTest class >> bindingsPackageName [
	^ #'PharoVulkan-Bindings'
]

{ #category : 'dsl surface' }
PVCompilerTest class >> dslExtensionMethods [
	"Every method this project adds to a class it does not own for a selector the compiler maps:
	 the method belongs to one of this project's packages while the class it is installed on does
	 not, which is what makes it an extension."

	^ self mappedDslSelectors gather: [ :selector |
		  (SystemNavigation default allImplementorsOf: selector) select: [ :method |
			  (method package notNil and: [
				   method package name beginsWith: self projectPackageNamePrefix ]) and: [
				  method methodClass instanceSide package
					  ifNil: [ true ]
					  ifNotNil: [ :package |
						  (package name beginsWith: self projectPackageNamePrefix) not ] ] ] ]
]

{ #category : 'dsl surface' }
PVCompilerTest class >> mappedDslSelectors [
	"The selectors PVSelectorTable maps, read out of the table itself so that a mapping added
	 tomorrow is covered. A key is the selector followed by a colon and the receiver type, and no
	 type name contains a colon, so the selector is what comes before the last one."

	^ (PVSelectorTable standard table keys collect: [ :each |
		   (each copyUpToLast: $:) asSymbol ]) asSet
]

{ #category : 'dsl surface' }
PVCompilerTest class >> projectPackageNamePrefix [
	"What every package of this project is called first, so a walk can tell this project's code
	 from the image's own by asking the organiser rather than listing packages."

	^ 'PharoVulkan'
]

{ #category : 'dsl surface' }
PVCompilerTest class >> projectPackagesNamedBy: aMethod [
	"The packages of this project whose classes aMethod names, read from its literals and from
	 the literals of every block inside it, because a reference inside a block is a reference."

	| found deep |
	found := Set new.
	deep := nil.
	deep := [ :compiled |
	        compiled literals do: [ :literal |
		        literal isVariableBinding ifTrue: [
			        literal value isBehavior ifTrue: [
				        literal value instanceSide package ifNotNil: [ :package |
					        (package name beginsWith: self projectPackageNamePrefix) ifTrue: [
						        found add: package name asString ] ] ] ].
		        literal class = CompiledBlock ifTrue: [ deep value: literal ] ] ].
	deep value: aMethod.
	^ found
]

{ #category : 'helpers' }
PVCompilerTest >> arrayStridesIn: bytes [
	"The literal of every ArrayStride decoration in the module. An OpDecorate names its
	 target and its decoration before the literal."

	^ ((self operandsOf: SpvOpcode opDecorate in: bytes) select: [ :each |
		   each second = SpvDecoration arrayStride ]) collect: [ :each |
		  each third ]
]

{ #category : 'private - cfg shapes' }
PVCompilerTest >> assertShapeCompiles: aSelector [
	"A shape the recogniser does represent must emit a SPIR-V module. Checks the magic
	 word against SpvSerializer rather than a literal byte pattern."

	| bytes expectedMagic |
	bytes := PVKernelCompiler compileMethod: (PVCfgShapeFixture >> aSelector).
	self assert: (bytes isKindOf: ByteArray).
	expectedMagic := (1 to: 4) collect: [ :i |
		                 (SpvSerializer spirvMagic bitShift: (i - 1) * -8) bitAnd: 16rFF ].
	self assert: (bytes first: 4) asArray equals: expectedMagic asArray.
	^ bytes
]

{ #category : 'private - cfg shapes' }
PVCompilerTest >> assertShapeRejected: aSelector [
	"Every CFG shape the recogniser cannot represent must be refused outright. A shape
	 that compiles to something is the failure this checks for: the recogniser used to
	 match the head of the graph and discard the rest, which produced a module that was
	 either silently wrong or invalid SPIR-V."

	| raised |
	raised := false.
	[ PVKernelCompiler compileMethod: (PVCfgShapeFixture >> aSelector) ]
		on: PVTypeError
		do: [ :e | raised := true ].
	self
		assert: raised
		description: aSelector , ' compiled instead of raising PVTypeError'
]

{ #category : 'private' }
PVCompilerTest >> assertSpirvMagic: bytes description: aDescription [
	"Derive the expected header from the serialiser instead of repeating the four bytes at
	 every call site, so the assertion cannot disagree with what the serialiser writes."
	| magic expected actual |
	magic := SpvSerializer spirvMagic.
	expected := ByteArray streamContents: [ :stream |
		0 to: 3 do: [ :index | stream nextPut: ((magic bitShift: index * -8) bitAnd: 16rFF) ] ].
	self assert: bytes class equals: ByteArray.
	actual := bytes first: expected size.
	self
		assert: actual = expected
		description: aDescription , ' must start with the SPIR-V magic number, got '
			, actual printString
]

{ #category : 'helpers' }
PVCompilerTest >> builtInDecorationsIn: bytes [
	"Answer the BuiltIn values decorated in a module, so a test can state which built-ins a
	 kernel actually reads rather than trusting the emitter's own bookkeeping."

	| words index found |
	words := (1 to: bytes size by: 4) collect: [ :each |
		         (bytes at: each) + ((bytes at: each + 1) bitShift: 8)
		         + ((bytes at: each + 2) bitShift: 16)
		         + ((bytes at: each + 3) bitShift: 24) ].
	found := OrderedCollection new.
	index := 6.
	[ index <= words size ] whileTrue: [
		| word wordCount opcode |
		word := words at: index.
		wordCount := word bitShift: -16.
		opcode := word bitAnd: 16rFFFF.
		(opcode = SpvOpcode opDecorate and: [
			 (words at: index + 2) = SpvDecoration builtIn ]) ifTrue: [
			found add: (words at: index + 3) ].
		index := index + wordCount ].
	^ found asArray
]

{ #category : 'helpers' }
PVCompilerTest >> capabilitiesIn: bytes [
	"Every capability the module declares, as its numeric value."

	^ (self operandsOf: SpvOpcode opCapability in: bytes) collect: [ :each |
		  each first ]
]

{ #category : 'helpers' }
PVCompilerTest >> codePackagesOfThisProject [
	^ PackageOrganizer default packages select: [ :package |
		(package name beginsWith: self projectPackagePrefix)
			and: [ (package name endsWith: self suffixOfATestPackage) not ] ]
]

{ #category : 'helpers' }
PVCompilerTest >> constantIdOfValue: aValue in: bytes [
	"The result id of the OpConstant holding that value, so a test can state which id an
	 instruction's scope operand must be rather than guessing an id the emitter allocated.
	 An OpConstant carries its result type and result id before the literal."

	^ ((self operandsOf: SpvOpcode opConstant in: bytes) detect: [ :each |
		   each third = aValue ]) second
]

{ #category : 'helpers' }
PVCompilerTest >> executionModeLiteralsIn: bytes [
	"Answer the literal operands of the first OpExecutionMode in a module. The entry point
	 id and the mode itself come first, so the local size starts at the third operand."

	| words index |
	words := (1 to: bytes size by: 4) collect: [ :each |
		         (bytes at: each) + ((bytes at: each + 1) bitShift: 8)
		         + ((bytes at: each + 2) bitShift: 16)
		         + ((bytes at: each + 3) bitShift: 24) ].
	index := 6.
	[ index <= words size ] whileTrue: [
		| word wordCount opcode |
		word := words at: index.
		wordCount := word bitShift: -16.
		opcode := word bitAnd: 16rFFFF.
		opcode = SpvOpcode opExecutionMode ifTrue: [
			^ ((index + 3) to: (index + wordCount - 1)) asArray collect: [ :each |
				  words at: each ] ].
		index := index + wordCount ].
	^ #( )
]

{ #category : 'helpers' }
PVCompilerTest >> extensionsIn: bytes [
	"The names the module's OpExtension instructions carry. A SPIR-V literal string packs
	 four bytes per word and ends at the first zero byte, so the words are unpacked and cut
	 there."

	^ (self operandsOf: SpvOpcode opExtension in: bytes) collect: [ :words |
		  | characters |
		  characters := OrderedCollection new.
		  words do: [ :word |
			  0 to: 3 do: [ :shift |
				  | byte |
				  byte := word bitShift: shift * -8.
				  byte := byte bitAnd: 16rFF.
				  byte = 0 ifFalse: [ characters add: (Character value: byte) ] ] ].
		  String withAll: characters ]
]

{ #category : 'helpers' }
PVCompilerTest >> gpuPragmaPrefix [
	"Every pragma that marks a method as a kernel starts with this: <gpu>, <gpuVertex>, <gpuFragment>."

	^ 'gpu'
]

{ #category : 'helpers' }
PVCompilerTest >> kernelMethodsOfThisProject [
	^ self codePackagesOfThisProject flatCollect: [ :package |
		package methods select: [ :method |
			method pragmas anySatisfy: [ :pragma |
				pragma keyword beginsWith: self gpuPragmaPrefix ] ] ]
]

{ #category : 'private - cfg shapes' }
PVCompilerTest >> opcodeCountsIn: bytes [
	"Decode the instruction stream of a SPIR-V module and count opcodes. A test about
	 control flow has to state a fact about the instructions, because spirv-val cannot see
	 a dropped loop: a straight-line kernel is valid SPIR-V."

	| headerWordCount words counts index |
	headerWordCount := 5.
	words := (1 to: bytes size by: 4) collect: [ :each |
		         (bytes at: each) + ((bytes at: each + 1) bitShift: 8)
		         + ((bytes at: each + 2) bitShift: 16)
		         + ((bytes at: each + 3) bitShift: 24) ].
	counts := Dictionary new.
	index := headerWordCount + 1.
	[ index <= words size ] whileTrue: [
		| word wordCount opcode |
		word := words at: index.
		wordCount := word bitShift: -16.
		opcode := word bitAnd: 16rFFFF.
		self
			assert: wordCount > 0
			description: 'instruction with zero word count at word ' , index printString.
		counts at: opcode put: (counts at: opcode ifAbsent: [ 0 ]) + 1.
		index := index + wordCount ].
	^ counts
]

{ #category : 'helpers' }
PVCompilerTest >> operandsOf: anOpcode in: bytes [
	"The operand words of every instruction carrying that opcode, in module order."

	| words index found headerWordCount |
	headerWordCount := 5.
	words := self wordsIn: bytes.
	found := OrderedCollection new.
	index := headerWordCount + 1.
	[ index <= words size ] whileTrue: [
		| word wordCount |
		word := words at: index.
		wordCount := word bitShift: -16.
		(word bitAnd: 16rFFFF) = anOpcode ifTrue: [
			found add: (((index + 1) to: index + wordCount - 1) asArray collect: [ :each |
					 words at: each ]) ].
		index := index + wordCount ].
	^ found asArray
]

{ #category : 'helpers' }
PVCompilerTest >> projectPackagePrefix [
	^ 'PharoVulkan-'
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> recogniserFor: aSelector [
	^ PVStructuredCFGRecognizer new initialize:
		  (PVCFGBuilder buildBytecodeBlocks:
			   (PVBytecodeDecoder decode: (PVCfgShapeFixture >> aSelector)))
]

{ #category : 'helpers' }
PVCompilerTest >> selectorsNoClassImplementsAmong: aCollectionOfSelectors [
	^ (aCollectionOfSelectors asSet
		reject: [ :selector | (SystemNavigation default allImplementorsOf: selector) notEmpty ])
			asSortedCollection asArray
]

{ #category : 'helpers' }
PVCompilerTest >> suffixOfATestPackage [
	^ '-Tests'
]

{ #category : 'tests - dispatch' }
PVCompilerTest >> testAMappingAnswersTheEmitterSelectorOfItsOwnOperation [
	"A mapping knows how it is emitted: that is what moved out of the emitter. An operation
	 whose emitter needs the result type as well answers a selector of three keywords, and the
	 mapping is the only object that can fill that argument."

	self
		assert: (PVSelectorMapping spirvOp: #workItemY resultType: #u32)
				emitterSelector
		equals: #emitWorkItemY:block:.
	self
		assert: (PVSelectorMapping spirvOp: #glslSqrt resultType: #f32)
				emitterSelector
		equals: #emitGlslSqrt:block:.
	self
		assert: (PVSelectorMapping spirvOp: #coopMatrixLoad resultType: #coopMatA)
				emitterSelector numArgs
		equals: 3.
	self
		assert: (PVSelectorMapping spirvOp: #OpFAdd resultType: #f32) emitterSelector
		equals: nil
]

{ #category : 'tests - block simulation' }
PVCompilerTest >> testASimulatedBlockNamesItsFiveParts [
	| node sim |
	node := PVCompilerExamples selectionOfAClampKernel.
	sim := PVBlockSimulator new
		       simulateBlock: node condBlock
		       initialTempDefs: Dictionary new
		       startingNextReg: 1.
	self assert: sim regOps isArray.
	self assert: sim tempDefs isDictionary.
	self assert: sim resultReg isNumber.
	self assert: sim nextReg > 1.
	self assert: sim stack isCollection
]

{ #category : 'tests' }
PVCompilerTest >> testAlphaClipFragmentCompiles [
	| bytes |
	bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #alphaClip:threshold:).
	self assertSpirvMagic: bytes description: 'alphaClip:threshold:'
]

{ #category : 'tests - dispatch' }
PVCompilerTest >> testAnOpcodeNoEmitterKnowsEmitsNothing [
	"The degenerate state: a register op carrying an opcode the table does not name must leave
	 the block it was given untouched rather than raise. #self is such an opcode today, and a
	 stage that invents a new one must not break a kernel that never reaches it."

	| emitter block |
	emitter := PVSPIRVEmitter new.
	block := SpvBlock new id: 1; yourself.
	#( #self #thisOpcodeExistsNowhere ) do: [ :opcode |
		emitter
			emitRegOp: (PVRegisterOp
					 pc: 0
					 opcode: opcode
					 result: 1
					 inputs: #(  )
					 literal: nil)
			block: block.
		self assert: block instructions isEmpty.
		self assert: block terminator isNil ]
]

{ #category : 'tests' }
PVCompilerTest >> testArrayStrideFollowsTheBufferElementWidth [
	"The stride decoration of a runtime array must match the element width rather than a
	 constant: a half array packs two bytes per element where a float array packs four."

	self
		assert: (PVSPIRVEmitter storageBufferArrayStrideFor: #bufferOf_f16)
		equals: 2.
	self
		assert: (PVSPIRVEmitter storageBufferArrayStrideFor: #bufferOf_f32)
		equals: 4.
	self
		assert: (PVSPIRVEmitter storageBufferArrayStrideFor: #bufferOf_i32)
		equals: 4
]

{ #category : 'tests' }
PVCompilerTest >> testBytecodeBlockBuilderSplits [
	| m ops blocks |
	m := (Smalltalk at: #PVKernelExamples) >> #relu:.
	ops := PVBytecodeDecoder decode: m.
	blocks := PVCFGBuilder buildBytecodeBlocks: ops.
	self assert: blocks size equals: 4.
	self assert: blocks first terminator opcode equals: #jumpIf.
	self assert: blocks first successors size equals: 2
]

{ #category : 'tests' }
PVCompilerTest >> testCapabilitiesDeclaredForEachBufferType [
	"What the Buffer types tab shows must be what an emitted module carries, so the answer
	 comes from the emitter's own declaration step."

	self
		assert:
			(PVSPIRVEmitter capabilitiesDeclaredFor: #bufferOf_f16) asArray
		equals: {
			PVSPIRVEmitter float16Capability.
			PVSPIRVEmitter storageBuffer16BitAccessCapability }.
	self assert: (PVSPIRVEmitter capabilitiesDeclaredFor: #bufferOf_f32) isEmpty.
	self assert: (PVSPIRVEmitter capabilitiesDeclaredFor: #bufferOf_i32) isEmpty
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeLoopThenSelectionRejected [
	"Emitted OpReturnValue with a bool from a function declared to return an int before
	 the coverage check existed; spirv-val rejected the module."

	self assertShapeRejected: #loopThenSelection:
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeNestedLoopsRecognised [
	"The one nesting shape the recogniser matches: an outer loop whose body is an inner
	 loop. The node must account for every block, because the coverage check is what stops
	 a partly matched graph compiling to its head alone."

	| blocks node |
	blocks := PVCFGBuilder buildBytecodeBlocks:
		          (PVBytecodeDecoder decode:
			           (PVCfgShapeFixture >> #computeNestedLoops:data:out:)).
	node := PVStructuredCFGRecognizer recognizeFrom: blocks.
	self assert: node class equals: PVNestedLoopNode.
	self
		assert: (IdentitySet newFrom: node coveredBlocks) size
		equals: blocks size.
	self assert: node preheaderBlock identicalTo: blocks first.
	self assert: node headerBlock identicalTo: (blocks at: 2).
	self assert: node innerPreheaderBlock identicalTo: (blocks at: 3).
	self assert: node innerHeaderBlock identicalTo: (blocks at: 4).
	self assert: node innerBodyBlocks asArray equals: { (blocks at: 5) }.
	self assert: node innerMergeBlock identicalTo: (blocks at: 6).
	self assert: node exitBlock identicalTo: (blocks at: 7)
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeNestedLoopsRejected [
	"The recogniser matches nested loops, but only the compute path emits them: a scalar
	 <gpu> method of that shape must still be refused outright rather than compiled to the
	 outer loop alone."

	self assertShapeRejected: #nestedLoops:
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeNestedSelectionRejected [
	self assertShapeRejected: #nestedSelection:
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeOneLoopCompiles [
	self assertShapeCompiles: #oneLoop:
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeOneSelectionCompiles [
	self assertShapeCompiles: #oneSelection:
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeSelectionInLoopRejected [
	self assertShapeRejected: #selectionInLoop:
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeTwoSequentialSelectionsRejected [
	"Compiled to a module byte-identical to the single-selection one before the
	 coverage check existed: the second selection was silently dropped."

	self assertShapeRejected: #twoSequentialSelections:
]

{ #category : 'tests' }
PVCompilerTest >> testClampCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #clampF32:lo:hi:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testClampCompiles'
]

{ #category : 'tests - compiler' }
PVCompilerTest >> testCompilerAsksTheNodeToEmitInsteadOfTestingItsClass [
	"The target methods used isKindOf: to choose an emitter entry point, which means every
	 new node shape has to be added to four cascades. The node knows its own shape."

	| typeTests |
	typeTests := (PVKernelCompiler methods , PVKernelCompiler class methods) select: [ :each |
		             each ast allChildren anySatisfy: [ :node |
			             node isMessage and: [ node selector = #isKindOf: ] ] ].
	self
		assertEmpty:
		(typeTests collect: [ :each | each selector ]) asSortedCollection asArray
]

{ #category : 'tests - compute control flow' }
PVCompilerTest >> testComputeLoopKernelEmitsOneLoopMerge [
	"A whileTrue: in a compute kernel must become a real SPIR-V loop. The compute path
	 used to return before the recogniser ran, so the body was emitted once into a single
	 basic block and spirv-val still passed the module."

	| counts |
	counts := self opcodeCountsIn: (PVKernelCompiler compileMethod: (PVCfgShapeFixture >> #computeLoopSum:data:out:)).
	self
		assert: (counts at: SpvOpcode opLoopMerge ifAbsent: [ 0 ])
		equals: 1.
	self
		assert: (counts at: SpvOpcode opBranchConditional ifAbsent: [ 0 ])
		equals: 1.
	self
		assert: (counts at: SpvOpcode opPhi ifAbsent: [ 0 ]) > 0
		description: 'a loop carrying a counter and an accumulator needs phi nodes'
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testComputeNestedLoopsCompiles [
	"The compute path emits the nested shape. Both loop merges and both back edges have to
	 be there: a module holding one OpLoopMerge would be the outer loop with its body
	 inlined once, which is the silent wrongness the recogniser used to refuse instead."

	| validator |
	validator := PVSpirvValidator on: (PVKernelCompiler compileMethod:
			              (PVCfgShapeFixture >> #computeNestedLoops:data:out:)).
	self
		assert: (validator countOfOpcode: SpvOpcode opLoopMerge)
		equals: 2.
	self
		assert: (validator countOfOpcode: SpvOpcode opBranchConditional)
		equals: 2.
	self assert: validator isValid description: validator validationReport
]

{ #category : 'tests - compute control flow' }
PVCompilerTest >> testComputeSelectionKernelEmitsSelectionMerge [
	"An ifTrue:ifFalse: in a compute kernel must become a real SPIR-V selection. This
	 raised PVTypeError: No mapping for at:put: before the compute path ran the
	 recogniser."

	| counts |
	counts := self opcodeCountsIn: (PVKernelCompiler compileMethod: (PVCfgShapeFixture >> #computeSelectionClamp:data:out:)).
	self
		assert: (counts at: SpvOpcode opSelectionMerge ifAbsent: [ 0 ])
		equals: 1.
	self
		assert: (counts at: SpvOpcode opBranchConditional ifAbsent: [ 0 ])
		equals: 1.
	self
		assert: (counts at: SpvOpcode opPhi ifAbsent: [ 0 ])
		equals: 1
]

{ #category : 'tests - compute control flow' }
PVCompilerTest >> testComputeSequentialSelectionsRejected [
	"Sequence is refused as firmly as nesting: one construct per method, on the compute
	 path too."

	self assertShapeRejected: #computeTwoSequentialSelections:data:out:
]

{ #category : 'tests - cooperative matrix' }
PVCompilerTest >> testCooperativeMatrixKernelCompilesFromPharoSource [
	"The DSL route to the module PVCooperativeMatrixKernel builds by hand: three
	 cooperative matrix types, one load per factor of the product and one mul-add. The
	 accumulator is a zero matrix rather than a third load, so there are two loads where
	 the hand-built kernel has three."

	| counts bytes |
	bytes := PVKernelCompiler new
		         method: PVKernelExamples >> #coopMatrixProductOf:by:into:;
		         compile.
	counts := self opcodeCountsIn: bytes.
	self
		assert: (counts at: SpvOpcode opTypeCooperativeMatrixKHR ifAbsent: [ 0 ])
		equals: PVCooperativeMatrixKernel matrixOperandCount.
	self
		assert: (counts at: SpvOpcode opCooperativeMatrixLoadKHR ifAbsent: [ 0 ])
		equals: 2.
	self
		assert: (counts at: SpvOpcode opCooperativeMatrixMulAddKHR ifAbsent: [ 0 ])
		equals: 1.
	self
		assert: (counts at: SpvOpcode opCooperativeMatrixStoreKHR ifAbsent: [ 0 ])
		equals: 1
]

{ #category : 'tests - cooperative matrix' }
PVCompilerTest >> testCooperativeMatrixModuleDeclaresWhatTheCapabilityRequires [
	"A cooperative matrix module is only legal with three declarations together: the
	 CooperativeMatrixKHR capability, the SPV_KHR_cooperative_matrix extension, and the
	 VulkanMemoryModel capability with the Vulkan memory model. spirv-val refuses Shader plus
	 CooperativeMatrixKHR without the last of them, so the three are asserted as one fact."

	| bytes capabilities |
	bytes := PVCooperativeMatrixKernel new spirv.
	capabilities := self capabilitiesIn: bytes.
	self assert:
		(capabilities includes: PVSPIRVEmitter cooperativeMatrixCapability).
	self assert:
		(capabilities includes: PVSPIRVEmitter vulkanMemoryModelCapability).
	self assert: ((self extensionsIn: bytes) includes:
			 PVSPIRVEmitter cooperativeMatrixExtensionName).
	self
		assert: (self operandsOf: SpvOpcode opMemoryModel in: bytes) first
		equals: {
				SpvModule logicalAddressingModel.
				SpvModule vulkanMemoryModel }
]

{ #category : 'tests - cooperative matrix' }
PVCompilerTest >> testCooperativeMatrixModuleHasOneTypePerOperandAndOneMulAdd [
	"The three matrix types are distinct: A, B and the accumulator differ in their Use
	 operand even where the component type is the same, and a kernel cannot reuse one for
	 another. One load per operand, one multiply-accumulate, one store."

	| counts bytes |
	bytes := PVCooperativeMatrixKernel new spirv.
	counts := self opcodeCountsIn: bytes.
	self
		assert: (counts at: SpvOpcode opTypeCooperativeMatrixKHR ifAbsent: [ 0 ])
		equals: PVCooperativeMatrixKernel matrixOperandCount.
	self
		assert: (counts at: SpvOpcode opCooperativeMatrixLoadKHR ifAbsent: [ 0 ])
		equals: PVCooperativeMatrixKernel matrixOperandCount.
	self
		assert: (counts at: SpvOpcode opCooperativeMatrixMulAddKHR ifAbsent: [ 0 ])
		equals: 1.
	self
		assert: (counts at: SpvOpcode opCooperativeMatrixStoreKHR ifAbsent: [ 0 ])
		equals: 1
]

{ #category : 'tests - cooperative matrix' }
PVCompilerTest >> testCooperativeMatrixOrderHasOneHomeBelowBothReaders [
	"The shape a cooperative matrix kernel names must be one the device reports, so the hand-built
	 kernel and a compiled one have to agree on it. The value therefore lives on the SPIR-V shape
	 class, below both of them, and neither the emitter nor the kernel may hold a second copy: the
	 emitter used to read it out of PVCooperativeMatrixKernel, which made the compiler depend on
	 the compute package for a number."

	self
		assert: PVSPIRVEmitter cooperativeMatrixOrder
		equals: SpvCooperativeMatrixShape canonicalOrder.
	self
		assert: PVCooperativeMatrixKernel matrixOrder
		equals: SpvCooperativeMatrixShape canonicalOrder
]

{ #category : 'tests' }
PVCompilerTest >> testDecoderHandlesInstVarAndDup [
| ops opcodes |
ops := PVBytecodeDecoder new.
ops initialize.
ops doDup.
ops pushReceiverVariable: 0.
ops popIntoReceiverVariable: 1.
opcodes := ops ops collect: [:o | o opcode].
self assert: (opcodes includes: #dup).
self assert: (opcodes includes: #pushInstVar).
self assert: (opcodes includes: #popInstVar)
]

{ #category : 'tests' }
PVCompilerTest >> testDecoderProducesOps [
	| m ops |
	m := (Smalltalk at: #PVKernelExamples) >> #addFloat:to:.
	ops := PVBytecodeDecoder decode: m.
	self deny: ops isEmpty.
	self assert: (ops anySatisfy: [ :op | op opcode = #send ]).
	self assert: (ops anySatisfy: [ :op | op opcode = #returnTop ])
]

{ #category : 'tests' }
PVCompilerTest >> testDecodesJumps [
	| m ops jumpIf |
	m := (Smalltalk at: #PVKernelExamples) >> #relu:.
	ops := PVBytecodeDecoder decode: m.
	self assert: (ops anySatisfy: [ :op | op opcode = #jumpIf ]).
	self assert: (ops anySatisfy: [ :op | op opcode = #jump ]).
	jumpIf := ops detect: [ :op | op opcode = #jumpIf ].
	self assert: (jumpIf operands first > 0)
]

{ #category : 'tests' }
PVCompilerTest >> testDefaultLocalSizeWhenPragmaAbsent [
	"A kernel without a <localSize:> keeps the one-dimensional default, so every kernel
	 written before the pragma existed still dispatches the same way."

	| literals |
	literals := self executionModeLiteralsIn:
		            (PVKernelCompiler compileMethod:
			             PVKernelExamples >> #vectorAdd:a:b:out:).
	self assert: literals equals: PVTypeAnnotation defaultLocalSize
]

{ #category : 'tests - dispatch' }
PVCompilerTest >> testEmitRegOpNamesNoOpcodeOfItsOwn [
	"The dispatcher looks its branch up and sends it. A comparison against an opcode symbol
	 written inside it would be a branch the table does not know about, which is the shape this
	 refactoring removed, so the method is held to naming no opcode at all."

	| method |
	method := PVSPIRVEmitter >> #emitRegOp:block:.
	PVSPIRVEmitter regOpEmitters keysDo: [ :opcode |
		self
			deny: (method literals includes: opcode)
			description: opcode printString , ' is tested inside the dispatcher' ].
	self assert: (method messages includes: #regOpEmitters)
]

{ #category : 'tests - dispatch' }
PVCompilerTest >> testEmitSendNamesNoSpirvOperationOfItsOwn [
	"The send branch asks the mapping which method emits it. A comparison against a spirvOp
	 symbol written inside it would be a branch no table knows about, which is the shape this
	 refactoring removed."

	| method |
	method := PVSPIRVEmitter >> #emitSend:block:.
	PVSelectorTable standard table valuesDo: [ :mapping |
		self
			deny: (method literals includes: mapping spirvOp)
			description: mapping spirvOp printString
				, ' is tested inside the send branch' ].
	self assert: (method messages includes: #emitOn:op:block:)
]

{ #category : 'tests - nodes' }
PVCompilerTest >> testEveryHookTheStructuredNodesShareIsDeclaredByTheirSuperclass [
	"A reader writing a fourth structured node finds what to implement on PVStructuredNode. A
	 selector every subclass implements while the superclass declares none is a hook nobody
	 announced, which is what Renraku reports and what this holds to: the set is read from the
	 classes themselves, so a hook added to the three later is covered the moment it is written."

	| shared |
	shared := PVStructuredNode subclasses
		          inject: PVStructuredNode subclasses first selectors asSet
		          into: [ :all :each | all intersection: each selectors asSet ].
	shared := shared reject: [ :each |
		          PVStructuredNode includesSelector: each ].
	self
		assert: shared isEmpty
		description: 'these hooks the nodes share are declared by none: '
			, shared asSortedCollection asArray printString.
	self assert:
		((PVStructuredNode >> #simulationsWith:selectorTable:) messages includes:
			 #subclassResponsibility)
]

{ #category : 'tests - dsl surface' }
PVCompilerTest >> testEveryMappedSelectorThisProjectAddsToABaseClassStaysInsideItsOwnLayer [
	"The selector table is the DSL surface: a kernel writes clamp:to: or coopMatLoad:, and the
	 compiler maps the send to a SPIR-V operation. Where this project also implements one of those
	 selectors on a class it does not own, the method is the host twin of the mapping, and it is
	 subject to the same layering as the rest of the project: it may not sit in the bindings,
	 which are the bottom layer and may name nothing above themselves, and it may only name
	 classes of the package it sits in. Before the split these methods sat in the one package and
	 neither question could be asked; the unit 8 rename answered the first one wrongly by default,
	 putting all six in PharoVulkan-Bindings, two of them naming classes of Core and Compute."

	| strays |
	strays := OrderedCollection new.
	self class dslExtensionMethods do: [ :method |
		| home named |
		home := method package name asString.
		named := self class projectPackagesNamedBy: method.
		home = self class bindingsPackageName asString ifTrue: [
			strays add: method methodClass name , ' >> ' , method selector
				, ' sits in the bindings' ].
		(named reject: [ :each | each = home ]) do: [ :each |
			strays add: method methodClass name , ' >> ' , method selector , ' sits in ' , home
				, ' and names ' , each ] ].
	self assertEmpty: strays
]

{ #category : 'tests - dispatch' }
PVCompilerTest >> testEveryRegisterOpcodeTheEmitterHandlesHasItsOwnMethod [
	"The register opcodes are dispatched through a table rather than tested one by one, so the
	 table is what has to be complete: every opcode a simulation can produce names a selector
	 the emitter really implements. An opcode absent from the table emits nothing, which is
	 what #self has always done."

	| table |
	table := PVSPIRVEmitter regOpEmitters.
	self
		assertCollection: table keys asSortedCollection asArray
		equals: #( #const #move #return #returnSelf #send #storeInstVar )
				  asSortedCollection asArray.
	table valuesDo: [ :selector |
		self
			assert: (PVSPIRVEmitter includesSelector: selector)
			description: selector printString , ' is named by the table and not implemented'.
		self assert: selector numArgs equals: 2 ].
	self deny: (table includesKey: #self)
]

{ #category : 'tests - dsl selectors' }
PVCompilerTest >> testEverySelectorAKernelOfThisProjectSendsIsImplemented [
	| kernels orphans |
	kernels := self kernelMethodsOfThisProject.
	self deny: kernels isEmpty.
	orphans := self selectorsNoClassImplementsAmong:
		(kernels flatCollect: [ :each | each messages ]).
	self
		assert: orphans isEmpty
		description: 'sent by a kernel of this project, implemented by no class: '
			, orphans printString
]

{ #category : 'tests - dispatch' }
PVCompilerTest >> testEverySpirvOperationOfTheStandardTableIsEmittable [
	"Each mapping of the dispatch table either names a method of the emitter or compiles to a
	 plain SPIR-V opcode of its own name. A third case would be a send the emitter accepts and
	 then cannot emit, which is a type error discovered at serialisation instead of here."

	PVSelectorTable standard table valuesDo: [ :mapping |
		| selector |
		selector := mapping emitterSelector.
		selector
			ifNil: [
				self
					assert: (SpvOpcode class includesSelector:
							 mapping spirvOp asString uncapitalized asSymbol)
					description: mapping spirvOp printString
						, ' names neither an emitter method nor an opcode' ]
			ifNotNil: [
				self
					assert: (PVSPIRVEmitter includesSelector: selector)
					description: selector printString
						, ' is named by a mapping and not implemented'.
				self assert: (selector numArgs between: 2 and: 3) ] ]
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testExampleRecogniserOnLoopKernelIsRecognised [

	| recogniser |
	recogniser := PVCompilerExamples recogniserOnLoopKernel.
	self assert: (recogniser recognize isKindOf: PVLoopNode).
	self assert: (recogniser recognitionReport allSatisfy: [ :each | each value ])
]

{ #category : 'tests' }
PVCompilerTest >> testFragmentShaderCompiles [
    | bytes |
    bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #triFragment:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assertSpirvMagic: bytes description: 'testFragmentShaderCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testGlslTriFragmentCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #glslTriFragment:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testGlslTriFragmentCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testGlslTriVertexCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #glslTriVertex:color:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testGlslTriVertexCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testGridWidthEmitsNumWorkgroupsBuiltIn [
	"wi gridWidth has to read the NumWorkgroups built-in. Nothing else in the kernel's
	 interface can tell it how many groups were dispatched."

	| builtIns |
	builtIns := self builtInDecorationsIn:
		            (PVKernelCompiler compileMethod:
			             PVKernelExamples >> #sumFirstGridWidth:data:out:).
	self assert: (builtIns includes: SpvBuiltIn numWorkgroups).
	self assert: (builtIns includes: SpvBuiltIn globalInvocationId)
]

{ #category : 'tests' }
PVCompilerTest >> testHalfKernelDeclaresTheHalfPrecisionCapabilities [
	"A module holding 16-bit floats in a storage buffer must say so: without Float16 and
	 StorageBuffer16BitAccess the driver refuses the shader. A float kernel must not pay
	 for capabilities it does not use."

	| half float |
	half := self capabilitiesIn:
		        (PVKernelCompiler compileMethod:
			         (PVKernelExamples >> #vectorAddF16:a:b:out:)).
	float := self capabilitiesIn:
		         (PVKernelCompiler compileMethod:
			          (PVKernelExamples >> #vectorAdd:a:b:out:)).
	self assert: (half includes: PVSPIRVEmitter float16Capability).
	self assert:
		(half includes: PVSPIRVEmitter storageBuffer16BitAccessCapability).
	self deny: (float includes: PVSPIRVEmitter float16Capability).
	self deny:
		(float includes: PVSPIRVEmitter storageBuffer16BitAccessCapability)
]

{ #category : 'tests' }
PVCompilerTest >> testHalfKernelDecoratesItsArraysWithATwoByteStride [
	"Read out of the emitted module rather than off the constant: the stride the driver
	 sees is the one in the decoration."

	| half float |
	half := self arrayStridesIn:
		        (PVKernelCompiler compileMethod:
			         (PVKernelExamples >> #vectorAddF16:a:b:out:)).
	float := self arrayStridesIn:
		         (PVKernelCompiler compileMethod:
			          (PVKernelExamples >> #vectorAdd:a:b:out:)).
	self deny: half isEmpty.
	self assert: half asSet asArray equals: #( 2 ).
	self assert: float asSet asArray equals: #( 4 )
]

{ #category : 'tests' }
PVCompilerTest >> testHalfKernelLoadsAndStoresHalvesOnly [
	"The three places the element type is decided — the buffer declaration, the load and
	 the store — must agree, so the module may declare one float width only."

	| widths |
	widths := (self operandsOf: SpvOpcode opTypeFloat in: (PVKernelCompiler
			            compileMethod: (PVKernelExamples >> #vectorAddF16:a:b:out:)))
		          collect: [ :each | each second ].
	self assert: widths asArray equals: #( 16 )
]

{ #category : 'tests' }
PVCompilerTest >> testHalfMatmulAccumulatesInSinglePrecision [
	"Half storage with float arithmetic: a 512-term sum accumulated in half loses far more
	 than the format's own rounding, so the module must declare both widths and convert
	 between them."

	| bytes widths |
	bytes := PVKernelCompiler compileMethod:
		         (PVKernelExamples >> #matmulF16:a:b:out:).
	widths := (self operandsOf: SpvOpcode opTypeFloat in: bytes) collect: [
		          :each | each second ].
	self assert: widths asSortedCollection asArray equals: #( 16 32 ).
	self deny: (self operandsOf: SpvOpcode opFConvert in: bytes) isEmpty
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testInspectorRecognitionViewBuildsARowPerBlock [

	| recogniser view |
	recogniser := self recogniserFor: #oneLoop:.
	view := recogniser inspectorRecognition: SpPresenter new.
	self assert: view items size equals: recogniser blocks size
]

{ #category : 'tests - type errors' }
PVCompilerTest >> testKernelWhoseTypesCannotBeInferredIsRefused [
	"Inference raising PVTypeError means the compiler does not know what the kernel computes.
	 Emitting a module from the partial type map produces SPIR-V that is either invalid or
	 silently wrong on the device, so the compile must be refused here instead."

	self
		should: [
			PVKernelCompiler compileMethod:
				(PVUninferableTypeFixture >> #sendsASelectorWithNoSpirvMapping:) ]
		raise: PVTypeError
]

{ #category : 'tests - type errors' }
PVCompilerTest >> testKernelWithAParameterNoPragmaDeclaresIsRefusedByName [
	"The inferencer knows exactly what is wrong — a register it cannot type — and says so.
	 Discarding that error and emitting from the partial type map hands the user a
	 KeyNotFound from inside the emitter instead of the reason the kernel was refused."

	| raised |
	raised := nil.
	[ PVKernelCompiler compileMethod:
		  (PVUninferableTypeFixture >> #usesAParameterNoPragmaDeclares:data:out:scale:) ]
		on: Error
		do: [ :e | raised := e ].
	self assert: raised class equals: PVTypeError.
	self assert: (raised messageText includesSubstring: 'infer')
]

{ #category : 'tests' }
PVCompilerTest >> testLocalSizePragmaReachesExecutionMode [
	"A kernel's workgroup shape belongs to the kernel, not to the emitter. A 2-D matmul
	 wants 16 by 16; the emitter must take the numbers from the pragma."

	| literals |
	literals := self executionModeLiteralsIn:
		            (PVKernelCompiler compileMethod:
			             PVKernelExamples >> #taggedLocalSizeAdd:data:out:).
	self assert: literals equals: #( 8 4 2 )
]

{ #category : 'tests' }
PVCompilerTest >> testLoopKernelCompiles [

	| bytes |
	bytes := PVKernelCompiler compileMethod:
		         PVKernelExamples >> #accumulateUpTo:.
	self assertSpirvMagic: bytes description: 'testLoopKernelCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testMat4MulCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #mat4Mul:vec:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testMat4MulCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testMatmulKernelEmitsOneLoopAndA2DLocalSize [
	"The matmul baseline is the first kernel that needs both of 7-C's pieces at once: a
	 two-dimensional workgroup from the pragma, and a k loop that survives compilation."

	| bytes counts |
	bytes := PVKernelCompiler compileMethod: PVKernelExamples >> #matmulF32:a:b:out:.
	counts := self opcodeCountsIn: bytes.
	self assert: (counts at: SpvOpcode opLoopMerge ifAbsent: [ 0 ]) equals: 1.
	self assert: (self executionModeLiteralsIn: bytes) equals: #( 16 16 1 ).
	self assert: (self builtInDecorationsIn: bytes) asSet equals: {
			SpvBuiltIn globalInvocationId.
			SpvBuiltIn numWorkgroups } asSet
]

{ #category : 'tests' }
PVCompilerTest >> testMatmulKernelOfEachElementTypeUsesBuffersOfThatType [
	"Callers that work in either precision name the precision and get the kernel. The
	 buffer types come out of the kernel's own pragmas, so a kernel filed under the wrong
	 element type fails here rather than on the device."

	PVKernelExamples matmulKernels keysDo: [ :each |
		| params expected |
		expected := ('bufferOf_' , each) asSymbol.
		params := (PVTypeAnnotation fromMethod:
			           (PVKernelExamples matmulFor: each)) params.
		self assert: params first type equals: #workItem.
		(params allButFirst collect: [ :one | one type ]) do: [ :one |
			self assert: one equals: expected ] ].
	self
		should: [ PVKernelExamples matmulFor: #f64 ]
		raise: PVTypeError
]

{ #category : 'tests-cfg' }
PVCompilerTest >> testNestedLoopNodeRolesReadEverySlotWithoutMovingAnything [
	"The Roles view reflects over the node's slots, so a role added to the class appears
	 without the view changing, and reading it leaves the recognised graph as it was."

	| node idsBefore rows roles |
	node := PVCompilerExamples nestedLoopOfTheTiledMatmul.
	idsBefore := node coveredBlocks collect: [ :each | each id ].
	rows := node roleRows.
	roles := rows collect: [ :each | each at: #role ].
	self assert: rows size equals: node coveredBlocks size.
	PVNestedLoopNode slotNames do: [ :slotName |
		self
			assert: (roles anySatisfy: [ :each | each beginsWith: slotName ])
			description: slotName ].
	self
		assert: (node coveredBlocks collect: [ :each | each id ])
		equals: idsBefore
]

{ #category : 'tests - compiler' }
PVCompilerTest >> testNodeShapeWithNoEmitterBehindItIsRefusedByName [
	"Pinned across the move to polymorphic dispatch: a nested loop has a compute emitter and
	 no plain-kernel one, and the refusal has to name the shape that was recognised."

	| raised |
	raised := [ PVKernelCompiler compileMethod: (PVCfgShapeFixture >> #nestedLoops:) ]
		          on: PVTypeError
		          do: [ :error | error ].
	self assert: raised class equals: PVTypeError.
	self assert: (raised messageText includesSubstring: 'PVNestedLoopNode')
]

{ #category : 'tests' }
PVCompilerTest >> testNormalizeCompiles [
    | bytes |
    bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #normalizeV:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assertSpirvMagic: bytes description: 'testNormalizeCompiles'
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testRecognitionReportCoversEveryBlockOfARecognisedShape [

	| report |
	report := (self recogniserFor: #oneLoop:) recognitionReport.
	self assert: report size equals: 4.
	self
		assert: (report allSatisfy: [ :each | each value ])
		description: 'a recognised node must account for every block'
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testRecognitionReportCoversNothingWhenShapeIsRefused [
	"Two sequential selections match the recogniser pattern at the head of the graph.
	 Covering only part of it is what used to be accepted, so the report must show the
	 refusal as no coverage at all rather than as a partial match."

	| recogniser report |
	recogniser := self recogniserFor: #twoSequentialSelections:.
	report := recogniser recognitionReport.
	self assert: recogniser recognize isNil.
	self assert: report size equals: recogniser blocks size.
	self assert: (report noneSatisfy: [ :each | each value ])
]

{ #category : 'tests' }
PVCompilerTest >> testRecognizesLoop [

	| method ops blocks node |
	method := PVKernelExamples >> #accumulateUpTo:.
	ops := PVBytecodeDecoder decode: method.
	blocks := PVCFGBuilder buildBytecodeBlocks: ops.
	node := PVStructuredCFGRecognizer recognizeFrom: blocks.
	self assert: (node isKindOf: PVLoopNode).
	self assert: node bodyBlocks size equals: 1.
	self assert: node exitBlock notNil
]

{ #category : 'tests' }
PVCompilerTest >> testRecognizesSelection [
	| m ops blocks node |
	m := (Smalltalk at: #PVKernelExamples) >> #relu:.
	ops := PVBytecodeDecoder decode: m.
	blocks := PVCFGBuilder buildBytecodeBlocks: ops.
	node := PVStructuredCFGRecognizer recognizeFrom: blocks.
	self assert: (node isKindOf: PVSelectionNode).
	self assert: node trueBlocks size equals: 1.
	self assert: node falseBlocks size equals: 1
]

{ #category : 'tests' }
PVCompilerTest >> testSelectionKernelCompiles [
	| m bytes |
	m := (Smalltalk at: #PVKernelExamples) >> #relu:.
	bytes := PVKernelCompiler compileMethod: m.
	self assert: bytes class equals: ByteArray.
	self deny: bytes isEmpty.
	self assert: (bytes at: 1) equals: 3.
	self assert: (bytes at: 2) equals: 2.
	self assert: (bytes at: 3) equals: 35.
	self assert: (bytes at: 4) equals: 7
]

{ #category : 'tests' }
PVCompilerTest >> testSelectorTableComputeMappings [
| st |
st := PVSelectorTable standard.
self assert: (st at: 'x' receiverType: #workItem) spirvOp equals: #workItemX.
self assert: (st at: 'y' receiverType: #workItem) spirvOp equals: #workItemY.
self assert: (st at: 'z' receiverType: #workItem) spirvOp equals: #workItemZ.
self assert: (st at: 'at:' receiverType: #bufferOf_f32) spirvOp equals: #bufferLoad.
self assert: (st at: 'at:put:' receiverType: #bufferOf_f32) spirvOp equals: #bufferStore.
self assert: (st at: 'at:' receiverType: #bufferOf_i32) spirvOp equals: #bufferLoad.
self assert: (st at: 'at:put:' receiverType: #bufferOf_i32) spirvOp equals: #bufferStore
]

{ #category : 'tests' }
PVCompilerTest >> testSelectorTableMapsConversionsBetweenHalfAndFloat [
	"Both directions, because a kernel that stores halves and accumulates in float needs
	 one conversion on the way in and one on the way out."

	| st |
	st := PVSelectorTable standard.
	self assert: (st at: 'asF32' receiverType: #f16) spirvOp equals: #OpFConvert.
	self
		assert: (st at: 'asF32' receiverType: #f16) resultTypeSymbol
		equals: #f32.
	self assert: (st at: 'asF16' receiverType: #f32) spirvOp equals: #OpFConvert.
	self
		assert: (st at: 'asF16' receiverType: #f32) resultTypeSymbol
		equals: #f16
]

{ #category : 'tests' }
PVCompilerTest >> testSelectorTableMapsHalfArithmeticLikeFloat [
	"Half arithmetic is the same SPIR-V instruction as single precision arithmetic; only
	 the result type differs. Stated against the f32 rows so the two cannot drift apart."

	| st |
	st := PVSelectorTable standard.
	#( '+' '-' '*' '/' ) do: [ :each |
		self
			assert: (st at: each receiverType: #f16) spirvOp
			equals: (st at: each receiverType: #f32) spirvOp.
		self
			assert: (st at: each receiverType: #f16) resultTypeSymbol
			equals: #f16 ].
	#( '<' '<=' ) do: [ :each |
		self
			assert: (st at: each receiverType: #f16) spirvOp
			equals: (st at: each receiverType: #f32) spirvOp.
		self
			assert: (st at: each receiverType: #f16) resultTypeSymbol
			equals: #bool ]
]

{ #category : 'tests' }
PVCompilerTest >> testSelectorTableMapsHalfBufferAccess [
	"Indexing a half buffer answers a half, and storing into one answers nothing."

	| st |
	st := PVSelectorTable standard.
	self
		assert: (st at: 'at:' receiverType: #bufferOf_f16) spirvOp
		equals: #bufferLoad.
	self
		assert: (st at: 'at:' receiverType: #bufferOf_f16) resultTypeSymbol
		equals: #f16.
	self
		assert: (st at: 'at:put:' receiverType: #bufferOf_f16) spirvOp
		equals: #bufferStore.
	self
		assert: (st at: 'at:put:' receiverType: #bufferOf_f16) resultTypeSymbol
		equals: #void
]

{ #category : 'tests - selector table' }
PVCompilerTest >> testSharedMappingsCoverEveryTileTypeTheEmitterCanDeclare [
	"A kernel body reaches a tile with at: and at:put: and nothing else, so every shared type
	 the emitter can declare needs both mappings. Stated over the shared element types rather
	 than over a list written here, so a type added to one and forgotten in the other fails."

	| table |
	table := PVSelectorTable standard.
	PVSPIRVEmitter sharedElementTypes keysAndValuesDo: [
		:sharedType
		:elementType |
		self
			assert: (table at: 'at:' receiverType: sharedType) resultTypeSymbol
			equals: elementType.
		self
			assert: (table at: 'at:put:' receiverType: sharedType) spirvOp
			equals: #sharedStore ]
]

{ #category : 'tests - shared memory' }
PVCompilerTest >> testSharedPragmaRefusesAnElementTypeTheEmitterCannotDeclare [
	"A <shared:named:count:> pragma naming an element type with no shared array type is
	 refused when the annotation is read, rather than defaulting to a tile of the wrong
	 element type."

	self
		should: [ PVSPIRVEmitter sharedTypeOf: #mat4 ]
		raise: PVTypeError.
	self
		should: [ PVSPIRVEmitter sharedElementTypeOf: #sharedOf_mat4 ]
		raise: PVTypeError.
	self
		assert: (PVSPIRVEmitter sharedTypeOf: #f32)
		equals: #sharedOf_f32.
	self
		assert: (PVSPIRVEmitter sharedElementTypeOf: #sharedOf_f32)
		equals: #f32
]

{ #category : 'tests - header' }
PVCompilerTest >> testSpirvMagicAssertionRejectsAForeignHeader [
	"The shared header assertion must be able to fail, or every test using it is vacuous."
	self
		should: [ self assertSpirvMagic: #[ 1 2 3 4 ] description: 'junk' ]
		raise: TestFailure
]

{ #category : 'tests' }
PVCompilerTest >> testSpvTypeForHalfIsASixteenBitFloat [
	"OpTypeFloat carries its width, so a half type is a distinct declaration from a float
	 one and must not be deduplicated with it."

	| em |
	em := PVSPIRVEmitter new.
	self assert: (em spvTypeFor: #f16) width equals: 16.
	self assert: (em spvTypeFor: #f32) width equals: 32.
	self deny: (em spvTypeFor: #f16) id = (em spvTypeFor: #f32) id
]

{ #category : 'tests' }
PVCompilerTest >> testSqrtCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #sqrtF32:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testSqrtCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testStackSimulatorAssignsRegs [
	| m bytecodeOps regOps sends |
	m := (Smalltalk at: #PVKernelExamples) >> #addFloat:to:.
	bytecodeOps := PVBytecodeDecoder decode: m.
	regOps := PVStackSimulator simulate: bytecodeOps.
	sends := regOps select: [ :op | op opcode = #send ].
	self assert: sends size equals: 1.
	self assert: sends first literal equals: #+.
	self assert: sends first inputs size equals: 2
]

{ #category : 'tests' }
PVCompilerTest >> testStackSimulatorParamCountPreseeds [
| ops sim |
sim := PVStackSimulator new.
sim simulate: #() paramCount: 3.
self assert: (sim tempDefs at: 0) equals: 1.
self assert: (sim tempDefs at: 1) equals: 2.
self assert: (sim tempDefs at: 2) equals: 3.
self assert: sim nextReg equals: 3
]

{ #category : 'tests' }
PVCompilerTest >> testStraightLineAdd [
	| m bytes |
	m := PVKernelExamples >> #addFloat:to:.
	bytes := PVKernelCompiler compileMethod: m.
	self deny: bytes isEmpty.
	self assertSpirvMagic: bytes description: 'addFloat:to:'
]

{ #category : 'tests' }
PVCompilerTest >> testSubgroupDotKernelDeclaresTheGroupCapabilities [
	"A module that reduces across a subgroup must ask for both capabilities. Without
	 GroupNonUniformArithmetic the driver is entitled to reject the add, and a module that
	 only declares Shader passes spirv-val while failing on the device."

	| caps |
	caps := self capabilitiesIn:
		        (PVKernelCompiler compileMethod:
			         PVKernelExamples >> #subgroupDotOf:a:b:out:lanes:).
	self assert: (caps includes: PVSPIRVEmitter groupNonUniformCapability).
	self assert:
		(caps includes: PVSPIRVEmitter groupNonUniformArithmeticCapability)
]

{ #category : 'tests' }
PVCompilerTest >> testSubgroupDotKernelReducesOverTheSubgroupScope [
	"Both reductions — the one over the products and the one that counts the lanes — go over
	 the subgroup and not the workgroup, and add every lane's value rather than scanning. The
	 scope is an id, so the test resolves it back to the constant the module declares instead
	 of trusting a number the emitter allocated."

	| bytes reductions scopeId |
	bytes := PVKernelCompiler compileMethod:
		         PVKernelExamples >> #subgroupDotOf:a:b:out:lanes:.
	reductions := self
		              operandsOf: SpvOpcode opGroupNonUniformFAdd
		              in: bytes.
	self assert: reductions size equals: 2.
	scopeId := self constantIdOfValue: SpvScope subgroup in: bytes.
	reductions do: [ :operands |
		self assert: (operands at: 3) equals: scopeId.
		self assert: (operands at: 4) equals: SpvGroupOperation reduce ]
]

{ #category : 'tests' }
PVCompilerTest >> testSubgroupSumMapsToTheGroupNonUniformAdd [
	"The DSL surface for the reduction. A float that answers a float, because the operation
	 adds the value every lane of the subgroup holds and delivers one sum."

	| mapping |
	mapping := PVSelectorTable standard at: 'subgroupSum' receiverType: #f32.
	self assert: mapping spirvOp equals: #subgroupReduceSum.
	self assert: mapping resultTypeSymbol equals: #f32
]

{ #category : 'tests' }
PVCompilerTest >> testSubgroupSumOnTheHostAnswersTheValueItself [
	"The host meaning of the DSL selector: one process is a subgroup of one, so the sum over
	 it is the value. A kernel body has to mean something when it runs in the image."

	self assert: 3.5 subgroupSum equals: 3.5
]

{ #category : 'tests - compiler' }
PVCompilerTest >> testTargetRowsOfANodeReadTheOverridesAndNotAList [
	"The Targets tab must not restate which shape each target emits: it reflects over the
	 node's own class, so a shape that gains or loses an emitter changes the tab with it."

	| selection nested emitted |
	selection := PVSelectionNode new.
	nested := PVNestedLoopNode new.
	emitted := [ :node |
		           (node targetRows select: [ :row | row value = 'yes' ])
			           collect: [ :row | row name ] ].
	self assert: (emitted value: selection) size equals: 3.
	self
		assert: (emitted value: nested) asArray
		equals: #( 'Compute kernel' ).
	self assert: nested targetRows size equals: 3
]

{ #category : 'tests - inspecting' }
PVCompilerTest >> testTheDispatchViewNamesEveryMappingTheTableHoldsSplitBackIntoSelectorAndReceiverType [
	"The dispatch table is read when a kernel is refused for a send the table does not know, so
	 the view must hold one row per mapping and name the receiver type and the selector apart.
	 The key is built by the table itself, so the view splits it with the table's own inverse
	 and every row found that way must look the mapping up again."

	| table view rows |
	table := PVSelectorTable standard.
	view := table inspectorDispatch: SpPresenter new.
	rows := view items.
	self assert: rows size equals: table size.
	self assert: (rows allSatisfy: [ :each |
			 (table
				  at: (each at: #selector)
				  receiverType: (each at: #receiverType)) spirvOp asString
			 = (each at: #operation) ]).
	self assert: (rows allSatisfy: [ :each |
			 (table
				  at: (each at: #selector)
				  receiverType: (each at: #receiverType)) resultTypeSymbol asString
			 = (each at: #resultType) ]).
	self
		assert: (rows collect: [ :each | each at: #receiverType ]) asArray
		equals: (rows collect: [ :each | each at: #receiverType ]) asArray sort
]

{ #category : 'tests - dispatch' }
PVCompilerTest >> testTheDispatchViewsReadTheTablesTheyReport [
	"Both views are read from the tables rather than from a list written beside them, so the
	 mapping's own row names the method the dispatch would send, and the emitter's view carries
	 one row per register opcode and one per operation of the standard table."

	| mapping row view |
	mapping := PVCompilerExamples mappingOfTheSubgroupSum.
	view := mapping inspectorEmitting: SpPresenter new.
	row := view items detect: [ :each | each name = 'emitted by' ].
	self assert: row value equals: mapping emitterSelector printString.
	self
		assert: (view items detect: [ :each | each name = 'takes the result type' ])
				value
		equals: true printString.
	view := PVSPIRVEmitter inspectorDispatch: SpPresenter new.
	self
		assert: view items size
		equals: PVSPIRVEmitter regOpEmitters size
			+ PVSelectorTable standard table size.
	self
		assert: (view items anySatisfy: [ :each |
				 each value beginsWith: 'plain opcode ' ])
		description: 'the arithmetic mappings carry no emitter method of their own'
]

{ #category : 'tests - dsl selectors' }
PVCompilerTest >> testTheKernelSendGateSeesASelectorNoClassImplements [
	| hole |
	hole := #thisSelectorNoClassOfTheImageImplements.
	self assert: (SystemNavigation default allImplementorsOf: hole) isEmpty.
	self
		assertCollection: (self selectorsNoClassImplementsAmong: { #at:put:. hole })
		hasSameElements: { hole }
]

{ #category : 'tests - inspecting' }
PVCompilerTest >> testThePipelineViewNamesTheStagesTheCompilerRanAndWhatTheyLeftBehind [
	"A reader opens a compiler to see how far a compile got. The view names the stage classes in
	 the order decode sends them, read from that method's own syntax tree, and the target from
	 the same selector compile dispatches on, so neither can drift. The state rows count what
	 the stages really left behind."

	| compiler view valueOf stages |
	compiler := PVCompilerExamples compilerOfTheClampKernel.
	view := compiler inspectorPipeline: SpPresenter new.
	valueOf := [ :name |
	           (view items detect: [ :each | each name = name ]) value ].
	stages := ((PVKernelCompiler >> #decode) ast allChildren select: [ :each |
		           each isMessage and: [
			           each receiver isVariable and: [
				           each receiver name first isUppercase ] ] ]) collect: [ :each |
		          each receiver name ].
	self deny: stages isEmpty.
	self assert: (stages allSatisfy: [ :each |
			 view items anySatisfy: [ :row | row name = each ] ]).
	self
		assert: (valueOf value: 'target')
		equals: compiler targetSelector asString.
	self
		assert: (valueOf value: 'register operations')
		equals: compiler registerOperations size printString.
	self
		assert: (valueOf value: 'basic blocks')
		equals: compiler basicBlocks size printString.
	self
		assert: (valueOf value: 'inferred types')
		equals: compiler typeMap size printString
]

{ #category : 'tests - inspecting' }
PVCompilerTest >> testThePipelineViewOpensOnACompilerThatHasCompiledNothing [
	"A compiler is inspected while it is being set up as well as after a compile, so the view
	 must open on one that holds no method: the stages are still named and every fact beside
	 them is empty."

	| view stateRows |
	view := PVKernelCompiler new inspectorPipeline: SpPresenter new.
	self
		assert: (view items first: PVKernelCompiler stageClassNames size)
		equals: ((view items first: PVKernelCompiler stageClassNames size)
				 select: [ :each | each value endsWith: 'of decode' ]).
	stateRows := view items allButFirst: PVKernelCompiler stageClassNames size.
	self deny: stateRows isEmpty.
	self assert: (stateRows allSatisfy: [ :each | each value = nil asString ])
]

{ #category : 'tests - inspecting' }
PVCompilerTest >> testTheTypesViewNamesEveryRegisterTheInferencerTypedAndTheParametersItWasSeededFrom [
	"A type error is read in this tab: one row per register the inferencer typed, in register
	 order, and the registers the declared parameters seeded named for the parameter they came
	 from. The seeding rule is the inferencer's own — a parameter seeds the register of its
	 position — so the view counts the annotation's parameters rather than restating which
	 registers are seeds."

	| inferencer view rows params |
	inferencer := PVCompilerExamples inferencerOfTheClampKernel.
	view := inferencer inspectorTypes: SpPresenter new.
	rows := view items.
	self assert: rows size equals: inferencer typeMap size.
	self
		assert: (rows collect: [ :each | each value ]) asArray
		equals: ((inferencer typeMap keys asSortedCollection collect: [ :key |
				  (inferencer typeMap at: key) asString ]) asArray).
	params := inferencer annotation params.
	self deny: params isEmpty.
	params doWithIndex: [ :param :index |
		self assert:
			((rows detect: [ :each | each name beginsWith: index printString ]) name
				 includesSubstring: param name asString) ]
]

{ #category : 'tests - half precision' }
PVCompilerTest >> testTiledHalfMatmulHoldsHalfTilesAndAccumulatesInFloat [
	"The tiled kernel in half precision, read back out of the bytes it emits: one shared tile
	 per input matrix, a barrier on each side of the accumulation loop, and both float widths,
	 because the tiles hold halves while the dot product accumulates in float."

	| bytes module widths |
	bytes := PVKernelCompiler compileMethod: (PVKernelExamples tiledMatmulFor: #f16).
	module := PVSpirvValidator on: bytes.
	self
		assert: (module variableCountInStorageClass: SpvStorageClass workgroup)
		equals: 2.
	self assert: (module countOfOpcode: SpvOpcode opControlBarrier) equals: 2.
	widths := (self operandsOf: SpvOpcode opTypeFloat in: bytes) collect: [ :each |
		          each second ].
	self assert: widths asSortedCollection asArray equals: #( 16 32 ).
	self deny: (self operandsOf: SpvOpcode opFConvert in: bytes) isEmpty
]

{ #category : 'tests - half precision' }
PVCompilerTest >> testTiledHalfMatmulModuleIsValidSpirv [
	"Half precision in the Workgroup storage class is not the same thing as half precision in
	 a storage buffer: the validator is the only thing here that checks the module declares
	 what the tiles need."

	| validator |
	PVSpirvValidator isAvailable ifFalse: [ ^ self skip ].
	validator := PVSpirvValidator on:
		             (PVKernelCompiler compileMethod:
			              (PVKernelExamples tiledMatmulFor: #f16)).
	self assert: validator isValid description: validator validationOutput
]

{ #category : 'tests' }
PVCompilerTest >> testTypeInferencerResolvesAdd [
	| m ann bytecodeOps regOps st typeInf typeMap addOp |
	m := (Smalltalk at: #PVKernelExamples) >> #addFloat:to:.
	ann := PVTypeAnnotation fromMethod: m.
	bytecodeOps := PVBytecodeDecoder decode: m.
	regOps := PVStackSimulator simulate: bytecodeOps.
	st := PVSelectorTable standard.
	typeInf := PVTypeInferencer new initialize annotation: ann.
	typeMap := typeInf inferAll: regOps selectorTable: st.
	addOp := regOps detect: [ :op | op opcode = #send ].
	self assert: (typeMap at: addOp result) equals: #f32
]

{ #category : 'tests' }
PVCompilerTest >> testUnknownBufferTypeIsRefused [
	"The degenerate buffer type. A stride quietly defaulting to four bytes would emit a
	 module that validates and reads the wrong addresses."

	self
		should: [ PVSPIRVEmitter storageBufferArrayStrideFor: #bufferOf_f64 ]
		raise: PVTypeError.
	self
		should: [ PVSPIRVEmitter new spvTypeFor: #f64 ]
		raise: PVTypeError
]

{ #category : 'tests' }
PVCompilerTest >> testVec3AddCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #vec3Add:b:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVec3AddCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVec3DotCompiles [
    | bytes |
    bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #dotOfA:b:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assertSpirvMagic: bytes description: 'testVec3DotCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVec3LengthCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #vec3Length:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVec3LengthCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVec4WCompiles [
| bytes |
bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #vec4W:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVec4WCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVectorAddKernelCompiles [
| m bytes |
m := PVKernelExamples >> #vectorAdd:a:b:out:.
bytes := PVKernelCompiler compileMethod: m.
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVectorAddKernelCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVertexShaderCompiles [
    | bytes |
    bytes := PVKernelCompiler compileMethod: (PVKernelExamples >> #triVertex:color:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assertSpirvMagic: bytes description: 'testVertexShaderCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testWorkItemAtTheOriginOfAnEmptyGrid [
	"The degenerate item: invocation zero of a dispatch that covers nothing. Its grid width
	 is zero, which a kernel loop reads as no iterations."

	| item |
	item := PVWorkItem x: 0 y: 0 z: 0 gridWidth: 0.
	self assert: item x equals: 0.
	self assert: item gridWidth equals: 0.
	self assert: item dispatchReport size equals: item kernelSelectors size
]

{ #category : 'tests' }
PVCompilerTest >> testWorkItemCarriesTheDispatchCoordinates [
	| item |
	item := PVWorkItem x: 3 y: 7 z: 0 gridWidth: 512.
	self assert: item x equals: 3.
	self assert: item y equals: 7.
	self assert: item z equals: 0.
	self assert: item gridWidth equals: 512
]

{ #category : 'tests' }
PVCompilerTest >> testWorkItemImplementsEverySelectorTheTableMapsForIt [
	"Every selector a kernel may send to its WorkItem must exist on the host too, or the
	 kernel source is a message to nobody. Asked of the table, so a mapping added later
	 without a host-side method fails here."

	| item |
	item := PVComputeExamples workItemInA512Grid.
	self deny: item kernelSelectors isEmpty.
	item kernelSelectors do: [ :selector |
		self
			assert: (PVWorkItem canUnderstand: selector)
			description: 'PVWorkItem must implement ' , selector ]
]

{ #category : 'tests' }
PVCompilerTest >> testWorkItemReportCoversTheWholeVocabulary [
	| item values |
	item := PVComputeExamples workItemInA512Grid.
	self assert: item dispatchReport size equals: item kernelSelectors size.
	values := item dispatchReport collect: [ :each | each value ].
	self deny: (values includes: 'not implemented').
	self assert: (values includes: '512')
]

{ #category : 'helpers' }
PVCompilerTest >> wordsIn: bytes [
	"A SPIR-V module reaches Vulkan as a little-endian stream of 32-bit words, so a test
	 about what a module declares has to read the words back out of the bytes."

	^ (1 to: bytes size by: 4) collect: [ :each |
		  (bytes at: each) + ((bytes at: each + 1) bitShift: 8)
		  + ((bytes at: each + 2) bitShift: 16)
		  + ((bytes at: each + 3) bitShift: 24) ]
]
