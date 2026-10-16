"
The part of a hello-triangle scene that does not care where the picture ends up: the context, the render pass it was given, a command pool and buffer, the two shader modules, the graphics pipeline and the vertex buffer. `PVHelloTriangleScene` adds a surface, a swapchain and frame synchronisation and presents to a window; `PVOffscreenTriangleScene` renders into a `PVOffscreenTarget` whose pixels can be asserted.

Subclasses build their own render pass first, because a window needs the swapchain's format and an offscreen target needs the copy-out layout, then send `initializeCtx:renderPass:extent:`. `destroy` releases the drawing objects in reverse creation order and calls `destroyPresentation` first, which is the hook a subclass overrides for whatever it owns in front of them. `lifecycleReport` and the Lifecycle inspector tab reflect over every slot, inherited ones included, so an owned object added later cannot be left out.
"
Class {
	#name : 'PVTriangleScene',
	#superclass : 'Object',
	#instVars : [
		'ctx',
		'renderPass',
		'commandPool',
		'commandBuffer',
		'vertexShaderModule',
		'fragmentShaderModule',
		'pipeline',
		'vertexBuffer'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'constants' }
PVTriangleScene class >> bytesPerFloat [
	"The vertex attributes are 32-bit floats, as the pipeline's vertex input declares."

	^ 4
]

{ #category : 'constants' }
PVTriangleScene class >> floatsPerVertex [
	"x and y in clip space, then r, g and b."

	^ 5
]

{ #category : 'constants' }
PVTriangleScene class >> liveLabel [
	^ 'live'
]

{ #category : 'constants' }
PVTriangleScene class >> releasedLabel [
	^ 'released'
]

{ #category : 'constants' }
PVTriangleScene class >> unownedSlotNames [
	"Slots the scene reads but does not destroy. The context outlives the scene: the
	 caller that created it destroys it, and destroy only waits on its queue."

	^ #( #ctx )
]

{ #category : 'constants' }
PVTriangleScene class >> vertexCount [
	^ 3
]

{ #category : 'constants' }
PVTriangleScene class >> vertexDataSize [
	"Three vertices of five floats each: x, y, r, g, b."

	^ self vertexCount * self floatsPerVertex * self bytesPerFloat
]

{ #category : 'private' }
PVTriangleScene >> buildFragmentShader [
    | mod tr cp f32 vec3 vec4 pInVec3 pOutVec4 voidType funcType inColor outColor one32 fn blk colorValId rId gId bId outVec4Id |
    mod := SpvModule new initialize.
    mod addCapability: 1.
    mod setAddressingModel: 0 memoryModel: 1.
    tr := mod typeRegistry.
    cp := mod constantPool.
    f32 := tr floatType: 32.
    vec3 := tr vectorType: f32 count: 3.
    vec4 := tr vectorType: f32 count: 4.
    pInVec3 := tr pointerType: SpvStorageClass input type: vec3.
    pOutVec4 := tr pointerType: SpvStorageClass output type: vec4.
    voidType := tr voidType.
    funcType := tr functionType: voidType paramTypes: #().
    inColor := SpvGlobalVariable on: mod type: pInVec3 storageClass: SpvStorageClass input.
    outColor := SpvGlobalVariable on: mod type: pOutVec4 storageClass: SpvStorageClass output.
    mod addGlobalVariable: inColor.
    mod addGlobalVariable: outColor.
    mod addDecoration: inColor id decoration: SpvDecoration location literals: (Array with: 0).
    mod addDecoration: outColor id decoration: SpvDecoration location literals: (Array with: 0).
    one32 := cp constantFloat32: 1.0.
    fn := SpvFunction new
        id: mod newId;
        returnType: voidType;
        functionType: funcType;
        module: mod;
        initialize;
        yourself.
    mod addFunction: fn.
    blk := fn addBlock.
    colorValId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad resultType: vec3 id resultId: colorValId operands: (Array with: inColor id)).
    rId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract resultType: f32 id resultId: rId operands: (Array with: colorValId with: 0)).
    gId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract resultType: f32 id resultId: gId operands: (Array with: colorValId with: 1)).
    bId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract resultType: f32 id resultId: bId operands: (Array with: colorValId with: 2)).
    outVec4Id := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeConstruct resultType: vec4 id resultId: outVec4Id operands: (Array with: rId with: gId with: bId with: one32)).
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore operands: (Array with: outColor id with: outVec4Id)).
    blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()).
    mod addEntryPoint: fn executionModel: SpvExecutionModel fragment name: 'main' interfaces: (Array with: inColor with: outColor).
    mod addExecutionMode: fn mode: 7 literals: #().
    ^ mod serialize
]

{ #category : 'private' }
PVTriangleScene >> buildVertexData [
    | data |
    data := ByteArray new: 60.
    self putFloat: -0.5 into: data at: 1.
    self putFloat: 0.5 into: data at: 5.
    self putFloat: 1.0 into: data at: 9.
    self putFloat: 0.0 into: data at: 13.
    self putFloat: 0.0 into: data at: 17.
    self putFloat: 0.5 into: data at: 21.
    self putFloat: 0.5 into: data at: 25.
    self putFloat: 0.0 into: data at: 29.
    self putFloat: 1.0 into: data at: 33.
    self putFloat: 0.0 into: data at: 37.
    self putFloat: 0.0 into: data at: 41.
    self putFloat: -0.5 into: data at: 45.
    self putFloat: 0.0 into: data at: 49.
    self putFloat: 0.0 into: data at: 53.
    self putFloat: 1.0 into: data at: 57.
    ^ data
]

{ #category : 'private' }
PVTriangleScene >> buildVertexShader [
    | mod tr cp f32 vec2 vec3 vec4 perVertexStruct pOutPerVertex pOutVec4 pInVec2 pInVec3 pOutVec3 voidType funcType inPos inColor outPerVertex outColor zero32 one32 zeroUInt32 fn blk posValId posXId posYId posVec4Id posChainId colorValId |
    mod := SpvModule new initialize.
    mod addCapability: 1.
    mod setAddressingModel: 0 memoryModel: 1.
    tr := mod typeRegistry.
    cp := mod constantPool.
    f32 := tr floatType: 32.
    vec2 := tr vectorType: f32 count: 2.
    vec3 := tr vectorType: f32 count: 3.
    vec4 := tr vectorType: f32 count: 4.
    perVertexStruct := tr structType: (Array with: vec4).
    pOutPerVertex := tr pointerType: SpvStorageClass output type: perVertexStruct.
    pOutVec4 := tr pointerType: SpvStorageClass output type: vec4.
    pInVec2 := tr pointerType: SpvStorageClass input type: vec2.
    pInVec3 := tr pointerType: SpvStorageClass input type: vec3.
    pOutVec3 := tr pointerType: SpvStorageClass output type: vec3.
    voidType := tr voidType.
    funcType := tr functionType: voidType paramTypes: #().
    mod addDecoration: perVertexStruct id decoration: SpvDecoration block literals: #().
    mod addMemberDecoration: perVertexStruct id member: 0 decoration: SpvDecoration builtIn literals: (Array with: SpvBuiltIn position).
    inPos := SpvGlobalVariable on: mod type: pInVec2 storageClass: SpvStorageClass input.
    inColor := SpvGlobalVariable on: mod type: pInVec3 storageClass: SpvStorageClass input.
    outPerVertex := SpvGlobalVariable on: mod type: pOutPerVertex storageClass: SpvStorageClass output.
    outColor := SpvGlobalVariable on: mod type: pOutVec3 storageClass: SpvStorageClass output.
    mod addGlobalVariable: inPos.
    mod addGlobalVariable: inColor.
    mod addGlobalVariable: outPerVertex.
    mod addGlobalVariable: outColor.
    mod addDecoration: inPos id decoration: SpvDecoration location literals: (Array with: 0).
    mod addDecoration: inColor id decoration: SpvDecoration location literals: (Array with: 1).
    mod addDecoration: outColor id decoration: SpvDecoration location literals: (Array with: 0).
    zero32 := cp constantFloat32: 0.0.
    one32 := cp constantFloat32: 1.0.
    zeroUInt32 := cp constantUInt32: 0.
    fn := SpvFunction new
        id: mod newId;
        returnType: voidType;
        functionType: funcType;
        module: mod;
        initialize;
        yourself.
    mod addFunction: fn.
    blk := fn addBlock.
    posValId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad resultType: vec2 id resultId: posValId operands: (Array with: inPos id)).
    posXId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract resultType: f32 id resultId: posXId operands: (Array with: posValId with: 0)).
    posYId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeExtract resultType: f32 id resultId: posYId operands: (Array with: posValId with: 1)).
    posVec4Id := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opCompositeConstruct resultType: vec4 id resultId: posVec4Id operands: (Array with: posXId with: posYId with: zero32 with: one32)).
    posChainId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opAccessChain resultType: pOutVec4 id resultId: posChainId operands: (Array with: outPerVertex id with: zeroUInt32)).
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore operands: (Array with: posChainId with: posVec4Id)).
    colorValId := mod newId.
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opLoad resultType: vec3 id resultId: colorValId operands: (Array with: inColor id)).
    blk addInstruction: (SpvInstruction opcode: SpvOpcode opStore operands: (Array with: outColor id with: colorValId)).
    blk terminate: (SpvInstruction opcode: SpvOpcode opReturn operands: #()).
    mod addEntryPoint: fn executionModel: SpvExecutionModel vertex name: 'main' interfaces: (Array with: inPos with: inColor with: outPerVertex with: outColor).
    ^ mod serialize
]

{ #category : 'geometry' }
PVTriangleScene >> centroidPosition [
	"The mean of the vertex positions, which is inside the triangle whatever the vertices are."

	| positions |
	positions := (1 to: self class vertexCount) collect: [ :i |
		              self vertexPositionAt: i ].
	^ (1 to: 2) collect: [ :axis |
		  ((positions inject: 0 into: [ :sum :each | sum + (each at: axis) ])
		   / self class vertexCount) asFloat ]
]

{ #category : 'accessing' }
PVTriangleScene >> commandPool [ ^ commandPool
]

{ #category : 'releasing' }
PVTriangleScene >> destroy [
	"Release every owned object in reverse creation order, nilling each slot so the method is
	 safe to run twice: it is reached from ensure: blocks that may already have run once on the
	 same scene. The context is not owned here, only waited on. A subclass releases whatever it
	 owns in front of these through destroyPresentation."

	self waitForIdleGpu.
	self destroyPresentation.
	vertexBuffer ifNotNil: [
		vertexBuffer destroy.
		vertexBuffer := nil ].
	pipeline ifNotNil: [
		pipeline destroy.
		pipeline := nil ].
	fragmentShaderModule ifNotNil: [
		fragmentShaderModule destroy.
		fragmentShaderModule := nil ].
	vertexShaderModule ifNotNil: [
		vertexShaderModule destroy.
		vertexShaderModule := nil ].
	commandBuffer := nil.
	"The pool frees its buffers, so there is nothing to destroy for the command buffer, but the
	 slot has to be cleared with the pool or the scene keeps a handle to freed memory and
	 lifecycleReport reports it live."
	commandPool ifNotNil: [
		commandPool destroy.
		commandPool := nil ].
	renderPass ifNotNil: [
		renderPass destroy.
		renderPass := nil ]
]

{ #category : 'releasing' }
PVTriangleScene >> destroyPresentation [
	"Hook for whatever a subclass owns in front of the drawing objects. A scene that renders
	 offscreen presents nothing, so the default releases nothing."

	^ self
]

{ #category : 'initialization' }
PVTriangleScene >> initializeCtx: aVkContext renderPass: aRenderPass extent: aPoint [
	"The half of initialisation that does not care where the picture ends up: the command pool
	 and buffer, the two shader modules, the pipeline and the vertex buffer. The caller has
	 already built the render pass, because a window needs the swapchain's format and an
	 offscreen target needs the copy-out layout."

	ctx := aVkContext.
	renderPass := aRenderPass.
	commandPool := VkCommandPool
		               on: ctx device
		               queueFamilyIndex: ctx computeQueueFamily.
	commandBuffer := commandPool allocateBuffer.
	vertexShaderModule := VkShaderModule
		                      fromBytes: self buildVertexShader
		                      device: ctx device.
	fragmentShaderModule := VkShaderModule
		                        fromBytes: self buildFragmentShader
		                        device: ctx device.
	pipeline := VkGraphicsPipeline
		            createDevice: ctx device
		            renderPass: renderPass
		            vertexModule: vertexShaderModule
		            fragmentModule: fragmentShaderModule
		            extent: aPoint.
	vertexBuffer := VkBuffer
		                on: ctx device
		                size: self class vertexDataSize
		                usage: VkBufferUsage vertexBufferBit.
	vertexBuffer copyFromByteArray: self buildVertexData
]

{ #category : 'inspecting' }
PVTriangleScene >> inspectorLifecycle: aBuilder [
	"Show which owned objects the scene is still holding. Reads the live slots through
	 lifecycleReport, so it cannot drift from what destroy actually releases: after a
	 complete teardown every row reads released except the slots the scene never owned."

	<inspectorPresentationOrder: 30 title: 'Lifecycle'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Slot'
				   evaluated: [ :each | each key asString ]);
		  addColumn: (SpStringTableColumn
				   title: 'State'
				   evaluated: [ :each | each value ]);
		  addColumn: (SpStringTableColumn
				   title: 'Owned'
				   evaluated: [ :each |
					   (self class unownedSlotNames includes: each key)
						   ifTrue: [ 'no' ]
						   ifFalse: [ 'yes' ] ]);
		  items: self lifecycleReport;
		  yourself
]

{ #category : 'inspecting' }
PVTriangleScene >> lifecycleReport [
	"Each slot paired with whether the scene is still holding something in it.
	 Reflects over the class own slots instead of naming them, so an owned object
	 added later cannot be left out of the report."

	^ self class allInstVarNames collect: [ :each |
		  each -> ((self instVarNamed: each)
			   ifNil: [ self class releasedLabel ]
			   ifNotNil: [ self class liveLabel ]) ]
]

{ #category : 'accessing' }
PVTriangleScene >> pipeline [ ^ pipeline
]

{ #category : 'private' }
PVTriangleScene >> putFloat: aFloat into: aByteArray at: offset [

	| bits |
	bits := aFloat asIEEE32BitWord.
	aByteArray at: offset put: (bits bitAnd: 16rFF).
	aByteArray at: offset + 1 put: (bits >> 8 bitAnd: 16rFF).
	aByteArray at: offset + 2 put: (bits >> 16 bitAnd: 16rFF).
	aByteArray at: offset + 3 put: (bits >> 24 bitAnd: 16rFF)
]

{ #category : 'accessing' }
PVTriangleScene >> renderPass [ ^ renderPass
]

{ #category : 'geometry' }
PVTriangleScene >> vertexAttributes [
	"Decode the vertex buffer the scene actually uploads, one array of five floats per vertex.
	 A test or a view that asks this cannot drift from buildVertexData, and it follows a
	 subclass that overrides the data."

	| data |
	data := self buildVertexData.
	^ (0 to: self class vertexCount - 1) collect: [ :vertex |
		  (0 to: self class floatsPerVertex - 1) collect: [ :field |
			  Float fromIEEE32Bit: (data unsignedLongAt:
						   vertex * self class floatsPerVertex + field
						   * self class bytesPerFloat + 1) ] ]
]

{ #category : 'geometry' }
PVTriangleScene >> vertexColourAt: anIndex [
	"The r, g and b of one vertex, one-based, each from 0.0 to 1.0."

	^ (self vertexAttributes at: anIndex) last: 3
]

{ #category : 'geometry' }
PVTriangleScene >> vertexPositionAt: anIndex [
	"The clip space x and y of one vertex, one-based. Clip space y points down."

	^ (self vertexAttributes at: anIndex) first: 2
]

{ #category : 'initialization' }
PVTriangleScene >> waitForIdleGpu [
	"Block until the device has finished every submitted command. destroy is reached
	 from an ensure: block, so the render loop may have been aborted with work still in
	 flight; destroying a resource the GPU is still reading is undefined behaviour and
	 shows up as a segfault once the validation layers are off. The context is not owned
	 here, so a context already destroyed or never prepared is simply skipped."

	ctx ifNil: [ ^ self ].
	(ctx device notNil and: [ ctx computeQueue notNil ]) ifFalse: [ ^ self ].
	ctx computeQueue waitIdle
]
