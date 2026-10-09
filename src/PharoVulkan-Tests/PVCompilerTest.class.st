"
SUnit test suite for the Pharo→SPIR-V compiler pipeline. Covers each stage: bytecode decode, stack simulation, CFG build, SSA construction, type inference, structured-CFG recognition, and SPIR-V emission. All 12 tests must pass.
"
Class {
	#name : 'PVCompilerTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Compiler',
	#package : 'PharoVulkan-Tests',
	#tag : 'Compiler'
}

{ #category : 'private - cfg shapes' }
PVCompilerTest >> assertShapeCompiles: aSelector [
	"A shape the recogniser does represent must emit a SPIR-V module. Checks the magic
	 word against SpvSerializer rather than a literal byte pattern."

	| bytes expectedMagic |
	bytes := PVKernelCompiler compile: (PVCfgShapeFixture >> aSelector).
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
	[ PVKernelCompiler compile: (PVCfgShapeFixture >> aSelector) ]
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

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> recogniserFor: aSelector [
	^ PVStructuredCFGRecognizer new initialize:
		  (PVCFGBuilder buildBytecodeBlocks:
			   (PVBytecodeDecoder decode: (PVCfgShapeFixture >> aSelector)))
]

{ #category : 'tests' }
PVCompilerTest >> testAlphaClipFragmentCompiles [
	| bytes |
	bytes := PVKernelCompiler compile: (PVKernelExamples >> #alphaClip:threshold:).
	self assertSpirvMagic: bytes description: 'alphaClip:threshold:'
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
PVCompilerTest >> testCFGBuilderSingleBlock [
	| m bytecodeOps regOps cfg |
	m := (Smalltalk at: #PVKernelExamples) >> #addFloat:to:.
	bytecodeOps := PVBytecodeDecoder decode: m.
	regOps := PVStackSimulator simulate: bytecodeOps.
	cfg := PVCFGBuilder buildFrom: regOps.
	self assert: cfg blocks size equals: 1.
	self assert: cfg entry ops size equals: regOps size
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeLoopThenSelectionRejected [
	"Emitted OpReturnValue with a bool from a function declared to return an int before
	 the coverage check existed; spirv-val rejected the module."

	self assertShapeRejected: #loopThenSelection:
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testCfgShapeNestedLoopsRejected [
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
bytes := PVKernelCompiler compile: (PVKernelExamples >> #clampF32:lo:hi:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testClampCompiles'
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

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testExampleRecogniserOnLoopKernelIsRecognised [

	| recogniser |
	recogniser := PVStructuredCFGRecognizer exampleRecogniserOnLoopKernel.
	self assert: (recogniser recognize isKindOf: PVLoopNode).
	self assert: (recogniser recognitionReport allSatisfy: [ :each | each value ])
]

{ #category : 'tests' }
PVCompilerTest >> testFragmentShaderCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #triFragment:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assertSpirvMagic: bytes description: 'testFragmentShaderCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testGlslTriFragmentCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #glslTriFragment:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testGlslTriFragmentCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testGlslTriVertexCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testGlslTriVertexCompiles'
]

{ #category : 'tests - cfg shapes' }
PVCompilerTest >> testInspectorRecognitionViewBuildsARowPerBlock [

	| recogniser view |
	recogniser := self recogniserFor: #oneLoop:.
	view := recogniser inspectorRecognition: SpPresenter new.
	self assert: view items size equals: recogniser blocks size
]

{ #category : 'tests' }
PVCompilerTest >> testLoopKernelCompiles [

	| bytes |
	bytes := PVKernelCompiler compile:
		         PVKernelExamples >> #accumulateUpTo:.
	self assertSpirvMagic: bytes description: 'testLoopKernelCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testMat4MulCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #mat4Mul:vec:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testMat4MulCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testNormalizeCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #normalizeV:).
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
PVCompilerTest >> testSSAConstructorNoPhisForStraightLine [

	| m bytecodeOps regOps cfg ssaCFG |
	m := (Smalltalk at: #PVKernelExamples) >> #addFloat:to:.
	bytecodeOps := PVBytecodeDecoder decode: m.
	regOps := PVStackSimulator simulate: bytecodeOps.
	cfg := PVCFGBuilder buildFrom: regOps.
	ssaCFG := PVSSAConstructor construct: cfg.
	"Straight-line: SSA is identity, same object"
	self assert: ssaCFG identicalTo: cfg
]

{ #category : 'tests' }
PVCompilerTest >> testSelectionKernelCompiles [
	| m bytes |
	m := (Smalltalk at: #PVKernelExamples) >> #relu:.
	bytes := PVKernelCompiler compile: m.
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

{ #category : 'tests - header' }
PVCompilerTest >> testSpirvMagicAssertionRejectsAForeignHeader [
	"The shared header assertion must be able to fail, or every test using it is vacuous."
	self
		should: [ self assertSpirvMagic: #[ 1 2 3 4 ] description: 'junk' ]
		raise: TestFailure
]

{ #category : 'tests' }
PVCompilerTest >> testSqrtCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #sqrtF32:).
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
	bytes := PVKernelCompiler compile: m.
	self deny: bytes isEmpty.
	self assertSpirvMagic: bytes description: 'addFloat:to:'
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
PVCompilerTest >> testVec3AddCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #vec3Add:b:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVec3AddCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVec3DotCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #dotOfA:b:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assertSpirvMagic: bytes description: 'testVec3DotCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVec3LengthCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #vec3Length:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVec3LengthCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVec4WCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #vec4W:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVec4WCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVectorAddKernelCompiles [
| m bytes |
m := PVKernelExamples >> #vectorAdd:a:b:out:.
bytes := PVKernelCompiler compile: m.
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assertSpirvMagic: bytes description: 'testVectorAddKernelCompiles'
]

{ #category : 'tests' }
PVCompilerTest >> testVertexShaderCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #triVertex:color:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assertSpirvMagic: bytes description: 'testVertexShaderCompiles'
]
