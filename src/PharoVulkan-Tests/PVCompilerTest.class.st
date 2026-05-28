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

{ #category : 'tests' }
PVCompilerTest >> testAlphaClipFragmentCompiles [
	| bytes |
	bytes := PVKernelCompiler compile: (PVKernelExamples >> #alphaClip:threshold:).
	self assert: ((bytes copyFrom: 1 to: 4) = #[3 2 35 7]) description: 'alphaClip:threshold: must start with SPIR-V magic number'
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

{ #category : 'tests' }
PVCompilerTest >> testClampCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #clampF32:lo:hi:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
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
PVCompilerTest >> testFragmentShaderCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #triFragment:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testGlslTriFragmentCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #glslTriFragment:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testGlslTriVertexCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testLoopKernelCompiles [

	| bytes |
	bytes := PVKernelCompiler compile:
		         PVKernelExamples >> #accumulateUpTo:.
	self assert: (bytes copyFrom: 1 to: 4) equals: #[ 3 2 35 7 ]
]

{ #category : 'tests' }
PVCompilerTest >> testMat4MulCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #mat4Mul:vec:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testNormalizeCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #normalizeV:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
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

{ #category : 'tests' }
PVCompilerTest >> testSqrtCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #sqrtF32:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
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
	m := (Smalltalk at: #PVKernelExamples) >> #addFloat:to:.
	bytes := PVKernelCompiler compile: m.
	"Must be a non-empty ByteArray with SPIR-V magic at the start"
	self assert: bytes class equals: ByteArray.
	self deny: bytes isEmpty.
	"SPIR-V magic: 0x07230203 little-endian = 3 2 35 7"
	self assert: (bytes at: 1) equals: 3.
	self assert: (bytes at: 2) equals: 2.
	self assert: (bytes at: 3) equals: 35.
	self assert: (bytes at: 4) equals: 7
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
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testVec3DotCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #dotOfA:b:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testVec3LengthCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #vec3Length:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testVec4WCompiles [
| bytes |
bytes := PVKernelCompiler compile: (PVKernelExamples >> #vec4W:).
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testVectorAddKernelCompiles [
| m bytes |
m := PVKernelExamples >> #vectorAdd:a:b:out:.
bytes := PVKernelCompiler compile: m.
self assert: bytes class equals: ByteArray.
self deny: bytes isEmpty.
self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]

{ #category : 'tests' }
PVCompilerTest >> testVertexShaderCompiles [
    | bytes |
    bytes := PVKernelCompiler compile: (PVKernelExamples >> #triVertex:color:).
    self assert: bytes class equals: ByteArray.
    self deny: bytes isEmpty.
    self assert: (bytes copyFrom: 1 to: 4) equals: #[3 2 35 7]
]
