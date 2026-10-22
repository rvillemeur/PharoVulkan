"
The examples of SpvBuilder: one builder holding a module built from the
structured control flow the builder emits, a counting loop with a selection nested
in its body and two function variables. structuredControlFlowBuilder answers it, its
Blocks tab shows the block order SPIR-V asks for, and PVSpirvValidatorTest hands
the same module to spirv-val, so the example and the gate read one module and not
two copies of it.
"
Class {
	#name : 'SpvBuilderExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-SPIRV',
	#package : 'PharoVulkan-Examples',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvBuilderExamples class >> bufferBindingIndex [
	^ 0
]

{ #category : 'building' }
SpvBuilderExamples class >> bufferIn: aBuilder ofElement: aType [
	"The one storage buffer the example writes, decorated as a block at set zero binding
	 zero. The stride belongs to the array type and the offset to the member: spirv-val
	 refuses a stride on a structure member."

	| array structure pointer variable |
	array := aBuilder types runtimeArrayType: aType.
	structure := aBuilder types structType: { array }.
	pointer := aBuilder types
		           pointerType: SpvStorageClass storageBuffer
		           type: structure.
	aBuilder
		addDecoration: array id
		decoration: SpvDecoration arrayStride
		literals: { self elementStride }.
	aBuilder
		addDecoration: structure id
		decoration: SpvDecoration block
		literals: #().
	aBuilder
		addMemberDecoration: structure id
		member: self firstMember
		decoration: SpvDecoration offset
		literals: { self firstMember }.
	variable := aBuilder
		            addGlobalVariable: pointer
		            storageClass: SpvStorageClass storageBuffer.
	aBuilder
		addDecoration: variable id
		decoration: SpvDecoration descriptorSet
		literals: { self descriptorSetIndex }.
	aBuilder
		addDecoration: variable id
		decoration: SpvDecoration bindingDecoration
		literals: { self bufferBindingIndex }.
	^ variable
]

{ #category : 'constants' }
SpvBuilderExamples class >> descriptorSetIndex [
	^ 0
]

{ #category : 'constants' }
SpvBuilderExamples class >> elementStride [
	"One unsigned 32-bit element of the buffer the example writes."

	^ 4
]

{ #category : 'constants' }
SpvBuilderExamples class >> entryPointName [
	^ 'main'
]

{ #category : 'constants' }
SpvBuilderExamples class >> firstMember [
	"The one member of the buffer structure, and the element of its array the sum lands in."

	^ 0
]

{ #category : 'building' }
SpvBuilderExamples class >> in: aBuilder clear: aVariableId [
	aBuilder emitStore: (aBuilder constants constantUInt32: 0) at: aVariableId
]

{ #category : 'building' }
SpvBuilderExamples class >> in: aBuilder compare: aVariableId below: anInteger [
	^ aBuilder
		  emitBinaryOp: SpvOpcode opULessThan
		  left: (self in: aBuilder valueOf: aVariableId)
		  right: (aBuilder constants constantUInt32: anInteger)
		  type: aBuilder types boolType
]

{ #category : 'building' }
SpvBuilderExamples class >> in: aBuilder declareEntryPoint: aFunction reading: aBufferVariable [
	aBuilder
		addEntryPoint: aFunction
		executionModel: SpvExecutionModel glCompute
		name: self entryPointName
		interfaces: { aBufferVariable }.
	aBuilder
		addExecutionMode: aFunction
		mode: SpvExecutionMode localSize
		literals: self localSize
]

{ #category : 'building' }
SpvBuilderExamples class >> in: aBuilder increment: aVariableId byValue: aValueId [
	| u32 |
	u32 := aBuilder types intType: self scalarBitWidth signed: false.
	aBuilder
		emitStore: (aBuilder
				 emitBinaryOp: SpvOpcode opIAdd
				 left: (self in: aBuilder valueOf: aVariableId)
				 right: aValueId
				 type: u32)
		at: aVariableId
]

{ #category : 'building' }
SpvBuilderExamples class >> in: aBuilder store: aVariableId into: aBufferVariable [
	| element index |
	element := aBuilder types
		           pointerType: SpvStorageClass storageBuffer
		           type: (aBuilder types intType: self scalarBitWidth signed: false).
	index := aBuilder constants constantUInt32: self firstMember.
	aBuilder
		emitStore: (self in: aBuilder valueOf: aVariableId)
		at: (aBuilder
				 emitAccessChain: aBufferVariable id
				 type: element
				 indices: {
						 index.
						 index })
]

{ #category : 'building' }
SpvBuilderExamples class >> in: aBuilder sumLowHalfOf: aCounterId into: aTotalId [
	"The loop and the selection nested in its body: the counter turns up to loopLimit and the
	 values below loopSplit are added, so both arms of the selection are really taken."

	aBuilder
		emitWhile: [ self in: aBuilder compare: aCounterId below: self loopLimit ]
		do: [
			aBuilder
				emitIf: (self in: aBuilder compare: aCounterId below: self loopSplit)
				then: [
					self
						in: aBuilder
						increment: aTotalId
						byValue: (self in: aBuilder valueOf: aCounterId) ].
			self
				in: aBuilder
				increment: aCounterId
				byValue: (aBuilder constants constantUInt32: 1) ]
]

{ #category : 'building' }
SpvBuilderExamples class >> in: aBuilder valueOf: aVariableId [
	^ aBuilder
		  emitLoad: aVariableId
		  type: (aBuilder types intType: self scalarBitWidth signed: false)
]

{ #category : 'constants' }
SpvBuilderExamples class >> localSize [
	"One invocation: the example is a shape to read and not a computation to spread."

	^ #( 1 1 1 )
]

{ #category : 'constants' }
SpvBuilderExamples class >> loopLimit [
	"How many times the loop of structuredControlFlowBuilder turns."

	^ 10
]

{ #category : 'constants' }
SpvBuilderExamples class >> loopSplit [
	"The counter below which the nested selection adds, so both of its arms are really taken."

	^ 5
]

{ #category : 'constants' }
SpvBuilderExamples class >> scalarBitWidth [
	^ 32
]

{ #category : 'examples' }
SpvBuilderExamples class >> structuredControlFlowBuilder [
	"One click: a module built only from the builder's structured control flow. Two function
	 variables stand in the entry block, a counting loop turns loopLimit times, a selection
	 nested in its body adds the counter while it is below loopSplit, and the sum is stored
	 into the first element of one storage buffer. Open the Blocks tab to read the block
	 order SPIR-V asks for."

	<sampleInstance>
	| builder u32 buffer function total counter |
	builder := SpvBuilder new.
	builder addCapability: #Shader.
	u32 := builder types intType: self scalarBitWidth signed: false.
	buffer := self bufferIn: builder ofElement: u32.
	function := builder newFunction: builder types voidType.
	builder currentBlock: function addBlock.
	total := builder emitVariableOfType: u32.
	counter := builder emitVariableOfType: u32.
	self in: builder clear: total.
	self in: builder clear: counter.
	self in: builder sumLowHalfOf: counter into: total.
	self in: builder store: total into: buffer.
	builder emitReturn.
	self in: builder declareEntryPoint: function reading: buffer.
	^ builder
]
