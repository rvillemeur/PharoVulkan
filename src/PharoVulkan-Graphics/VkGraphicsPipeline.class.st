"
Graphics pipeline for hello-triangle. Wraps VkPipeline + embedded VkPipelineLayout (no descriptor sets). Create with createDevice:renderPass:vertexModule:fragmentModule:extent:, destroy with destroy.

The class side owns the vertex layout this project draws with: vertexBindingDescriptions and vertexAttributeDescriptions build declared descriptions in object memory from the named widths and locations, runOf: copies a collection of them into one contiguous external run at the declared stride, and vertexInputStateForBindings:attributes: answers the VkPipelineVertexInputStateCreateInfo that points at both runs. The state owns those runs: freeVertexInputState: gives them back through it. The stride is derived from positionByteCount and colourByteCount rather than written again, and PVGraphicsTest asserts it against the bytes PVTriangleScene uploads.

The class side also owns the shader stages: shaderStagesForVertexModule:fragmentModule: answers a run of shaderStagesPerPipeline declared VkPipelineShaderStageCreateInfo, each naming its own module and its own copy of VkShaderModule class >> defaultEntryPoint, and freeShaderStages: gives back every entry point string and then the run.

Every other structure in the tree is declared as well, one builder per state: inputAssemblyState, viewportState, rasterizationState, multisampleState, colorBlendState — which owns a run of VkPipelineColorBlendAttachmentState — and dynamicState, which owns a run of the enumerations in dynamicStatesSetWhileRecording. Each builder writes only what carries meaning, because externalInstance hands back a zeroed block. requestForStages:vertexInput:layout:renderPass: builds the VkGraphicsPipelineCreateInfo that names them all: the stage run and the vertex input state are passed in, since a module and a vertex layout are needed to build them, and the six states that need neither are built and owned by the request. freeRequest: gives the nested states back and then the request's own store, and handleForRequest:on: is the only caller of vkCreateGraphicsPipelines — its out parameter is a run of one handle rather than a structure, which is the one block here still read at an offset, along with the run of dynamic state enumerations, whose elements are plain words and so have a named stride instead of a layout.

The viewport and the scissor are dynamic, so the extent passed to createDevice:... is not read when the pipeline is built: PVTriangleScene sets both while recording.
"
Class {
	#name : 'VkGraphicsPipeline',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'layout'
	],
	#category : 'PharoVulkan-Graphics-Pipeline',
	#package : 'PharoVulkan-Graphics',
	#tag : 'Pipeline'
}

{ #category : 'constants' }
VkGraphicsPipeline class >> colorAttachmentsPerPipeline [
	"One colour attachment, the one the render pass declares, so the blend state describes one
	 attachment and the run it points at holds one element."

	^ 1
]

{ #category : 'request' }
VkGraphicsPipeline class >> colorBlendState [
	"How this project writes colour: the fragment replaces what is in the attachment, on all
	 four channels. Blending is off, so the factors and the operations stay as the zeroed block
	 left them, and no logic operation is asked for. The state owns the attachment run it
	 points at, so the caller gives it back through freeColorBlendState:."

	| attachments |
	attachments := VkPipelineColorBlendAttachmentState externalArrayOf:
		               self colorAttachmentsPerPipeline.
	attachments do: [ :each |
		each colorWriteMask: VkColorComponent allChannels ].
	^ VkPipelineColorBlendStateCreateInfo externalInstance
		  attachmentCount: attachments size;
		  pAttachments: attachments first getHandle;
		  yourself
]

{ #category : 'vertex layout' }
VkGraphicsPipeline class >> colourByteCount [
	"A colour is three 32 bit floats, so it is twelve bytes wide."

	^ 12
]

{ #category : 'vertex layout' }
VkGraphicsPipeline class >> colourLocation [
	"The shader location the vertex colour arrives at, after the position."

	^ 1
]

{ #category : 'instance creation' }
VkGraphicsPipeline class >> createDevice: aVkDevice renderPass: aRenderPass vertexModule: aVertexModule fragmentModule: aFragmentModule extent: aPoint [
    | obj |
    obj := self new.
    obj initializeDevice: aVkDevice renderPass: aRenderPass vertexModule: aVertexModule fragmentModule: aFragmentModule extent: aPoint.
    ^ obj
]

{ #category : 'request' }
VkGraphicsPipeline class >> dynamicState [
	"Which states the command buffer sets while it records. The run of state values is
	 allocated by the stride the structure declares and the state is pointed at it; the state
	 owns that run, so the caller gives it back through freeDynamicState:."

	| states stride run |
	states := self dynamicStatesSetWhileRecording.
	stride := VkPipelineDynamicStateCreateInfo dynamicStateByteCount.
	run := ExternalAddress allocate: states size * stride.
	states doWithIndex: [ :each :index |
		run unsignedLongAt: index - 1 * stride + 1 put: each ].
	^ VkPipelineDynamicStateCreateInfo externalInstance
		  dynamicStateCount: states size;
		  pDynamicStates: run;
		  yourself
]

{ #category : 'constants' }
VkGraphicsPipeline class >> dynamicStatesSetWhileRecording [
	"The viewport and the scissor rectangle, in the order the run holds them. Both are set
	 while the command buffer is recorded, so one pipeline draws into a target of any extent;
	 everything else about the pipeline is fixed when it is built."

	^ {
		  VkDynamicState viewport.
		  VkDynamicState scissor }
]

{ #category : 'constants' }
VkGraphicsPipeline class >> everySampleShaded [
	"The least part of the samples in a pixel that gets its own shading, as a fraction: one is
	 all of them. The driver reads it only where sample shading is enabled, which nothing here
	 enables, so it is written to keep the field from reading as a fraction no one chose."

	^ 1.0
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeColorBlendAttachmentsOf: aState [
	"Give back the attachment run the state points at, and null the field as it goes: the state
	 is the record of where that run is, so a freed address left in it could be read or freed
	 twice."

	aState pAttachments isNull ifFalse: [
		aState pAttachments getHandle free ].
	aState pAttachments: ExternalAddress null
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeColorBlendState: aState [
	"Everything the state owns, in the order that keeps each address readable until it is
	 freed: the attachment run it points at, then the state's own store."

	self freeColorBlendAttachmentsOf: aState.
	aState getHandle free
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeDynamicState: aState [
	"Everything the state owns, in the order that keeps each address readable until it is
	 freed: the run of state values it points at, then the state's own store."

	self freeDynamicStatesOf: aState.
	aState getHandle free
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeDynamicStatesOf: aState [
	"Give back the run of state values the state points at, and null the field as it goes: the
	 state is the record of where that run is, so a freed address left in it could be read or
	 freed twice."

	aState pDynamicStates isNull ifFalse: [
		aState pDynamicStates getHandle free ].
	aState pDynamicStates: ExternalAddress null
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeNestedStatesOf: aRequest [
	"Give back the six states the request built, and null each field as it goes: the request is
	 the record of where those states are, so a freed address left in one could be read or freed
	 twice. The two states owning runs go first through the methods that free the run before the
	 store. The stage run and the vertex input state are not touched: they belong to the caller
	 that passed them in."

	self freeColorBlendState: (VkPipelineColorBlendStateCreateInfo fromHandle:
			 aRequest pColorBlendState getHandle).
	aRequest pColorBlendState: ExternalAddress null.
	self freeDynamicState: (VkPipelineDynamicStateCreateInfo fromHandle:
			 aRequest pDynamicState getHandle).
	aRequest pDynamicState: ExternalAddress null.
	self statesTheRequestOwnsOutright do: [ :each |
		(aRequest perform: each) getHandle free.
		aRequest perform: (each , ':') asSymbol with: ExternalAddress null ]
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeRequest: aRequest [
	"Everything the request owns, in the order that keeps each address readable until it is
	 freed: the states nested under it, then its own store."

	self freeNestedStatesOf: aRequest.
	aRequest getHandle free
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeShaderStageEntryPointsOf: someStages [
	"Give back the entry point string each stage points at, and null the field as it goes: a
	 stage is the record of where its own name is, so a freed address left in it could be read
	 or freed twice. Each stage allocated its own string, so each is freed once."

	someStages do: [ :each |
		each pName isNull ifFalse: [ each pName getHandle free ].
		each pName: ExternalAddress null ]
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeShaderStages: someStages [
	"Everything the run owns, in the order that keeps each address readable until it is freed:
	 the entry point strings the stages point at, then the one block the whole run lives in,
	 which is named by its first element."

	self freeShaderStageEntryPointsOf: someStages.
	someStages first getHandle free
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeVertexInputRunsOf: aVertexInputState [
	"Give back the two runs the state points at, and null each field as it goes: the state is
	 the record of where those runs are, so a freed address left in it could be read or freed
	 twice. A null field was never a run and is left alone."

	aVertexInputState pVertexBindingDescriptions isNull ifFalse: [
		aVertexInputState pVertexBindingDescriptions getHandle free ].
	aVertexInputState pVertexAttributeDescriptions isNull ifFalse: [
		aVertexInputState pVertexAttributeDescriptions getHandle free ].
	aVertexInputState
		pVertexBindingDescriptions: ExternalAddress null;
		pVertexAttributeDescriptions: ExternalAddress null
]

{ #category : 'request' }
VkGraphicsPipeline class >> freeVertexInputState: aVertexInputState [
	"Everything the state owns, in the order that keeps each address readable until it is
	 freed: the two runs it points at, then its own store."

	self freeVertexInputRunsOf: aVertexInputState.
	aVertexInputState getHandle free
]

{ #category : 'request' }
VkGraphicsPipeline class >> handleForRequest: aRequest on: aDevice [
	"The one call that creates a graphics pipeline. The driver answers through an out parameter,
	 which is a run of one handle rather than a structure, so it stays a plain block read by
	 pointerAt: and freed whatever the result. The handle is read before the block goes."

	| handleBlock result |
	handleBlock := ExternalAddress allocate:
		               VkPipelineCreation pipelinesPerCreate
		               * VkContext pointerSize.
	^ [
	  result := Vk
		            createGraphicsPipelines: aDevice handle
		            pipelineCache: ExternalAddress null
		            createInfoCount: VkPipelineCreation pipelinesPerCreate
		            pCreateInfos: aRequest getHandle
		            allocator: ExternalAddress null
		            pPipelines: handleBlock.
	  Vk checkResult: result.
	  VkPipeline_H fromHandle: (handleBlock pointerAt: 1) ] ensure: [
		  handleBlock free ]
]

{ #category : 'request' }
VkGraphicsPipeline class >> inputAssemblyState [
	"The one shape this project draws: separate triangles, three vertices each, with no restart
	 index. The state points at nothing, so the caller frees its own store and nothing else."

	^ VkPipelineInputAssemblyStateCreateInfo externalInstance
		  topology: VkPrimitiveTopology triangleList;
		  primitiveRestartEnable: self primitiveRestartDisabled;
		  yourself
]

{ #category : 'constants' }
VkGraphicsPipeline class >> lineWidthEveryDeviceAccepts [
	"Vulkan accepts a line width other than one only where the wideLines feature is enabled,
	 and nothing here enables it. The field applies to line primitives, of which this project
	 draws none, but the driver reads it whatever the topology."

	^ 1.0
]

{ #category : 'request' }
VkGraphicsPipeline class >> multisampleState [
	"How this project samples: one sample per pixel, so there is nothing to average and no
	 sample mask to hand over. Sample shading and the two alpha flags stay as the zeroed block
	 left them, which is what a disabled VkBool32 reads as. The state points at nothing, so
	 the caller frees its own store and nothing else."

	^ VkPipelineMultisampleStateCreateInfo externalInstance
		  rasterizationSamples: VkSampleCount count1Bit;
		  minSampleShading: self everySampleShaded;
		  yourself
]

{ #category : 'vertex layout' }
VkGraphicsPipeline class >> positionByteCount [
	"A position is two 32 bit floats, so it is eight bytes wide. It is also the offset of the
	 colour that follows it and part of the stride, both of which are derived from it rather
	 than written again."

	^ 8
]

{ #category : 'vertex layout' }
VkGraphicsPipeline class >> positionLocation [
	"The shader location the vertex position arrives at — the first input of the vertex shader
	 this project compiles."

	^ 0
]

{ #category : 'constants' }
VkGraphicsPipeline class >> primitiveRestartDisabled [
	"Primitive restart applies to indexed draws, where one index value ends a primitive and
	 starts the next. Nothing here draws indexed, so the flag is off."

	^ 0
]

{ #category : 'request' }
VkGraphicsPipeline class >> rasterizationState [
	"How this project rasterizes: filled triangles, no face discarded, front faces wound
	 counter clockwise. Depth clamp, rasterizer discard and depth bias stay as the zeroed
	 block left them, which is what a disabled VkBool32 and an unused bias factor read as.
	 The state points at nothing, so the caller frees its own store and nothing else."

	^ VkPipelineRasterizationStateCreateInfo externalInstance
		  polygonMode: VkPolygonMode fill;
		  cullMode: VkCullMode none;
		  frontFace: VkFrontFace counterClockwise;
		  lineWidth: self lineWidthEveryDeviceAccepts;
		  yourself
]

{ #category : 'request' }
VkGraphicsPipeline class >> requestForStages: someStages vertexInput: aVertexInputState layout: aLayoutHandle renderPass: aRenderPassHandle [
	"The one request every graphics pipeline here is created from, outside object memory because
	 the driver reads it after this method answers. The stage run and the vertex input state are
	 passed in: they need a shader module and a vertex layout to build, and the caller that has
	 those owns them. The six states that need neither are built here and owned by the request,
	 which freeRequest: gives back. Nothing writes the flags, the tessellation or depth stencil
	 states, or the base pipeline handle: this project asks for none of them and the zeroed
	 block already reads as null."

	^ VkGraphicsPipelineCreateInfo externalInstance
		  stageCount: someStages size;
		  pStages: someStages first getHandle;
		  pVertexInputState: aVertexInputState getHandle;
		  pInputAssemblyState: self inputAssemblyState getHandle;
		  pViewportState: self viewportState getHandle;
		  pRasterizationState: self rasterizationState getHandle;
		  pMultisampleState: self multisampleState getHandle;
		  pColorBlendState: self colorBlendState getHandle;
		  pDynamicState: self dynamicState getHandle;
		  layout: aLayoutHandle;
		  renderPass: aRenderPassHandle;
		  subpass: self subpassThisPipelineDrawsIn;
		  basePipelineIndex: VkPipelineCreation noBasePipelineIndex;
		  yourself
]

{ #category : 'request' }
VkGraphicsPipeline class >> runOf: someDescriptions [
	"One contiguous run outside object memory holding the given descriptions at their declared
	 stride, which is how the driver reads an array it is pointed at. The descriptions
	 themselves live in object memory, where the garbage collector may move them, so each is
	 copied into its element. The caller frees the first element's handle, which is the
	 address of the whole block; an empty collection allocates nothing and answers null,
	 because a pointer into a block of no bytes is not something to hand a driver."

	| elements |
	someDescriptions ifEmpty: [ ^ ExternalAddress null ].
	elements := someDescriptions first class externalArrayOf:
		            someDescriptions size.
	someDescriptions doWithIndex: [ :each :index |
		each copyBytesInto: (elements at: index) ].
	^ elements first getHandle
]

{ #category : 'constants' }
VkGraphicsPipeline class >> scissorsPerPipeline [
	"One scissor rectangle, matching the one viewport. It is dynamic for the same reason: the
	 target's extent is known when the frame is recorded, not when the pipeline is built."

	^ 1
]

{ #category : 'request' }
VkGraphicsPipeline class >> shaderStagesForVertexModule: aVertexModuleHandle fragmentModule: aFragmentModuleHandle [
	"The two stages a graphics pipeline is created from, in one contiguous external run so the
	 request can name them by the first element's address. Each element is written through the
	 declared fields, so the structure's own layout decides where each value lands."

	| stages |
	stages := VkPipelineShaderStageCreateInfo externalArrayOf:
		          self shaderStagesPerPipeline.
	{
		(VkShaderStage vertexBit -> aVertexModuleHandle).
		(VkShaderStage fragmentBit -> aFragmentModuleHandle) }
		doWithIndex: [ :each :index |
			(stages at: index)
				sType: VkStructureType pipelineShaderStageCreateInfo;
				stage: each key;
				module: each value;
				pName: (Vk allocateCString: VkShaderModule defaultEntryPoint) ].
	^ stages
]

{ #category : 'constants' }
VkGraphicsPipeline class >> shaderStagesPerPipeline [
	"Every pipeline this project draws with has a vertex stage and a fragment stage, and no
	 other. A tessellation or geometry stage would add an element to the run and a module to
	 build it from."

	^ 2
]

{ #category : 'request' }
VkGraphicsPipeline class >> statesTheRequestOwnsOutright [
	"The nested states a request gives back by freeing their own store alone. The colour blend
	 and dynamic states are not here: each owns a run of its own, which has to be freed first,
	 so each goes through the method that knows about that run."

	^ #( #pInputAssemblyState #pViewportState #pRasterizationState
	     #pMultisampleState )
]

{ #category : 'constants' }
VkGraphicsPipeline class >> subpassThisPipelineDrawsIn [
	"The render pass this project builds declares one subpass, so the pipeline draws in the
	 first one and its index is zero. A second subpass would be a pipeline of its own created
	 with the next index."

	^ 0
]

{ #category : 'vertex layout' }
VkGraphicsPipeline class >> vertexAttributeDescriptions [
	"What one vertex holds: a two-float position at its start and a three-float colour after it,
	 both read from the one bound buffer. The colour's offset is the width of the position, so
	 the two cannot drift apart. The descriptions live in object memory and are copied into an
	 external run when a state structure is built from them."

	^ {
		  (VkVertexInputAttributeDescription new
			   location: self positionLocation;
			   binding: self vertexBufferBinding;
			   format: VkFormat r32g32Sfloat;
			   offset: 0;
			   yourself).
		  (VkVertexInputAttributeDescription new
			   location: self colourLocation;
			   binding: self vertexBufferBinding;
			   format: VkFormat r32g32b32Sfloat;
			   offset: self positionByteCount;
			   yourself) }
]

{ #category : 'vertex layout' }
VkGraphicsPipeline class >> vertexBindingDescriptions [
	"The buffer bindings this project's pipeline reads vertices from: one buffer, advanced one
	 vertex at a time. The stride is the position and the colour together, derived from the two
	 widths so a format changed on one side cannot leave it naming a width no vertex has. The
	 descriptions live in object memory and are copied into an external run when a state
	 structure is built from them."

	^ { (VkVertexInputBindingDescription new
		   binding: self vertexBufferBinding;
		   stride: self positionByteCount + self colourByteCount;
		   inputRate: VkVertexInputRate perVertex;
		   yourself) }
]

{ #category : 'vertex layout' }
VkGraphicsPipeline class >> vertexBufferBinding [
	"The one binding number this project's pipeline reads vertices from. Every attribute reads
	 the same buffer, so they all name this binding."

	^ 0
]

{ #category : 'request' }
VkGraphicsPipeline class >> vertexInputStateForBindings: someBindings attributes: someAttributes [
	"The vertex input state this project's pipeline is created with, outside object memory
	 because the driver reads it after this method answers. It owns the two runs it points at,
	 which freeVertexInputState: gives back through it."

	| state |
	state := VkPipelineVertexInputStateCreateInfo externalInstance.
	^ state
		  vertexBindingDescriptionCount: someBindings size;
		  pVertexBindingDescriptions: (self runOf: someBindings);
		  vertexAttributeDescriptionCount: someAttributes size;
		  pVertexAttributeDescriptions: (self runOf: someAttributes);
		  yourself
]

{ #category : 'request' }
VkGraphicsPipeline class >> viewportState [
	"How many rectangles the pipeline draws into. Neither run is given: both rectangles are
	 dynamic states, so the command buffer sets them while it records. The state points at
	 nothing, so the caller frees its own store and nothing else."

	^ VkPipelineViewportStateCreateInfo externalInstance
		  viewportCount: self viewportsPerPipeline;
		  scissorCount: self scissorsPerPipeline;
		  yourself
]

{ #category : 'constants' }
VkGraphicsPipeline class >> viewportsPerPipeline [
	"One viewport, the whole target. The pipeline declares the count because the driver needs
	 it when it compiles, and the command buffer gives the rectangle itself while recording."

	^ 1
]

{ #category : 'lifecycle' }
VkGraphicsPipeline >> destroy [

	handle ifNotNil: [
			Vk
				destroyPipeline: device handle
				pipeline: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ].
	layout ifNotNil: [
			layout destroy.
			layout := nil ]
]

{ #category : 'accessing' }
VkGraphicsPipeline >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkGraphicsPipeline >> initializeDevice: aVkDevice renderPass: aRenderPass vertexModule: aVertexModule fragmentModule: aFragmentModule extent: aPoint [
	"Every structure in the tree is declared: the two shader stages and the vertex input state,
	 with the runs they point at, and the request that names them along with the six states it
	 builds itself. The stages and the vertex input state are owned here, because a module and a
	 vertex layout are needed to build them; the request owns the rest and is freed whatever the
	 creation does. The extent is not read: the viewport and the scissor are dynamic, so they
	 are set while recording rather than built into the pipeline."

	| emptyLayout stages vertInput request |
	device := aVkDevice.
	emptyLayout := VkPipelineLayout new.
	emptyLayout initializeOn: aVkDevice setLayouts: #().
	layout := emptyLayout.
	stages := self class
		          shaderStagesForVertexModule: aVertexModule handle
		          fragmentModule: aFragmentModule handle.
	vertInput := self class
		             vertexInputStateForBindings:
		             self class vertexBindingDescriptions
		             attributes: self class vertexAttributeDescriptions.
	request := self class
		           requestForStages: stages
		           vertexInput: vertInput
		           layout: layout handle
		           renderPass: aRenderPass handle.
	handle := [ self class handleForRequest: request on: device ] ensure: [
		          self class freeRequest: request.
		          self class freeVertexInputState: vertInput.
		          self class freeShaderStages: stages ]
]

{ #category : 'accessing' }
VkGraphicsPipeline >> layout [
    ^ layout
]
