"
Tests for the PharoVulkan-SPIRV builder infrastructure.
Covers serialization, type deduplication, constant deduplication,
and end-to-end construction of a compute vector-add SPIR-V module.
"
Class {
	#name : 'SpvBuilderTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-SPIRV-Tests-Tests',
	#package : 'PharoVulkan-SPIRV-Tests',
	#tag : 'Tests'
}

{ #category : 'helpers' }
SpvBuilderTest >> buildVectorAddModule [
    "Build a GLCompute SPIR-V module: result[i] = a[i] + b[i].
     Three storage buffer bindings at set=0, binding=0/1/2. LocalSize 64 1 1."
    | b types consts f32 u32 uvec3 pUvec3 rta struct pStruct pF32Buf
      mainFn entryBlock invIdGlobal bufA bufB bufR voidType
      invIdVar idx zero aPtr bPtr rPtr aVal bVal rVal |

    b := SpvBuilder new.
    b beShaderModule.
    types  := b types.
    consts := b constants.

    "Scalar types"
    f32   := types floatType: 32.
    u32   := types intType: 32 signed: false.
    uvec3 := types vectorType: u32 count: 3.

    "Buffer layout: struct { float[] }"
    rta    := types runtimeArrayType: f32.
    struct := types structType: { rta }.
    pStruct := types pointerType: SpvStorageClass storageBuffer type: struct.
    pF32Buf := types pointerType: SpvStorageClass storageBuffer type: f32.
    pUvec3  := types pointerType: SpvStorageClass input type: uvec3.

    "Struct/array decorations"
    b addDecoration: struct id decoration: SpvDecoration block literals: #().
    b addMemberDecoration: struct id member: 0 decoration: SpvDecoration arrayStride literals: { 4 }.

    "Global variables"
    bufA       := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
    bufB       := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
    bufR       := b addGlobalVariable: pStruct storageClass: SpvStorageClass storageBuffer.
    invIdGlobal := b addGlobalVariable: pUvec3 storageClass: SpvStorageClass input.

    "Descriptor binding decorations"
    b addDecoration: bufA id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufA id decoration: SpvDecoration bindingDecoration         literals: { 0 }.
    b addDecoration: bufB id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufB id decoration: SpvDecoration bindingDecoration         literals: { 1 }.
    b addDecoration: bufR id decoration: SpvDecoration descriptorSet literals: { 0 }.
    b addDecoration: bufR id decoration: SpvDecoration bindingDecoration         literals: { 2 }.
    b addDecoration: invIdGlobal id decoration: SpvDecoration builtIn
        literals: { SpvBuiltIn globalInvocationId }.

    "main function body"
    voidType  := types voidType.
    mainFn    := b newFunction: voidType.
    entryBlock := mainFn addBlock.
    b currentBlock: entryBlock.

    invIdVar := b emitLoad: invIdGlobal id type: uvec3.
    idx      := b emitCompositeExtract: invIdVar type: u32 indices: { 0 }.
    zero     := consts constantUInt32: 0.
    aPtr     := b emitAccessChain: bufA id type: pF32Buf indices: { zero. idx }.
    bPtr     := b emitAccessChain: bufB id type: pF32Buf indices: { zero. idx }.
    rPtr     := b emitAccessChain: bufR id type: pF32Buf indices: { zero. idx }.
    aVal     := b emitLoad: aPtr type: f32.
    bVal     := b emitLoad: bPtr type: f32.
    rVal     := b emitBinaryOp: SpvOpcode opFAdd left: aVal right: bVal type: f32.
    b emitStore: rVal at: rPtr.
    b emitReturn.

    "Entry point — execution mode LocalSize = 64 1 1 (mode id 17)"
    b addEntryPoint: mainFn
        executionModel: SpvExecutionModel glCompute
        name: 'main'
        interfaces: { bufA. bufB. bufR. invIdGlobal }.
    b addExecutionMode: mainFn mode: 17 literals: { 64. 1. 1 }.

    ^ b module
]

{ #category : 'fixtures' }
SpvBuilderTest >> builderOnAVoidFunction [
	"A builder whose current block is the first block of a void function with no entry point:
	 what the control flow tests need and nothing else."

	| builder function |
	builder := SpvBuilder new.
	function := builder newFunction: builder types voidType.
	builder currentBlock: function addBlock.
	^ builder
]

{ #category : 'helpers' }
SpvBuilderTest >> definitionOrderIn: bytes [
	"Maps every result id in the module to the position of the instruction that defines it, so
	 a test can state that a definition precedes its use rather than reading hex by eye. Only
	 the instructions that carry a result id in the same place are walked: types, constants
	 and global variables all put it first or second, and this answers both forms by taking
	 the id a type instruction declares."

	| words index order position |
	order := Dictionary new.
	words := self wordsIn: bytes.
	index := 6.
	position := 0.
	[ index <= words size ] whileTrue: [
		| word wordCount opcode |
		word := words at: index.
		wordCount := word bitShift: -16.
		opcode := word bitAnd: 16rFFFF.
		position := position + 1.
		(self resultIdOfTypeOrConstant: opcode at: index in: words) ifNotNil: [ :id |
			order at: id ifAbsentPut: [ position ] ].
		index := index + wordCount ].
	^ order
]

{ #category : 'fixtures' }
SpvBuilderTest >> emitASumIn: aBuilder [
	"An instruction with a result, so a block the tests build is not empty."

	| one u32 |
	u32 := aBuilder types intType: 32 signed: false.
	one := aBuilder constants constantUInt32: 1.
	^ aBuilder emitBinaryOp: SpvOpcode opIAdd left: one right: one type: u32
]

{ #category : 'helpers' }
SpvBuilderTest >> resultIdOfTypeOrConstant: anOpcode at: anIndex in: words [
	"Type declarations carry their result id as the first word after the opcode; constants and
	 variables carry a result type first and the result id second. Anything else answers nil,
	 since this is only asked about the types-and-constants section."

	| typeOpcodes typedOpcodes |
	typeOpcodes := {
		               SpvOpcode opTypeVoid.
		               SpvOpcode opTypeBool.
		               SpvOpcode opTypeInt.
		               SpvOpcode opTypeFloat.
		               SpvOpcode opTypeVector.
		               SpvOpcode opTypeMatrix.
		               SpvOpcode opTypeArray.
		               SpvOpcode opTypeRuntimeArray.
		               SpvOpcode opTypeStruct.
		               SpvOpcode opTypePointer.
		               SpvOpcode opTypeFunction }.
	typedOpcodes := {
		                SpvOpcode opConstant.
		                SpvOpcode opConstantTrue.
		                SpvOpcode opConstantFalse.
		                SpvOpcode opConstantNull.
		                SpvOpcode opVariable }.
	(typeOpcodes includes: anOpcode) ifTrue: [ ^ words at: anIndex + 1 ].
	(typedOpcodes includes: anOpcode) ifTrue: [ ^ words at: anIndex + 2 ].
	^ nil
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testADecorationAnswersTheOpDecorateInstructionOfItsOperands [
	"A decoration is an object that answers its own instruction. The serializer used to read an
	 Array with a symbol in slot one and decide the opcode itself."

	| instruction |
	instruction := (SpvDecorate
		                target: 7
		                decoration: SpvDecoration arrayStride
		                literals: #( 4 )) instruction.
	self assert: instruction opcode equals: SpvOpcode opDecorate.
	self assert: instruction resultId isNil.
	self
		assert: instruction operands asArray
		equals: {
				7.
				SpvDecoration arrayStride.
				4 }
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testAMemberDecorationNamesItsMemberBetweenTheStructAndTheDecoration [
	"OpMemberDecorate carries the member index between the struct and the decoration, which is
	 the one difference between the two kinds of annotation this project emits."

	| instruction |
	instruction := (SpvMemberDecorate
		                target: 9
		                member: 1
		                decoration: SpvDecoration offset
		                literals: #( 16 )) instruction.
	self assert: instruction opcode equals: SpvOpcode opMemberDecorate.
	self
		assert: instruction operands asArray
		equals: {
				9.
				1.
				SpvDecoration offset.
				16 }
]

{ #category : 'tests' }
SpvBuilderTest >> testArrayLengthConstantIsDefinedBeforeTheArrayType [
	"An array type's length is an id, so the constant holding it has to be serialised first.
	 The serialiser used to emit every type and only then every constant, which put the use
	 before the definition and made any fixed-size array invalid SPIR-V."

	| b types f32 array lengthId bytes order |
	b := SpvBuilder new.
	b beShaderModule.
	types := b types.
	f32 := types floatType: 32.
	array := types arrayType: f32 length: 16.
	lengthId := b constants constantUInt32: 16.
	bytes := SpvSerializer serialize: b module.
	order := self definitionOrderIn: bytes.
	self assert: ((order at: lengthId) < (order at: array id))
]

{ #category : 'tests' }
SpvBuilderTest >> testArrayTypeCarriesItsElementTypeAndLengthConstant [
	"A fixed-size array names its length through an id of a constant, not a literal, which is
	 what separates OpTypeArray from OpTypeRuntimeArray."

	| b types f32 array lengthId |
	b := SpvBuilder new.
	types := b types.
	f32 := types floatType: 32.
	lengthId := b constants constantUInt32: 16.
	array := types arrayType: f32 length: 16.
	self assert: array instruction opcode equals: SpvOpcode opTypeArray.
	self assert: array instruction operands equals: {
			f32 id.
			lengthId }
]

{ #category : 'tests' }
SpvBuilderTest >> testArrayTypeOfTheSameShapeIsDeduplicated [
	"Two arrays of the same element type and length are one type, as every other type in the
	 registry is."

	| b types f32 |
	b := SpvBuilder new.
	types := b types.
	f32 := types floatType: 32.
	self
		assert: (types arrayType: f32 length: 16) id
		equals: (types arrayType: f32 length: 16) id.
	self
		deny: (types arrayType: f32 length: 16) id
		equals: (types arrayType: f32 length: 32) id
]

{ #category : 'tests' }
SpvBuilderTest >> testBlockTabNamesTheMergeAndTerminatorOfEveryBlock [
	"The tab is read from the blocks, so it has one row a block and every cell of the loop
	 header names an instruction that block really holds."

	| builder view header |
	builder := SpvBuilderExamples structuredControlFlowBuilder.
	view := builder inspectorBlocks: SpPresenter new.
	self
		assert: view items size
		equals: builder currentBlock function blocks size.
	header := view items
		          detect: [ :each | (each at: #merge) beginsWith: #opLoopMerge ].
	self assert: (header at: #terminator) equals: #opBranchConditional asString.
	self
		assert: (header at: #label)
		equals: (builder currentBlock function blocks second) id.
	self assert: ((view items last) at: #terminator) equals: #opReturn asString
]

{ #category : 'tests' }
SpvBuilderTest >> testBlocksOfASelectionNestedInALoopPrecedeTheLoopsOwnTail [
	"SPIR-V serialises a function's blocks in the order they are added and asks that a block
	 precede every block it dominates, so the blocks a nested selection adds have to sit
	 between the loop body and the loop's continue target rather than after the merge."

	| builder blocks loopMerge |
	builder := self builderOnAVoidFunction.
	builder emitWhile: [ builder constants constantBool: true ] do: [
		builder
			emitIf: (builder constants constantBool: false)
			then: [ self emitASumIn: builder ] ].
	blocks := builder currentBlock function blocks.
	self assert: blocks size equals: 7.
	loopMerge := blocks second instructions last.
	self assert: loopMerge opcode equals: SpvOpcode opLoopMerge.
	self assert: blocks third instructions last opcode equals: SpvOpcode opSelectionMerge.
	self assert: (loopMerge operands first: 2) equals: {
			blocks seventh id.
			blocks sixth id }
]

{ #category : 'tests - cooperative matrix' }
SpvBuilderTest >> testBuilderCanBeOpenedOnAModuleSomeoneElseOwns [
	"PVSPIRVEmitter owns its module and still has to build the cooperative matrix
	 instructions, whose operand assembly lives in this class. A builder opened on an
	 existing module writes into it rather than into one of its own."

	| module builder |
	module := SpvModule new.
	builder := SpvBuilder on: module.
	self assert: builder module identicalTo: module.
	self assert: (builder types floatType: 32) id equals: (module typeRegistry floatType: 32) id
]

{ #category : 'tests' }
SpvBuilderTest >> testConstantDeduplication [
    "Requesting the same constant twice must return the same result id."
    | m id1 id2 |
    m := SpvModule new.
    id1 := m constantPool constantFloat32: 1.0.
    id2 := m constantPool constantFloat32: 1.0.
    self assert: id1 equals: id2
]

{ #category : 'tests - cooperative matrix' }
SpvBuilderTest >> testCooperativeMatrixTypeIsOnePerShapeAndRole [
	"The registry keys a cooperative matrix on its component type and its whole shape, so
	 asking twice for the same one answers the same type, while a different use is a
	 different type even with everything else equal. A key that missed would emit a second
	 OpTypeCooperativeMatrixKHR for a type the module already has."

	| builder f16 shapeOf |
	builder := SpvBuilder new.
	f16 := builder types floatType: 16.
	shapeOf := [ :use |
	           SpvCooperativeMatrixShape
		           rows: 8
		           columns: 8
		           scope: SpvScope subgroup
		           use: use ].
	self
		assert:
		(builder types
			 cooperativeMatrixType: f16
			 shape: (shapeOf value: SpvCooperativeMatrixType matrixAUse)) id
		equals: (builder types
				 cooperativeMatrixType: f16
				 shape: (shapeOf value: SpvCooperativeMatrixType matrixAUse)) id.
	self
		deny:
		(builder types
			 cooperativeMatrixType: f16
			 shape: (shapeOf value: SpvCooperativeMatrixType matrixAUse)) id
		equals: (builder types
				 cooperativeMatrixType: f16
				 shape: (shapeOf value: SpvCooperativeMatrixType matrixBUse)) id
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testDecorationNamesComeFromTheConstantsThemselves [
	"The reverse lookup the annotation view reads: a number no constant answers has no name, and
	 the name of one that does is the selector that answers it, so a constant renamed renames
	 itself here."

	self
		assert: (SpvDecoration nameOfDecoration: SpvDecoration arrayStride)
		equals: #arrayStride.
	self
		assert: (SpvDecoration nameOfDecoration: SpvDecoration bindingDecoration)
		equals: #bindingDecoration.
	self assert: (SpvDecoration nameOfDecoration: -1) isNil
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testEmitAnnotationsNamesNoKindAndNoOpcodeOfItsOwn [
	"The type test is gone for good: the section method asks each annotation for its instruction
	 and names neither kind nor opcode, so a third kind of annotation needs no edit here."

	| method |
	method := SpvSerializer >> #emitAnnotations.
	self assert: (method messages includes: #instruction).
	self deny: (method literals anySatisfy: [ :each |
			 #( #decorate #memberDecorate ) includes: each ]).
	self deny: (method messages anySatisfy: [ :each |
			 #( #opDecorate #opMemberDecorate ) includes: each ])
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testEveryAnnotationKindAnswersAnOpcodeAndOperandsOfItsOwn [
	"SpvAnnotation holds the target, the decoration and the literals, and declares the two hooks
	 without answering either: a kind of annotation says what it emits rather than inherit a
	 guess from its superclass."

	self assert: SpvAnnotation subclasses size equals: 2.
	SpvAnnotation subclasses do: [ :each |
		self assert: (each includesSelector: #opcode).
		self assert: (each includesSelector: #operands) ].
	#( #opcode #operands ) do: [ :selector |
		self
			should: [ SpvAnnotation new perform: selector ]
			raise: SubclassResponsibility ]
]

{ #category : 'tests - package' }
SpvBuilderTest >> testEveryClassOfTheSpirvPackageAnswersItsOwnBinding [
	"A class-side method named after a reflection selector hides the real one. The decoration
	 number used to be answered by a class-side method named binding, so asking SpvDecoration for
	 its binding answered that integer rather than the global variable holding the class, and
	 every tool reading a class through its binding failed on it: Renraku's unreferenced-class
	 rule raised 'SmallInteger did not understand #isReferenced'. Each class of the package is
	 asked, because the next constant named after a reflection selector would break the same way."

	SpvBuilder package definedClasses do: [ :each |
		self assert: each binding value identicalTo: each ]
]

{ #category : 'tests - package' }
SpvBuilderTest >> testEveryTypeClassifiesTheHooksOfItsSuperclassWhereTheSuperclassDoes [
	"The browser groups the type hierarchy by protocol, and Renraku refuses an override
	 classified away from the method it overrides. The hooks are read from SpvType rather than
	 named here, so a third hook declared later is covered the moment it is written, and each one
	 is held to a single protocol across the declaration and every implementation."

	| hooks |
	hooks := SpvType methods
		         select: [ :each |
			         each messages includes: #subclassResponsibility ]
		         thenCollect: [ :each | each selector ].
	self assert: hooks size >= 2.
	hooks do: [ :selector |
		| protocols |
		protocols := ((SpvType withAllSubclasses select: [ :each |
			               each includesSelector: selector ]) collect: [ :each |
			              (each >> selector) protocolName ]) asSet.
		self
			assert: protocols size = 1
			description: selector printString , ' is classified in '
				, protocols asSortedCollection asArray printString ]
]

{ #category : 'tests' }
SpvBuilderTest >> testFunctionVariableIsDeclaredInTheFirstBlockWhateverBlockAsksForIt [
	"SPIR-V asks that every OpVariable of a function stand in its first block, and a
	 rasteriser declares one while it is deep in a loop."

	| builder u32 variable blocks |
	builder := self builderOnAVoidFunction.
	u32 := builder types intType: 32 signed: false.
	variable := nil.
	builder
		emitWhile: [ builder constants constantBool: true ]
		do: [ variable := builder emitVariableOfType: u32 ].
	blocks := builder currentBlock function blocks.
	self assert: blocks first instructions size equals: 1.
	self assert: blocks first instructions first opcode equals: SpvOpcode opVariable.
	self assert: blocks first instructions first resultId equals: variable.
	self assert: (blocks allButFirst noneSatisfy: [ :each |
			 each instructions anySatisfy: [ :instruction |
				 instruction opcode = SpvOpcode opVariable ] ])
]

{ #category : 'tests - module' }
SpvBuilderTest >> testHeaderRowsOfAModuleShowItsOwnValuesBesideTheShaderPrologue [
	"The Header tab reads the module, not a copy of the numbers. A module built with the
	 Vulkan memory model must show a memory model the shader prologue column does not."

	| prologue other memoryRow |
	prologue := SpvModule new beShaderModule.
	prologue headerRows do: [ :row |
		self assert: (row at: #value) equals: (row at: #expected) ].
	other := SpvModule new beShaderModule.
	other
		setAddressingModel: SpvModule logicalAddressingModel
		memoryModel: SpvModule vulkanMemoryModel.
	memoryRow := other headerRows detect: [ :row |
		(row at: #fact) = 'Memory model' ].
	self deny: (memoryRow at: #value) equals: (memoryRow at: #expected)
]

{ #category : 'tests' }
SpvBuilderTest >> testMemorySemanticsAreSingleBitsOfOneMask [
	"Memory semantics is a bitmask, so the named values have to be distinct single bits that
	 can be combined. A value that is not a power of two would silently set two meanings."

	{
		SpvMemorySemantics acquire.
		SpvMemorySemantics releaseSemantics.
		SpvMemorySemantics acquireRelease.
		SpvMemorySemantics uniformMemory.
		SpvMemorySemantics subgroupMemory.
		SpvMemorySemantics workgroupMemory } do: [ :each |
		self assert: each isPowerOfTwo ].
	self
		assert: (SpvMemorySemantics acquireRelease bitAnd:
				 SpvMemorySemantics workgroupMemory)
		equals: 0
]

{ #category : 'tests - barriers' }
SpvBuilderTest >> testModuleAnswersTheSameBarrierTheBuilderDoes [
	"The hand-built path reaches the barrier through the builder and the compiled path
	 reaches it through the module. One definition, so the two cannot drift apart in scope
	 or memory semantics."

	| b fromBuilder fromModule |
	b := SpvBuilder new.
	fromBuilder := b workgroupBarrier.
	fromModule := b module workgroupBarrierInstruction.
	self assert: fromModule opcode equals: fromBuilder opcode.
	self assert: fromModule operands equals: fromBuilder operands
]

{ #category : 'tests - cooperative matrix' }
SpvBuilderTest >> testNullConstantOfACooperativeMatrixTypeIsDeclaredOnce [
	"A zero accumulator is OpConstantNull of the matrix type. Asking twice answers the same
	 id, and the constant must come after the type it is null of, which the ascending id
	 order of the declaration section gives for free."

	| builder matrixType first second |
	builder := SpvBuilder new.
	matrixType := builder types
		              cooperativeMatrixType: (builder types floatType: 32)
		              shape: (SpvCooperativeMatrixShape
				               rows: PVCooperativeMatrixKernel matrixOrder
				               columns: PVCooperativeMatrixKernel matrixOrder
				               scope: SpvScope subgroup
				               use: SpvCooperativeMatrixType matrixAccumulatorUse).
	first := builder constants constantNullOfType: matrixType.
	second := builder constants constantNullOfType: matrixType.
	self assert: first equals: second.
	self assert: first > matrixType id
]

{ #category : 'tests' }
SpvBuilderTest >> testOpcodeNamesComeFromTheConstantsThemselves [
	"The reverse lookup the block tab reads: a number no constant answers has no name, and
	 the name of one that does is the selector that answers it, so a constant renamed or
	 corrected renames itself here."

	self
		assert: (SpvOpcode nameOfOpcode: SpvOpcode opLoopMerge)
		equals: #opLoopMerge.
	self
		assert: (SpvOpcode nameOfOpcode: SpvOpcode opBranchConditional)
		equals: #opBranchConditional.
	self assert: (SpvOpcode nameOfOpcode: -1) isNil
]

{ #category : 'tests' }
SpvBuilderTest >> testSerializeHeader [
    "Serialized SPIR-V must start with the magic bytes 0x07230203 in little-endian."
    | bytes |
    bytes := SpvModule new serialize.
    self assert: (bytes at: 1) equals: 16r03.
    self assert: (bytes at: 2) equals: 16r02.
    self assert: (bytes at: 3) equals: 16r23.
    self assert: (bytes at: 4) equals: 16r07
]

{ #category : 'tests - module' }
SpvBuilderTest >> testShaderModulePrologueDeclaresTheShaderCapabilityAndTheGlsl450MemoryModel [
	"Every module this project emits opens with the same three facts. One message puts them
	 there, asked of the module, so no emitter writes the numbers again."

	| mod |
	mod := SpvModule new beShaderModule.
	self assert: (mod capabilities includes: SpvModule shaderCapability).
	self assert: mod addressingModel equals: SpvModule logicalAddressingModel.
	self assert: mod memoryModel equals: SpvModule glsl450MemoryModel
]

{ #category : 'tests' }
SpvBuilderTest >> testStructuredLoopOrdersHeaderBodyContinueAndMerge [
	| builder blocks header body continue merge |
	builder := self builderOnAVoidFunction.
	builder
		emitWhile: [ builder constants constantBool: true ]
		do: [ self emitASumIn: builder ].
	blocks := builder currentBlock function blocks.
	self assert: blocks size equals: 5.
	header := blocks second.
	body := blocks third.
	continue := blocks fourth.
	merge := blocks fifth.
	self assert: blocks first terminator opcode equals: SpvOpcode opBranch.
	self assert: blocks first terminator operands first equals: header id.
	self assert: header instructions last opcode equals: SpvOpcode opLoopMerge.
	self assert: (header instructions last operands first: 2) equals: {
			merge id.
			continue id }.
	self assert: header terminator opcode equals: SpvOpcode opBranchConditional.
	self assert: (header terminator operands last: 2) equals: {
			body id.
			merge id }.
	self assert: body terminator operands first equals: continue id.
	self assert: continue terminator operands first equals: header id.
	self assert: builder currentBlock equals: merge
]

{ #category : 'tests' }
SpvBuilderTest >> testStructuredSelectionBranchesOverItsBodyToAMergeBlock [
	| builder blocks condition |
	builder := self builderOnAVoidFunction.
	condition := builder constants constantBool: true.
	builder emitIf: condition then: [ self emitASumIn: builder ].
	blocks := builder currentBlock function blocks.
	self assert: blocks size equals: 3.
	self
		assert: blocks first instructions last opcode
		equals: SpvOpcode opSelectionMerge.
	self
		assert: blocks first instructions last operands first
		equals: blocks third id.
	self
		assert: blocks first terminator opcode
		equals: SpvOpcode opBranchConditional.
	self assert: blocks first terminator operands equals: {
			condition.
			blocks second id.
			blocks third id }.
	self assert: blocks second terminator opcode equals: SpvOpcode opBranch.
	self assert: blocks second terminator operands first equals: blocks third id.
	self assert: builder currentBlock equals: blocks third
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testTheAnnotationSectionIsWhatItsAnnotationsAnswer [
	"The annotation section of a serialised module is the concatenation of the instructions its
	 annotations answer, so the serializer decides nothing about a decoration beyond where it
	 goes."

	| module words expected |
	module := SpvModule new beShaderModule.
	module addDecoration: 3 decoration: SpvDecoration block literals: #(  ).
	module
		addMemberDecoration: 3
		member: 0
		decoration: SpvDecoration offset
		literals: #( 0 ).
	words := self wordsIn: (SpvSerializer serialize: module).
	expected := module decorations flatCollect: [ :each |
		            | stream |
		            stream := WriteStream on: (Array new: 0).
		            each instruction encodeInto: stream.
		            stream contents ].
	self
		assert:
		(words asArray indexOfSubCollection: expected asArray startingAt: 1) > 0
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testTheAnnotationViewReadsTheAnnotationItShows [
	"The view names the instruction and the decoration through the reverse lookups rather than
	 restating them, shows the member only for the kind that carries one, and its operand row is
	 the operands of the instruction it would emit."

	| annotation view |
	annotation := SpvBuilderExamples memberOffsetAnnotation.
	view := annotation inspectorAnnotation: SpPresenter new.
	self
		assert: (view items detect: [ :each | each name = 'instruction' ]) value
		equals: #opMemberDecorate asString.
	self
		assert: (view items detect: [ :each | each name = 'decoration' ]) value
		equals: #offset asString.
	self
		assert: (view items detect: [ :each | each name = 'operands' ]) value
		equals: annotation instruction operands asArray printString.
	self assert: (view items anySatisfy: [ :each | each name = 'member' ]).
	view := (SpvDecorate
		         target: 7
		         decoration: SpvDecoration block
		         literals: #(  )) inspectorAnnotation: SpPresenter new.
	self deny: (view items anySatisfy: [ :each | each name = 'member' ])
]

{ #category : 'tests - annotations' }
SpvBuilderTest >> testTheModuleKeepsAnAnnotationForEveryDecorationItIsGiven [
	"What the module holds for a decoration is an annotation object, not an Array whose first
	 slot a reader has to interpret, and the order it was given in is kept."

	| module |
	module := SpvModule new.
	module addDecoration: 3 decoration: SpvDecoration block literals: #(  ).
	module
		addMemberDecoration: 3
		member: 0
		decoration: SpvDecoration offset
		literals: #( 0 ).
	self assert: (module decorations allSatisfy: [ :each |
			 each class includesBehavior: SpvAnnotation ]).
	self
		assert:
		(module decorations collect: [ :each | each instruction opcode ]) asArray
		equals: {
				SpvOpcode opDecorate.
				SpvOpcode opMemberDecorate }
]

{ #category : 'tests - inspecting' }
SpvBuilderTest >> testTheSectionViewNamesEverySectionTheSerializerEmitsAndTheWordsItWrote [
	"The Sections view of a serializer is read while debugging a module that spirv-val refuses,
	 so it must name the sections in the order the serializer really sends them and say how many
	 words each one wrote. Both facts are asked of the code: the order from the AST of
	 serializeModule:, the counts from a replay on a serializer of its own."

	| serializer sent rows |
	serializer := SpvSerializer new.
	serializer serializeModule:
		SpvBuilderExamples structuredControlFlowBuilder module.
	sent := ((SpvSerializer >> #serializeModule:) ast body statements select: [
		         :each |
		         each isMessage and: [
			         each receiver isSelfVariable and: [
				         each selector beginsWith: 'emit' ] ] ]) collect: [ :each |
		        each selector asString ].
	rows := serializer sectionRows.
	self
		assert: (rows collect: [ :each | each name ]) asArray
		equals: sent asArray.
	self
		assert: ((rows inject: 0 into: [ :sum :each | sum + each value asInteger ])
			 * 4)
		equals: (SpvSerializer serialize:
				 SpvBuilderExamples structuredControlFlowBuilder module) size
]

{ #category : 'tests - inspecting' }
SpvBuilderTest >> testTheSectionViewWritesNothingIntoTheSerializerItReads [
	"A view must not change the object it shows. The sections are measured on a serializer of
	 the view's own making, so the words of the inspected serializer stand still and its bytes
	 are the same before and after a reader opens the tab."

	| serializer before view |
	serializer := SpvSerializerExamples serializerOfTheStructuredControlFlowModule.
	before := serializer wordCount.
	view := serializer inspectorSections: SpPresenter new.
	self assert: serializer wordCount equals: before.
	self
		assert: (view items inject: 0 into: [ :sum :each | sum + each value asInteger ])
		equals: before.
	self assert: (SpvSerializer new serializeModule: SpvBuilderExamples structuredControlFlowBuilder module) size
		equals: before * 4
]

{ #category : 'tests - serializing' }
SpvBuilderTest >> testTheSerializerNamesTheCapacityItsWordStreamStartsAt [
	"The capacity the word stream starts at is a constant, not a number written inline: the
	 stream grows on its own, so the number is only a first guess at a module's size and says so
	 where it is named. Which method readies the stream is the serializer's own business, so the
	 class is asked rather than one selector of it."

	| capacity readers |
	capacity := SpvSerializer initialWordCapacity.
	self assert: capacity isInteger.
	self assert: capacity > 0.
	readers := SpvSerializer methods select: [ :each |
		           each messages includes: #initialWordCapacity ].
	self deny: readers isEmpty.
	self deny: (SpvSerializer methods anySatisfy: [ :each |
			 each literals includes: capacity ])
]

{ #category : 'tests - inspecting' }
SpvBuilderTest >> testTheValidatorViewNamesTheToolItRunsAndWhatItSignals [
	"A validator carries no state, so what a reader opens it for is the contract: the executable
	 it runs, the file it writes the bytes into, the exit code it accepts and the exception it
	 raises. The exception is read from the syntax tree of validate: rather than named twice, and
	 the rest from constants, so nothing in the tab can disagree with the code."

	| view valueOf |
	view := SpvValidator new inspectorValidator: SpPresenter new.
	valueOf := [ :name |
	            (view items detect: [ :each | each name = name ]) value ].
	self assert: (valueOf value: 'executable') equals: SpvValidator spirvValPath.
	self
		assert: (valueOf value: 'signals')
		equals: SpvValidationError name asString.
	self
		assert: (valueOf value: 'accepted exit code')
		equals: SpvValidator successExitCode printString.
	self
		assert: ((valueOf value: 'temporary file') includesSubstring:
				 SpvValidator spirvFileExtension).
	self deny: (SpvValidator methods anySatisfy: [ :each |
			 each literals includes: SpvValidator successExitCode ])
]

{ #category : 'tests' }
SpvBuilderTest >> testTypeDeduplication [
    "Requesting the same type twice must return the identical object."
    | m reg t1 t2 |
    m := SpvModule new.
    reg := m typeRegistry.
    t1 := reg floatType: 32.
    t2 := reg floatType: 32.
    self assert: t1 identicalTo: t2
]

{ #category : 'tests' }
SpvBuilderTest >> testTypeIdsAreUnique [
	"Different types must get different ids."

	| m reg |
	m := SpvModule new.
	reg := m typeRegistry.
	self
		deny: (reg floatType: 32) id
		equals: (reg intType: 32 signed: true) id
]

{ #category : 'tests' }
SpvBuilderTest >> testValidatorRaisesOnGarbage [
    "Passing garbage bytes to SpvValidator must raise SpvValidationError."
    self should: [ SpvValidator validate: #[0 1 2 3] asByteArray ]
        raise: SpvValidationError
]

{ #category : 'tests' }
SpvBuilderTest >> testVectorAddModuleSerializes [
    "Build the vector-add compute module and verify it serializes without error."
    | m bytes |
    m := self buildVectorAddModule.
    bytes := m serialize.
    self assert: bytes size > 20.
    self assert: (bytes at: 1) equals: 16r03.
    self assert: (bytes at: 2) equals: 16r02.
    self assert: (bytes at: 3) equals: 16r23.
    self assert: (bytes at: 4) equals: 16r07
]

{ #category : 'tests' }
SpvBuilderTest >> testWorkgroupBarrierCarriesThreeConstantIds [
	"OpControlBarrier takes an execution scope, a memory scope and memory semantics, and all
	 three are ids of constants rather than literals — unlike the group operation beside the
	 scope in a subgroup reduction. The semantics say the workgroup's shared memory is made
	 visible, which is the whole reason a tiled kernel needs the barrier."

	| b barrier scopeId semanticsId |
	b := SpvBuilder new.
	b beShaderModule.
	barrier := b workgroupBarrier.
	scopeId := b constants constantUInt32: SpvScope workgroup.
	semanticsId := b constants constantUInt32:
		               (SpvMemorySemantics acquireRelease
			                bitOr: SpvMemorySemantics workgroupMemory).
	self assert: barrier opcode equals: SpvOpcode opControlBarrier.
	self assert: barrier operands equals: {
			scopeId.
			scopeId.
			semanticsId }
]

{ #category : 'helpers' }
SpvBuilderTest >> wordsIn: bytes [
	"The module as 32-bit little-endian words, which is the only form its instruction stream
	 can be walked in."

	^ (1 to: bytes size by: 4) collect: [ :each |
		  (bytes at: each) + ((bytes at: each + 1) bitShift: 8)
		  + ((bytes at: each + 2) bitShift: 16)
		  + ((bytes at: each + 3) bitShift: 24) ]
]
