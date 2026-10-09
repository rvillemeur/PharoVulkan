"
Renders a coloured triangle using Vulkan graphics. Owns the full graphics resource chain: surface, swapchain, render pass, framebuffers, graphics pipeline, vertex buffer, semaphores, and fence. Key methods: prepare:backendWindow:, renderFrame, destroy.
"
Class {
	#name : 'PVHelloTriangleScene',
	#superclass : 'Object',
	#instVars : [
		'ctx',
		'surface',
		'swapchain',
		'renderPass',
		'framebuffers',
		'commandPool',
		'vertexShaderModule',
		'fragmentShaderModule',
		'pipeline',
		'imageAvailable',
		'renderFinished',
		'inFlightFence',
		'vertexBuffer',
		'commandBuffer'
	],
	#category : 'PharoVulkan-Example',
	#package : 'PharoVulkan',
	#tag : 'Example'
}

{ #category : 'constants' }
PVHelloTriangleScene class >> exampleExtent [
	^ 800 @ 600
]

{ #category : 'constants' }
PVHelloTriangleScene class >> exampleFrameCount [
	^ 300
]

{ #category : 'constants' }
PVHelloTriangleScene class >> liveLabel [
	^ 'live'
]

{ #category : 'instance creation' }
PVHelloTriangleScene class >> prepare: aVkContext backendWindow: aBackendWindow [
	"Answer a prepared scene, or nothing at all. A raise part-way through
	 initialisation would otherwise strand the Vulkan objects already created on an
	 instance no caller ever receives, so there would be no way left to destroy them.
	 destroy tolerates nil slots, so it is safe on a half-initialised scene."

	| scene |
	scene := self new.
	[ scene initializeCtx: aVkContext backendWindow: aBackendWindow ]
		ifCurtailed: [ scene destroy ].
	^ scene
]

{ #category : 'constants' }
PVHelloTriangleScene class >> releasedLabel [
	^ 'released'
]

{ #category : 'examples' }
PVHelloTriangleScene class >> renderTriangle [
	"Open a window, render exampleFrameCount frames, then tear everything down.
	 Every acquired resource is released by an ensure: block, in reverse order of
	 creation: scene, then context, then window, then the OSWindow driver. A raise
	 or a user interrupt mid-loop must not leave a live VkInstance, an SDL window
	 still registered with the driver, or the driver itself swapped out — with the
	 validation layers off, that state resurfaces as a segfault on the next run."

	<sampleInstance>
	| attrs |
	attrs := PVWindowAttributes newVulkan.
	attrs
		title: self windowTitle;
		extent: self exampleExtent;
		windowCentered: true.
	^ PVVulkanDriver installDuring: [
		  | win |
		  win := OSWindow createWithAttributes: attrs.
		  [ | backendWin ctx |
		  backendWin := win backendWindow.
		  ctx := VkContext graphicsContextForExtensions:
			         backendWin requiredInstanceExtensions.
		  [ | scene |
		  scene := self prepare: ctx backendWindow: backendWin.
		  [ 1 to: self exampleFrameCount do: [ :i | scene renderFrame ] ]
			  ensure: [ scene destroy ].
		  scene ] ensure: [ ctx destroy ] ] ensure: [ win destroy ] ]
]

{ #category : 'constants' }
PVHelloTriangleScene class >> unownedSlotNames [
	"Slots the scene reads but does not destroy. The context outlives the scene: the
	 caller that created it destroys it, and destroy only waits on its queue."

	^ #( #ctx )
]

{ #category : 'constants' }
PVHelloTriangleScene class >> windowTitle [
	^ 'Hello Triangle'
]

{ #category : 'private' }
PVHelloTriangleScene >> buildFragmentShader [
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
PVHelloTriangleScene >> buildVertexData [
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
PVHelloTriangleScene >> buildVertexShader [
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

{ #category : 'accessing' }
PVHelloTriangleScene >> commandPool [ ^ commandPool
]

{ #category : 'initialization' }
PVHelloTriangleScene >> destroy [
	"Release every owned object in reverse creation order, nilling each slot so the
	 method is safe to run twice: it is reached from ensure: blocks that may already
	 have run once on the same scene. The context is not owned here, only waited on."

	self waitForIdleGpu.
	inFlightFence ifNotNil: [
			inFlightFence destroy.
			inFlightFence := nil ].
	renderFinished ifNotNil: [
			renderFinished destroy.
			renderFinished := nil ].
	imageAvailable ifNotNil: [
			imageAvailable destroy.
			imageAvailable := nil ].
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
	commandPool ifNotNil: [
			commandPool destroy.
			commandPool := nil ].
	framebuffers ifNotNil: [
			framebuffers do: [ :fb | fb destroy ].
			framebuffers := nil ].
	renderPass ifNotNil: [
			renderPass destroy.
			renderPass := nil ].
	swapchain ifNotNil: [
			swapchain destroy.
			swapchain := nil ].
	surface ifNotNil: [
			surface destroy.
			surface := nil ]
]

{ #category : 'initialization' }
PVHelloTriangleScene >> initializeCtx: aVkContext backendWindow: aBackendWindow [

	| ext |
	ctx := aVkContext.
	surface := VkSurface
		           fromWindow: aBackendWindow
		           instance: ctx instance
		           physicalDevice: ctx physicalDevice.
	ext := aBackendWindow vulkanDrawableExtent.
	swapchain := VkSwapchain on: ctx device surface: surface extent: ext.
	renderPass := VkRenderPass
		              createColorPassDevice: ctx device
		              format: swapchain format.
	framebuffers := swapchain imageViews collect: [ :view |
			                VkFramebuffer
				                on: ctx device
				                renderPass: renderPass
				                imageView: view
				                width: ext x
				                height: ext y ].
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
		            extent: ext.
	vertexBuffer := VkBuffer on: ctx device size: 60 usage: 128.
	vertexBuffer copyFromByteArray: self buildVertexData.
	imageAvailable := VkSemaphoreWrapper createDevice: ctx device.
	renderFinished := VkSemaphoreWrapper createDevice: ctx device.
	inFlightFence := VkFenceWrapper createSignaledDevice: ctx device
]

{ #category : 'inspecting' }
PVHelloTriangleScene >> inspectorLifecycle: aBuilder [
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
PVHelloTriangleScene >> lifecycleReport [
	"Each slot paired with whether the scene is still holding something in it.
	 Reflects over the class own slots instead of naming them, so an owned object
	 added later cannot be left out of the report."

	^ self class allInstVarNames collect: [ :each |
		  each -> ((self instVarNamed: each)
			   ifNil: [ self class releasedLabel ]
			   ifNotNil: [ self class liveLabel ]) ]
]

{ #category : 'accessing' }
PVHelloTriangleScene >> pipeline [ ^ pipeline
]

{ #category : 'private' }
PVHelloTriangleScene >> putFloat: aFloat into: aByteArray at: offset [

	| bits |
	bits := aFloat asIEEE32BitWord.
	aByteArray at: offset put: (bits bitAnd: 16rFF).
	aByteArray at: offset + 1 put: (bits >> 8 bitAnd: 16rFF).
	aByteArray at: offset + 2 put: (bits >> 16 bitAnd: 16rFF).
	aByteArray at: offset + 3 put: (bits >> 24 bitAnd: 16rFF)
]

{ #category : 'rendering' }
PVHelloTriangleScene >> renderFrame [
	| imageIndex ext |
	inFlightFence waitTimeout: 16rFFFFFFFFFFFFFFFF.
	inFlightFence reset.
	imageIndex := swapchain
		              acquireNextImage: imageAvailable handle
		              fence: ExternalAddress null.
	ext := swapchain extent.
	commandPool reset.
	commandBuffer do: [ :c |
			c
				beginRenderPass: renderPass
				framebuffer: (framebuffers at: imageIndex + 1)
				extent: ext.
			c bindGraphicsPipeline: pipeline.
			c setViewport: ext.
			c setScissor: ext.
			c bindVertexBuffer: vertexBuffer.
			c draw: 3 ].
	ctx computeQueue
		submitGraphics: commandBuffer
		waitSemaphore: imageAvailable
		signalSemaphore: renderFinished
		fence: inFlightFence.
	swapchain
		present: imageIndex
		queue: ctx computeQueue
		waitSemaphore: renderFinished handle
]

{ #category : 'accessing' }
PVHelloTriangleScene >> renderPass [ ^ renderPass
]

{ #category : 'see class side' }
PVHelloTriangleScene >> seeClassSide [
]

{ #category : 'accessing' }
PVHelloTriangleScene >> swapchain [ ^ swapchain
]

{ #category : 'initialization' }
PVHelloTriangleScene >> waitForIdleGpu [
	"Block until the device has finished every submitted command. destroy is reached
	 from an ensure: block, so the render loop may have been aborted with work still in
	 flight; destroying a resource the GPU is still reading is undefined behaviour and
	 shows up as a segfault once the validation layers are off. The context is not owned
	 here, so a context already destroyed or never prepared is simply skipped."

	ctx ifNil: [ ^ self ].
	(ctx device notNil and: [ ctx computeQueue notNil ]) ifFalse: [ ^ self ].
	ctx computeQueue waitIdle
]
