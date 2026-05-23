Class {
	#name : 'PVCompilerTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Compiler',
	#package : 'PharoVulkan-Tests-Compiler'
}

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
	self assert: ssaCFG == cfg
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
