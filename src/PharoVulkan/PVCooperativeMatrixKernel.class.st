"
Hand-built SPIR-V for a cooperative matrix multiply-accumulate: one M8 N8 K8 product, A and B half precision, the accumulator single precision, held across one subgroup. The module is assembled through SpvBuilder rather than compiled from a Pharo method, because no DSL selector maps to the cooperative matrix instructions yet; Phase 7 item 7-H exists to prove the instructions correct on a device first.

A kernel cannot choose its own shape. It must name one of the combinations the device reports through vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR, which `VkCooperativeMatrixConfiguration` decodes, and the shape here is the only one lavapipe offers. The module has no control flow at all: every invocation of the subgroup must reach each cooperative matrix instruction, so a branch around one would be invalid.

It needs a context built by capability rather than by position, `VkContext cooperativeMatrixContext`, because the device offering the extension here is not the first enumerated, and that context enables the vulkanMemoryModel feature alongside it: a module declaring CooperativeMatrixKHR must also declare VulkanMemoryModel. Buffers bind in the order left, right, accumulator, and the accumulator binding is also the output, so the host decides what the product is added to. Key methods: spirv, productOf:by:on:, reportRows.
"
Class {
	#name : 'PVCooperativeMatrixKernel',
	#superclass : 'Object',
	#instVars : [
		'spirv',
		'builder',
		'bufferVariables'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> bufferBindings [
	"The descriptor bindings, in the order the host binds its buffers: the two half
	 precision inputs and then the single precision accumulator, which is also the output."

	^ #( 0 1 2 )
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> elementCount [
	^ self matrixOrder * self matrixOrder
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> entryPointName [
	^ 'main'
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> exampleIdentityMatrix [
	"Row major identity of the reported order: multiplying by it leaves the other matrix
	 alone, so a wrong row or column order shows up at a glance."

	| order |
	order := self matrixOrder.
	^ (0 to: self elementCount - 1) collect: [ :each |
		  each \\ order = (each // order)
			  ifTrue: [ 1.0 ]
			  ifFalse: [ 0.0 ] ]
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> exampleRampMatrix [
	"Row major, one value per element, small enough that halves carry them exactly."

	^ (1 to: self elementCount) collect: [ :each | each / 8.0 ]
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> firstElementIndex [
	"The matrices fill their buffers from the start: one tile per dispatch."

	^ 0
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> floatBitWidths [
	"The float widths this kernel knows, by the compiler's element type name. The shape
	 lavapipe reports multiplies halves into floats, so those are the two."

	^ Dictionary newFrom: {
			  (#f16 -> 16).
			  (#f32 -> 32) }
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> leftBinding [
	^ 0
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> localSize [
	"One subgroup, which on lavapipe is eight invocations wide. A cooperative matrix is held
	 across the whole scope, so a workgroup wider than one subgroup would hold a second,
	 unused matrix."

	^ { 8. 1. 1 }
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> matrixOperandCount [
	"A multiply-accumulate takes three matrices: A, B and the accumulator."

	^ 3
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> matrixOrder [
	"The one shape lavapipe reports for VK_KHR_cooperative_matrix is M8 N8 K8, and a kernel
	 must name a reported shape exactly. Square, so one number covers M, N and K."

	^ 8
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> moduleHeaderWordCount [
	"Magic, version, generator, id bound and schema sit before the first instruction."

	^ 5
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> outputBinding [
	^ 2
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> rightBinding [
	^ 1
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> shaderCapability [
	"The serializer maps this symbol to the Shader capability number, so the module names the
	 capability rather than repeating its value."

	^ #Shader
]

{ #category : 'constants' }
PVCooperativeMatrixKernel class >> subgroupScope [
	"The shape lavapipe reports carries subgroup scope, so the matrices are held jointly by
	 one subgroup and the instructions must sit in uniform control flow."

	^ SpvScope subgroup
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> bufferTypeForUse: aUse [
	"Which buffer a matrix of that role is read from, and so which element type it holds."

	^ aUse = SpvCooperativeMatrixType matrixAccumulatorUse
		  ifTrue: [ #bufferOf_f32 ]
		  ifFalse: [ #bufferOf_f16 ]
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> bufferTypeOfBinding: anInteger [
	"The element type each binding holds: halves for the two inputs, floats for the
	 accumulator, which is the combination lavapipe reports."

	^ anInteger = self class outputBinding
		  ifTrue: [ #bufferOf_f32 ]
		  ifFalse: [ #bufferOf_f16 ]
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> buildSpirv [
	"Assemble the module. The capabilities and the buffers are declared before the function,
	 because a definition has to precede every use of its id."

	builder := SpvBuilder new.
	self declareCapabilities.
	self declareBuffers.
	self emitMain.
	^ builder module serialize
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> countOf: anOpcode in: aCountDictionary [
	"Zero where the opcode is absent: a report saying none is better than a report that
	 raises when the kernel stops emitting an instruction."

	^ (aCountDictionary at: anOpcode ifAbsent: [ 0 ]) printString
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> declareBuffers [
	"Three bindings: the two inputs hold halves and the accumulator holds floats. The types
	 behind one element type are declared once and reused, because ArrayStride on the same
	 runtime array twice is invalid SPIR-V, and the two half bindings share that array."

	| pointerTypes |
	pointerTypes := Dictionary new.
	bufferVariables := Dictionary new.
	self class bufferBindings do: [ :binding |
		| bufferType |
		bufferType := self bufferTypeOfBinding: binding.
		bufferVariables
			at: binding
			put: (self
					 newBufferVariableOfPointerType:
					 (pointerTypes
						  at: bufferType
						  ifAbsentPut: [ self newDecoratedBlockPointerFor: bufferType ])
					 binding: binding) ]
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> declareCapabilities [
	"Five capabilities and one extension. CooperativeMatrixKHR needs the extension named and
	 VulkanMemoryModel declared beside it, which in turn means the module must name the
	 Vulkan memory model rather than the GLSL450 one the other kernels of this project use.
	 Float16 and the 16-bit storage access cover the half precision inputs."

	builder addCapability: self class shaderCapability.
	builder addCapability: PVSPIRVEmitter float16Capability.
	builder addCapability: PVSPIRVEmitter storageBuffer16BitAccessCapability.
	builder addCapability: PVSPIRVEmitter vulkanMemoryModelCapability.
	builder addCapability: PVSPIRVEmitter cooperativeMatrixCapability.
	builder module addExtension:
		PVSPIRVEmitter cooperativeMatrixExtensionName.
	builder
		setMemoryModel: SpvModule logicalAddressingModel
		memoryModel: SpvModule vulkanMemoryModel
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> emitMain [
	"One block: no control flow at all, because every invocation of the subgroup has to reach
	 each cooperative matrix instruction. The accumulator is read from the output binding and
	 the result written back to it, so the host decides what the product is added to."

	| function block stride pointers matrices result |
	function := builder newFunction: self voidType.
	builder
		addEntryPoint: function
		executionModel: SpvExecutionModel glCompute
		name: self class entryPointName
		interfaces: self interfaceVariables.
	builder
		addExecutionMode: function
		mode: SpvExecutionMode localSize
		literals: self class localSize.
	block := function addBlock.
	builder currentBlock: block.
	stride := builder constants constantUInt32: self class matrixOrder.
	pointers := self class bufferBindings collect: [ :each |
		            self firstElementPointerOfBinding: each ].
	matrices := self matrixUses with: pointers collect: [ :use :pointer |
		            builder
			            emitCooperativeMatrixLoad: pointer
			            type: (self matrixTypeFor: use)
			            layout: SpvCooperativeMatrixType rowMajorLayout
			            stride: stride ].
	result := builder
		          emitCooperativeMatrixMulAdd: matrices first
		          by: (matrices at: 2)
		          into: matrices last
		          type:
		          (self matrixTypeFor: SpvCooperativeMatrixType matrixAccumulatorUse).
	builder
		emitCooperativeMatrixStore: result
		at: (self firstElementPointerOfBinding: self class outputBinding)
		layout: SpvCooperativeMatrixType rowMajorLayout
		stride: stride.
	builder emitReturn
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> firstElementPointerOfBinding: anInteger [
	"A cooperative matrix load takes a pointer to the first element it reads, and a binding
	 is a struct holding one runtime array, so the chain goes through the member index and
	 then element zero."

	| variable |
	variable := bufferVariables at: anInteger.
	^ builder
		  emitAccessChain: variable id
		  type: (builder types
				   pointerType: SpvStorageClass storageBuffer
				   type: (self scalarTypeFor: (self bufferTypeOfBinding: anInteger)))
		  indices: {
				  (builder constants constantUInt32:
					   PVSPIRVEmitter bufferMemberIndex).
				  (builder constants constantUInt32: self class firstElementIndex) }
]

{ #category : 'inspector' }
PVCooperativeMatrixKernel >> inspectorModule: aBuilder [
	"What the bytes hold, walked out of the module rather than restated, so the tab cannot
	 claim an instruction the build stopped emitting."

	<inspectorPresentationOrder: 10 title: 'Module'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Quantity' evaluated: [ :each |
					   each at: #name ]);
		  addColumn:
			  (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each at: #value ]);
		  items: self reportRows;
		  yourself
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> interfaceVariables [
	"SPIR-V 1.4 onwards wants every module-scope variable the entry point touches named in
	 its interface list. This kernel reads no built-in: one tile sits at the start of each
	 buffer, so no invocation needs to know where it is."

	^ self class bufferBindings collect: [ :each | bufferVariables at: each ]
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> localSizeDescription [
	^ ''  join: ((self class localSize collect: [ :each | each printString ])
		   inject: OrderedCollection new
		   into: [ :acc :each |
			   acc isEmpty ifFalse: [ acc add: ' x ' ].
			   acc add: each.
			   acc ])
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> matrixTypeFor: aUse [
	"A, B and the accumulator are three distinct types: the inputs hold halves and the
	 accumulator holds floats, which is the combination lavapipe reports, and the Use operand
	 separates them even where the component type agrees."

	^ builder types
		  cooperativeMatrixType: (self scalarTypeFor: (self bufferTypeForUse: aUse))
		  shape: (SpvCooperativeMatrixShape
				   rows: self class matrixOrder
				   columns: self class matrixOrder
				   scope: self class subgroupScope
				   use: aUse)
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> matrixUses [
	"The three roles, in the order the bindings are declared: the left input is A, the right
	 input is B, and the output binding carries the accumulator."

	^ {
		  SpvCooperativeMatrixType matrixAUse.
		  SpvCooperativeMatrixType matrixBUse.
		  SpvCooperativeMatrixType matrixAccumulatorUse }
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> memoryModelDescription [
	"The model the module names, compared against the constant rather than printed raw, so
	 the row says Vulkan only while the module really asks for it."

	^ self module memoryModel = SpvModule vulkanMemoryModel
		  ifTrue: [ 'Vulkan' ]
		  ifFalse: [ self module memoryModel printString ]
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> module [
	"The module behind the bytes. Building the bytes is what builds it, so the bytes are
	 asked for first."

	self spirv.
	^ builder module
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> newBufferVariableOfPointerType: aPointerType binding: anInteger [
	"One storage buffer variable at that binding of the single descriptor set this project's
	 compute pipelines use."

	| variable |
	variable := builder
		            addGlobalVariable: aPointerType
		            storageClass: SpvStorageClass storageBuffer.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration descriptorSet
		literals: { PVSPIRVEmitter computeDescriptorSet }.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration bindingDecoration
		literals: { anInteger }.
	^ variable
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> newDecoratedBlockPointerFor: aBufferTypeSymbol [
	"A runtime array of the element type inside a Block-decorated struct, with the stride and
	 the member offset a storage buffer needs, and a pointer to the struct. Called once per
	 element type: each decoration may be given once."

	| arrayType structType |
	arrayType := builder types runtimeArrayType:
		             (self scalarTypeFor: aBufferTypeSymbol).
	structType := builder types structType: { arrayType }.
	builder module
		addDecoration: arrayType id
		decoration: SpvDecoration arrayStride
		literals:
		{ (PVSPIRVEmitter storageBufferArrayStrideFor: aBufferTypeSymbol) }.
	builder module
		addDecoration: structType id
		decoration: SpvDecoration block
		literals: #( ).
	builder module
		addMemberDecoration: structType id
		member: PVSPIRVEmitter bufferMemberIndex
		decoration: SpvDecoration offset
		literals: { PVSPIRVEmitter bufferMemberOffset }.
	^ builder types
		  pointerType: SpvStorageClass storageBuffer
		  type: structType
]

{ #category : 'reporting' }
PVCooperativeMatrixKernel >> opcodeCounts [
	"Opcodes counted by walking the serialised words, so the report cannot claim an
	 instruction the build stopped emitting. A SPIR-V instruction carries its word count in
	 the high half of its first word."

	| words counts index |
	words := (1 to: self spirv size by: 4) collect: [ :each |
		         (self spirv at: each) + ((self spirv at: each + 1) bitShift: 8)
		         + ((self spirv at: each + 2) bitShift: 16)
		         + ((self spirv at: each + 3) bitShift: 24) ].
	counts := Dictionary new.
	index := self class moduleHeaderWordCount + 1.
	[ index <= words size ] whileTrue: [
		| word wordCount opcode |
		word := words at: index.
		wordCount := word bitShift: -16.
		opcode := word bitAnd: 16rFFFF.
		counts at: opcode put: (counts at: opcode ifAbsent: [ 0 ]) + 1.
		index := index + wordCount ].
	^ counts
]

{ #category : 'dispatching' }
PVCooperativeMatrixKernel >> productOf: aFlatLeftMatrix by: aFlatRightMatrix on: aContext [
	"Dispatch this module over one tile on a context whose device offers cooperative matrix,
	 and answer the product as floats. Both inputs are written as halves, which is the
	 component type the reported shape names for A and B; the accumulator starts at zero, so
	 what comes back is the product and not a running sum. One workgroup, because the
	 matrices are held across a single subgroup."

	^ self
		  productOf: aFlatLeftMatrix
		  by: aFlatRightMatrix
		  on: aContext
		  spirv: self spirv
]

{ #category : 'dispatching' }
PVCooperativeMatrixKernel >> productOf: aFlatLeftMatrix by: aFlatRightMatrix on: aContext spirv: aByteArray [
	"The dispatch of productOf:by:on:, over a module the caller names. The module the DSL
	 compiles from PVKernelExamples >> #coopMatrixProductOf:by:into: takes the same three
	 bindings over the same one workgroup, so one dispatch serves both and the comparison
	 between them measures the modules rather than two host paths."

	| elementCount left right output kernel |
	elementCount := self class elementCount.
	left := VkBuffer
		        storageBuffer: elementCount
		        of: #f16
		        on: aContext device.
	right := VkBuffer
		         storageBuffer: elementCount
		         of: #f16
		         on: aContext device.
	output := VkBuffer
		          storageBuffer: elementCount
		          of: #f32
		          on: aContext device.
	kernel := PVComputeKernel on: aContext spirv: aByteArray.
	^ [
	  left put: aFlatLeftMatrix as: #f16.
	  right put: aFlatRightMatrix as: #f16.
	  output put: (Array new: elementCount withAll: 0.0) as: #f32.
	  { left. right. output } do: [ :each | kernel bindBuffer: each ].
	  kernel prepare.
	  kernel dispatch: 1 y: 1 z: 1.
	  output elementsAs: #f32 ] ensure: [
		  kernel destroy.
		  left destroy.
		  right destroy.
		  output destroy ]
]

{ #category : 'reporting' }
PVCooperativeMatrixKernel >> reportRows [
	"What the built module actually declares, read back out of it rather than restated: the
	 capabilities come from the module, the instruction counts from the serialised words, and
	 the shape from the constants the type names."

	| counts |
	counts := self opcodeCounts.
	^ {
		  (self rowNamed: 'Shape' value: self shapeDescription).
		  (self rowNamed: 'Scope' value: (VkScope nameOf: self class subgroupScope)).
		  (self rowNamed: 'Local size' value: self localSizeDescription).
		  (self
			   rowNamed: 'Capabilities'
			   value: self module capabilities asArray printString).
		  (self
			   rowNamed: 'Extensions'
			   value: self module extensions asArray printString).
		  (self rowNamed: 'Memory model' value: self memoryModelDescription).
		  (self
			   rowNamed: 'Matrix types'
			   value: (self countOf: SpvOpcode opTypeCooperativeMatrixKHR in: counts)).
		  (self
			   rowNamed: 'Loads'
			   value: (self countOf: SpvOpcode opCooperativeMatrixLoadKHR in: counts)).
		  (self
			   rowNamed: 'Multiply-accumulates'
			   value: (self countOf: SpvOpcode opCooperativeMatrixMulAddKHR in: counts)).
		  (self
			   rowNamed: 'Stores'
			   value: (self countOf: SpvOpcode opCooperativeMatrixStoreKHR in: counts)).
		  (self rowNamed: 'Module bytes' value: self spirv size printString) }
]

{ #category : 'reporting' }
PVCooperativeMatrixKernel >> rowNamed: aString value: aValueString [
	"Read only: opening the tab must not change the kernel."

	^ (Dictionary newFrom: {
			   (#name -> aString).
			   (#value -> aValueString) }) beReadOnlyObject
]

{ #category : 'building' }
PVCooperativeMatrixKernel >> scalarTypeFor: aBufferTypeSymbol [
	"The SPIR-V scalar type one element of that buffer holds. This kernel multiplies floats,
	 so an integer element type is refused rather than silently read as a float of the same
	 width."

	| elementType |
	elementType := PVSPIRVEmitter elementTypeOf: aBufferTypeSymbol.
	^ builder types floatType:
		  (self class floatBitWidths at: elementType ifAbsent: [
			   PVTypeError signal:
				   'Cooperative matrix kernel takes float buffers only, not: '
				   , elementType ])
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> shapeDescription [
	"M, N and K as the device reports them, asked of the constants the kernel uses."

	^ 'M' , self class matrixOrder printString , ' N'
	  , self class matrixOrder printString , ' K'
	  , self class matrixOrder printString , ', f16 x f16 into f32'
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> spirv [
	"The module bytes, built once per instance: the build allocates result ids from one
	 counter, so it is a fresh builder each time or nothing."

	^ spirv ifNil: [ spirv := self buildSpirv ]
]

{ #category : 'accessing' }
PVCooperativeMatrixKernel >> voidType [
	^ builder types voidType
]
