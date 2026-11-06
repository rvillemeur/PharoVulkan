"
Hand-built SPIR-V for a tiled matmul: each workgroup copies one tile of each input matrix into Workgroup storage, barriers, accumulates the tile product from shared memory, barriers again, and moves on to the next tile. The module is assembled through SpvBuilder rather than compiled from a Pharo method, because the structured control flow recogniser handles one loop per kernel while this kernel nests an accumulation loop inside a tile loop; Phase 7 item 7-G measures the kernel first and only then decides whether that shape earns a place in the recogniser.

It takes the matrix order from the dispatch grid, exactly as the naive matmul does, so the grid must cover the matrix: order divided by tileWidth groups along x and the same along y. Buffers bind in the order a, b, output. Key methods: spirv, sharedMemoryBytes, localSize, reportRows.
"
Class {
	#name : 'PVTiledMatmulKernel',
	#superclass : 'Object',
	#instVars : [
		'spirv',
		'builder',
		'builtInVariables',
		'bufferVariables',
		'tileVariables'
	],
	#category : 'PharoVulkan-Compute-Kernels',
	#package : 'PharoVulkan-Compute',
	#tag : 'Kernels'
}

{ #category : 'constants' }
PVTiledMatmulKernel class >> bufferBindings [
	"The descriptor bindings, in the order the host binds its buffers: the two input
	 matrices and then the output."

	^ #( 0 1 2 )
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> bufferElementType [
	"Float throughout, because the kernel is measured against the float baseline of 7-C. The
	 symbol is the compiler's buffer type name, so the array stride comes from the same
	 table the compiled kernels use."

	^ #bufferOf_f32
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> builtIns [
	"Every built-in the kernel reads, in the order it declares them. The entry point has to
	 list all three, so one list serves both the declarations and the interface."

	^ {
		  SpvBuiltIn globalInvocationId.
		  SpvBuiltIn localInvocationId.
		  SpvBuiltIn numWorkgroups }
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> columnComponent [
	"The component read as a matrix column, the sibling of rowComponent."

	^ 1
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> entryPointName [
	"The name every compute entry point of this project carries, and the one the pipeline
	 asks the shader module for."

	^ 'main'
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> rowComponent [
	"The invocation id component the kernel reads as a matrix row. The naive matmul reads x
	 as its row, and the two kernels have to fill the output buffer the same way for either
	 to be checked against the other."

	^ 0
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> shaderCapability [
	"The serializer maps this symbol to the Shader capability number, so the module names
	 the capability rather than repeating its value."

	^ #Shader
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> tileCount [
	"One tile of the left matrix and one of the right. Shared memory is sized from this, so
	 a third tile cannot be added without the size following it."

	^ 2
]

{ #category : 'constants' }
PVTiledMatmulKernel class >> tileWidth [
	"The side of the square tile a workgroup cooperates on, and so also the workgroup
	 width along both axes: one invocation fills one slot of each tile. Sixteen keeps the
	 workgroup at 256 invocations and the tile pair at two kibibytes, well inside both the
	 invocation and the shared memory limits this device reports."

	^ 16
]

{ #category : 'emitting' }
PVTiledMatmulKernel >> add: aLeftId to: aRightId [
	"Unsigned addition: every index in this kernel comes from a built-in invocation id."

	^ builder
		  emitBinaryOp: SpvOpcode opIAdd
		  left: aLeftId
		  right: aRightId
		  type: self u32Type
]

{ #category : 'types' }
PVTiledMatmulKernel >> boolType [
	^ builder types boolType
]

{ #category : 'building' }
PVTiledMatmulKernel >> buildSpirv [
	"Assemble the module. The built-ins, the buffers and the shared tiles are declared
	 before the function, because a definition has to precede every use of its id."

	builder := SpvBuilder new.
	builder module addCapability: self class shaderCapability.
	self declareBuiltIns.
	self declareBuffers.
	self declareSharedTiles.
	self emitMain.
	^ builder module serialize
]

{ #category : 'building' }
PVTiledMatmulKernel >> declareBuffers [
	"Three Block-decorated structs, each holding one runtime array of floats. The type
	 registry hands back the same array and struct for all three bindings, and a type
	 carries each decoration once, so the type is decorated here and the variables are
	 decorated one by one."

	| arrayType structType pointerType |
	arrayType := builder types runtimeArrayType: self f32Type.
	structType := builder types structType: { arrayType }.
	pointerType := builder types
		               pointerType: SpvStorageClass storageBuffer
		               type: structType.
	builder module
		addDecoration: arrayType id
		decoration: SpvDecoration arrayStride
		literals:
		{ (PVSPIRVEmitter storageBufferArrayStrideFor: self class bufferElementType) }.
	builder module
		addDecoration: structType id
		decoration: SpvDecoration block
		literals: #( ).
	builder module
		addMemberDecoration: structType id
		member: PVSPIRVEmitter bufferMemberIndex
		decoration: SpvDecoration offset
		literals: { PVSPIRVEmitter bufferMemberOffset }.
	bufferVariables := self class bufferBindings collect: [ :each |
		                   self newBufferVariableOfType: pointerType binding: each ]
]

{ #category : 'building' }
PVTiledMatmulKernel >> declareBuiltIns [
	"Three built-ins: where the invocation sits in the whole dispatch, where it sits in its
	 own workgroup, and how many workgroups there are. The last one carries the matrix
	 order, exactly as it does for the naive kernel. They are kept by built-in number, so a
	 reader of the module and a reader of this class name the same thing."

	builtInVariables := Dictionary new.
	self class builtIns do: [ :each |
		builtInVariables at: each put: (self newBuiltInVariable: each) ]
]

{ #category : 'building' }
PVTiledMatmulKernel >> declareSharedTiles [
	"One tile per input matrix, in the Workgroup storage class: the memory a workgroup
	 shares. The tile is a fixed-size array, whose length operand is the id of a constant,
	 which is why the array type declares that constant as it is created."

	| arrayType pointerType |
	arrayType := builder types
		             arrayType: self f32Type
		             length: self tileElementCount.
	pointerType := builder types
		               pointerType: SpvStorageClass workgroup
		               type: arrayType.
	tileVariables := (1 to: self class tileCount) collect: [ :each |
		                 builder
			                 addGlobalVariable: pointerType
			                 storageClass: SpvStorageClass workgroup ]
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitEntryBlockIn: blocks [
	"Everything that does not change from tile to tile: where this invocation sits in the
	 dispatch and in its workgroup, the matrix order the grid implies, and the flat indices
	 built from them. Row comes from x and column from y, the mapping the naive matmul uses."

	| values globalId localId groups tileWidthConstant |
	builder currentBlock: (blocks at: #entry).
	values := Dictionary new.
	tileWidthConstant := builder constants constantUInt32: self tileWidth.
	globalId := builder emitLoad: self globalIdVariable id type: self uvec3Type.
	localId := builder emitLoad: self localIdVariable id type: self uvec3Type.
	groups := builder
		          emitLoad: self numWorkgroupsVariable id
		          type: self uvec3Type.
	values
		at: #row put: (self extract: self class rowComponent from: globalId);
		at: #column put: (self extract: self class columnComponent from: globalId);
		at: #localRow put: (self extract: self class rowComponent from: localId);
		at: #localColumn
		put: (self extract: self class columnComponent from: localId).
	values
		at: #order
		put: (self
				 multiply: (self extract: self class rowComponent from: groups)
				 by: tileWidthConstant).
	values
		at: #tileRowBase
		put: (self multiply: (values at: #localRow) by: tileWidthConstant).
	values
		at: #slotIndex
		put: (self add: (values at: #tileRowBase) to: (values at: #localColumn)).
	values
		at: #rowBase
		put: (self multiply: (values at: #row) by: (values at: #order)).
	values
		at: #outputIndex
		put: (self add: (values at: #rowBase) to: (values at: #column)).
	builder emitBranch: (blocks at: #outerHeader) id.
	^ values
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitInnerBodyIn: blocks values: values [
	"One term of the dot product, both factors read from shared memory. This is the whole
	 point of the tiling: the naive kernel reads both factors from the storage buffers."

	| block product |
	block := blocks at: #innerBody.
	builder currentBlock: block.
	product := builder
		           emitBinaryOp: SpvOpcode opFMul
		           left: (self
				            loadFromTile: self leftTile
				            slot:
				            (self
					             add: (values at: #tileRowBase)
					             to: (values at: #innerIndex)))
		           right: (self
				            loadFromTile: self rightTile
				            slot: (self
						             add: (self
								              multiply: (values at: #innerIndex)
								              by:
								              (builder constants constantUInt32: self tileWidth))
						             to: (values at: #localColumn)))
		           type: self f32Type.
	values
		at: #nextInnerAccumulator
		put: (builder
				 emitBinaryOp: SpvOpcode opFAdd
				 left: (values at: #innerAccumulator)
				 right: product
				 type: self f32Type).
	builder emitBranch: (blocks at: #innerLatch) id
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitInnerHeaderIn: blocks values: values [
	"The accumulation loop over one tile. It runs tileWidth times, the same count in every
	 lane, which is what lets the barriers around it be reached by the whole workgroup."

	| block condition |
	block := blocks at: #innerHeader.
	builder currentBlock: block.
	values
		at: #innerIndex put: builder module newId;
		at: #innerAccumulator put: builder module newId.
	condition := builder
		             emitBinaryOp: SpvOpcode opULessThan
		             left: (values at: #innerIndex)
		             right: (builder constants constantUInt32: self tileWidth)
		             type: self boolType.
	block addInstruction: (SpvInstruction
			 opcode: SpvOpcode opLoopMerge
			 operands: {
					 (blocks at: #innerMerge) id.
					 (blocks at: #innerLatch) id.
					 SpvLoopControl none }).
	block terminate: (SpvInstruction
			 opcode: SpvOpcode opBranchConditional
			 operands: {
					 condition.
					 (blocks at: #innerBody) id.
					 (blocks at: #innerMerge) id })
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitLatchesIn: blocks values: values [
	"The two latches and the inner merge. The barrier in the inner merge is the one without
	 which a lane that has finished the tile could overwrite a slot a slower lane of the
	 same workgroup has not read yet."

	builder currentBlock: (blocks at: #innerLatch).
	values
		at: #nextInnerIndex
		put: (self
				 add: (values at: #innerIndex)
				 to: (builder constants constantUInt32: 1)).
	builder emitBranch: (blocks at: #innerHeader) id.
	builder currentBlock: (blocks at: #innerMerge).
	(blocks at: #innerMerge) addInstruction: builder workgroupBarrier.
	builder emitBranch: (blocks at: #outerLatch) id.
	builder currentBlock: (blocks at: #outerLatch).
	values
		at: #nextTileBase
		put: (self
				 add: (values at: #tileBase)
				 to: (builder constants constantUInt32: self tileWidth)).
	builder emitBranch: (blocks at: #outerHeader) id
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitMain [
	"The entry point and its nine blocks. The phis come last, because a phi names a value
	 from each predecessor and the latch values only exist once the bodies are emitted."

	| function blocks values |
	function := builder newFunction: self voidType.
	builder
		addEntryPoint: function
		executionModel: SpvExecutionModel glCompute
		name: self class entryPointName
		interfaces: self interfaceVariables.
	builder
		addExecutionMode: function
		mode: SpvExecutionMode localSize
		literals: self localSize.
	blocks := self newBlocksFor: function.
	values := self emitEntryBlockIn: blocks.
	self emitOuterHeaderIn: blocks values: values.
	self emitOuterBodyIn: blocks values: values.
	self emitInnerHeaderIn: blocks values: values.
	self emitInnerBodyIn: blocks values: values.
	self emitLatchesIn: blocks values: values.
	self emitOuterMergeIn: blocks values: values.
	self emitPhisIn: blocks values: values
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitOuterBodyIn: blocks values: values [
	"The cooperative copy. Each invocation brings one element of each matrix into shared
	 memory, and the barrier is what makes the whole tile visible to every lane of the
	 workgroup before any lane reads a slot a neighbour filled."

	| block leftIndex rightRow rightIndex |
	block := blocks at: #outerBody.
	builder currentBlock: block.
	leftIndex := self
		             add: (self add: (values at: #rowBase) to: (values at: #tileBase))
		             to: (values at: #localColumn).
	self
		storeToTile: self leftTile
		slot: (values at: #slotIndex)
		value: (self loadBufferElement: self leftBuffer index: leftIndex).
	rightRow := self add: (values at: #tileBase) to: (values at: #localRow).
	rightIndex := self
		              add: (self multiply: rightRow by: (values at: #order))
		              to: (values at: #column).
	self
		storeToTile: self rightTile
		slot: (values at: #slotIndex)
		value: (self loadBufferElement: self rightBuffer index: rightIndex).
	block addInstruction: builder workgroupBarrier.
	builder emitBranch: (blocks at: #innerHeader) id
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitOuterHeaderIn: blocks values: values [
	"The tile loop. Its two phis, the tile the workgroup is on and the dot product so far,
	 have their ids reserved here and their operands filled in by emitPhisIn:values:."

	| block condition |
	block := blocks at: #outerHeader.
	builder currentBlock: block.
	values
		at: #tileBase put: builder module newId;
		at: #accumulator put: builder module newId.
	condition := builder
		             emitBinaryOp: SpvOpcode opULessThan
		             left: (values at: #tileBase)
		             right: (values at: #order)
		             type: self boolType.
	block addInstruction: (SpvInstruction
			 opcode: SpvOpcode opLoopMerge
			 operands: {
					 (blocks at: #outerMerge) id.
					 (blocks at: #outerLatch) id.
					 SpvLoopControl none }).
	block terminate: (SpvInstruction
			 opcode: SpvOpcode opBranchConditional
			 operands: {
					 condition.
					 (blocks at: #outerBody) id.
					 (blocks at: #outerMerge) id })
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitOuterMergeIn: blocks values: values [
	"One store per invocation, of the dot product the tile loop finished. The value is the
	 tile loop's own phi, which holds the total of every tile once the loop exits."

	builder currentBlock: (blocks at: #outerMerge).
	builder
		emitStore: (values at: #accumulator)
		at: (builder
				 emitAccessChain: self outputBuffer id
				 type: self storageBufferPointerType
				 indices: {
						 (builder constants constantUInt32:
							  PVSPIRVEmitter bufferMemberIndex).
						 (values at: #outputIndex) }).
	builder emitReturn
]

{ #category : 'building' }
PVTiledMatmulKernel >> emitPhisIn: blocks values: values [
	"The four loop phis, prepended once every block that feeds them exists. A phi names one
	 value per predecessor, and SPIR-V wants the phis first in their block."

	self
		prependPhiTo: (blocks at: #outerHeader)
		resultId: (values at: #accumulator)
		type: self f32Type
		operands: {
				(builder constants constantFloat32: 0.0).
				(blocks at: #entry) id.
				(values at: #innerAccumulator).
				(blocks at: #outerLatch) id }.
	self
		prependPhiTo: (blocks at: #outerHeader)
		resultId: (values at: #tileBase)
		type: self u32Type
		operands: {
				(builder constants constantUInt32: 0).
				(blocks at: #entry) id.
				(values at: #nextTileBase).
				(blocks at: #outerLatch) id }.
	self
		prependPhiTo: (blocks at: #innerHeader)
		resultId: (values at: #innerAccumulator)
		type: self f32Type
		operands: {
				(values at: #accumulator).
				(blocks at: #outerBody) id.
				(values at: #nextInnerAccumulator).
				(blocks at: #innerLatch) id }.
	self
		prependPhiTo: (blocks at: #innerHeader)
		resultId: (values at: #innerIndex)
		type: self u32Type
		operands: {
				(builder constants constantUInt32: 0).
				(blocks at: #outerBody) id.
				(values at: #nextInnerIndex).
				(blocks at: #innerLatch) id }
]

{ #category : 'emitting' }
PVTiledMatmulKernel >> extract: aComponent from: aVectorId [
	^ builder
		  emitCompositeExtract: aVectorId
		  type: self u32Type
		  indices: { aComponent }
]

{ #category : 'types' }
PVTiledMatmulKernel >> f32Type [
	^ builder types floatType: 32
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> globalIdVariable [
	"Where this invocation sits in the whole dispatch: its matrix row and column."

	^ builtInVariables at: SpvBuiltIn globalInvocationId
]

{ #category : 'inspector' }
PVTiledMatmulKernel >> inspectorModule: aBuilder [
	"What the bytes hold. The counts come from walking the module, so the tab cannot claim
	 a barrier the kernel stopped emitting."

	<inspectorPresentationOrder: 10 title: 'Module'>
	^ PVFactRow
		  tableOf: self reportRows
		  nameColumn: 'Quantity'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'building' }
PVTiledMatmulKernel >> interfaceVariables [
	"SPIR-V 1.4 onwards wants every module-scope variable the entry point touches named in
	 its interface list, the shared tiles included."

	^ (self class builtIns collect: [ :each | builtInVariables at: each ])
	  , bufferVariables , tileVariables
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> leftBuffer [
	"The binding holding the left matrix."

	^ bufferVariables first
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> leftTile [
	"The shared tile of the left matrix."

	^ tileVariables first
]

{ #category : 'emitting' }
PVTiledMatmulKernel >> loadBufferElement: aVariable index: anIndexId [
	"A buffer binding is a struct holding one runtime array, so the element sits behind the
	 member index and then the element index."

	^ builder
		  emitLoad: (builder
				   emitAccessChain: aVariable id
				   type: self storageBufferPointerType
				   indices: {
						   (builder constants constantUInt32:
							    PVSPIRVEmitter bufferMemberIndex).
						   anIndexId })
		  type: self f32Type
]

{ #category : 'emitting' }
PVTiledMatmulKernel >> loadFromTile: aVariable slot: aSlotId [
	^ builder
		  emitLoad: (builder
				   emitAccessChain: aVariable id
				   type: self workgroupPointerType
				   indices: { aSlotId })
		  type: self f32Type
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> localIdVariable [
	"Where this invocation sits in its own workgroup: the tile slot it fills."

	^ builtInVariables at: SpvBuiltIn localInvocationId
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> localSize [
	"One invocation per tile slot, which is what makes the tile copy a single store per
	 invocation."

	^ {
		  self tileWidth.
		  self tileWidth.
		  1 }
]

{ #category : 'emitting' }
PVTiledMatmulKernel >> multiply: aLeftId by: aRightId [
	^ builder
		  emitBinaryOp: SpvOpcode opIMul
		  left: aLeftId
		  right: aRightId
		  type: self u32Type
]

{ #category : 'building' }
PVTiledMatmulKernel >> newBlocksFor: aFunction [
	"The blocks in the order SPIR-V asks for, where a block precedes every block it
	 dominates: entry, the tile loop, the accumulation loop nested inside it, then the
	 latches and the merges."

	^ Dictionary newFrom: (#( #entry #outerHeader #outerBody #innerHeader
		   #innerBody #innerLatch #innerMerge #outerLatch #outerMerge ) collect: [
			   :each | each -> aFunction addBlock ])
]

{ #category : 'building' }
PVTiledMatmulKernel >> newBufferVariableOfType: aPointerType binding: anInteger [
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
PVTiledMatmulKernel >> newBuiltInVariable: aBuiltIn [
	| variable |
	variable := builder
		            addGlobalVariable:
		            (builder types pointerType: SpvStorageClass input type: self uvec3Type)
		            storageClass: SpvStorageClass input.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration builtIn
		literals: { aBuiltIn }.
	^ variable
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> numWorkgroupsVariable [
	"The grid, which is where the matrix order comes from."

	^ builtInVariables at: SpvBuiltIn numWorkgroups
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> outputBuffer [
	^ bufferVariables third
]

{ #category : 'emitting' }
PVTiledMatmulKernel >> prependPhiTo: aBlock resultId: anId type: aType operands: anArray [
	aBlock prependInstruction: (SpvInstruction
			 opcode: SpvOpcode opPhi
			 resultType: aType id
			 resultId: anId
			 operands: anArray)
]

{ #category : 'reporting' }
PVTiledMatmulKernel >> reportRows [
	"One row per fact about the module, every one of them asked of the emitted bytes rather
	 than restated here: a tile that stopped being shared, or a barrier that was dropped,
	 shows up in this table."

	| module |
	module := PVSpirvValidator on: self spirv.
	^ {
		  (PVFactRow name: 'Tile width' value: self tileWidth).
		  (PVFactRow
			   name: 'Workgroup'
			   value: ((self localSize collect: [ :each | each printString ])
					    inject: ''
					    into: [ :all :each |
							    all isEmpty
								    ifTrue: [ each ]
								    ifFalse: [ all , ' by ' , each ] ])).
		  (PVFactRow
			   name: 'Shared memory bytes per group'
			   value: self sharedMemoryBytes).
		  (PVFactRow
			   name: 'Shared tiles in the module'
			   value:
			   (module variableCountInStorageClass: SpvStorageClass workgroup)).
		  (PVFactRow
			   name: 'Buffer bindings in the module'
			   value:
			   (module variableCountInStorageClass:
				    SpvStorageClass storageBuffer)).
		  (PVFactRow
			   name: 'Barriers'
			   value: (module countOfOpcode: SpvOpcode opControlBarrier)).
		  (PVFactRow
			   name: 'Loops'
			   value: (module countOfOpcode: SpvOpcode opLoopMerge)).
		  (PVFactRow name: 'Module bytes' value: self spirv size).
		  (PVFactRow name: 'spirv-val' value: (PVSpirvValidator isAvailable
				    ifTrue: [
						    module isValid
							    ifTrue: [ 'valid' ]
							    ifFalse: [ module validationOutput ] ]
				    ifFalse: [ 'not installed' ])) }
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> rightBuffer [
	^ bufferVariables second
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> rightTile [
	^ tileVariables second
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> sharedMemoryBytes [
	"What one workgroup of this kernel asks of the device's shared memory. The element
	 width comes from the compiler's own stride table, so the figure follows the buffer
	 type rather than being restated here."

	^ self class tileCount * self tileElementCount
	  * (PVSPIRVEmitter storageBufferArrayStrideFor: self class bufferElementType)
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> spirv [
	"The module bytes, built once per instance: the build allocates result ids from one
	 counter, so it is a fresh builder each time or nothing."

	^ spirv ifNil: [ spirv := self buildSpirv ]
]

{ #category : 'types' }
PVTiledMatmulKernel >> storageBufferPointerType [
	"A pointer to one float of a storage buffer, which is what an access chain into a
	 binding answers."

	^ builder types pointerType: SpvStorageClass storageBuffer type: self f32Type
]

{ #category : 'emitting' }
PVTiledMatmulKernel >> storeToTile: aVariable slot: aSlotId value: aValueId [
	"A tile is a flat array of tileWidth squared floats, indexed row-major like the
	 matrices it holds a piece of."

	builder
		emitStore: aValueId
		at: (builder
				 emitAccessChain: aVariable id
				 type: self workgroupPointerType
				 indices: { aSlotId })
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> tileElementCount [
	^ self tileWidth * self tileWidth
]

{ #category : 'accessing' }
PVTiledMatmulKernel >> tileWidth [
	^ self class tileWidth
]

{ #category : 'types' }
PVTiledMatmulKernel >> u32Type [
	"The registry deduplicates, so asking it for a type each time it is needed costs one
	 dictionary lookup and cannot drift from the type the rest of the module uses."

	^ builder types intType: 32 signed: false
]

{ #category : 'types' }
PVTiledMatmulKernel >> uvec3Type [
	"The shape of every invocation built-in this kernel reads."

	^ builder types vectorType: self u32Type count: 3
]

{ #category : 'types' }
PVTiledMatmulKernel >> voidType [
	^ builder types voidType
]

{ #category : 'types' }
PVTiledMatmulKernel >> workgroupPointerType [
	"A pointer to one float of a shared tile."

	^ builder types pointerType: SpvStorageClass workgroup type: self f32Type
]
