"
Graphics pipeline for hello-triangle. Wraps VkPipeline + embedded VkPipelineLayout (no descriptor sets). Create with createDevice:renderPass:vertexModule:fragmentModule:extent:, destroy with destroy.

The class side owns the vertex layout this project draws with: vertexBindingDescriptions and vertexAttributeDescriptions build declared descriptions in object memory from the named widths and locations, runOf: copies a collection of them into one contiguous external run at the declared stride, and vertexInputStateForBindings:attributes: answers the VkPipelineVertexInputStateCreateInfo that points at both runs. The state owns those runs: freeVertexInputState: gives them back through it. The stride is derived from positionByteCount and colourByteCount rather than written again, and PVGraphicsTest asserts it against the bytes PVTriangleScene uploads.

The class side also owns the shader stages: shaderStagesForVertexModule:fragmentModule: answers a run of shaderStagesPerPipeline declared VkPipelineShaderStageCreateInfo, each naming its own module and its own copy of VkShaderModule class >> defaultEntryPoint, and freeShaderStages: gives back every entry point string and then the run.

The rest of the pipeline create info tree — input assembly, viewport, rasterization, multisample, colour blend, dynamic state and the request itself — is still written at counted offsets inside initializeDevice:renderPass:vertexModule:fragmentModule:extent:, one declared structure per remaining unit of LAYOUT-PLAN.md.
"
Class {
	#name : 'VkGraphicsPipeline',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'layout'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

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
	"The two shader stages and the vertex input state, with the two description runs it points
	 at, are declared structures built and freed through the class; the rest of the tree is
	 still written at counted offsets."

	| emptyLayout stages vertInput inputAssembly viewportState rasterState sampleState blendAttach blendState dynStates dynState createInfo pipeBuf result |

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
	inputAssembly := ExternalAddress allocate: 32.
	viewportState := ExternalAddress allocate: 48.
	rasterState := ExternalAddress allocate: 64.
	sampleState := ExternalAddress allocate: 48.
	blendAttach := ExternalAddress allocate: 32.
	blendState := ExternalAddress allocate: 56.
	dynStates := ExternalAddress allocate: 8.
	dynState := ExternalAddress allocate: 32.
	createInfo := ExternalAddress allocate: 144.
	pipeBuf := ExternalAddress allocate: 8.
	[	inputAssembly unsignedLongAt: 1  put: VkStructureType pipelineInputAssemblyStateCreateInfo.
		inputAssembly pointerAt:   9  put: ExternalAddress null.
		inputAssembly unsignedLongAt: 17 put: 0.
		inputAssembly unsignedLongAt: 21 put: VkRenderConfig primitiveTopologyTriangleList.
		inputAssembly unsignedLongAt: 25 put: 0.
		viewportState unsignedLongAt: 1  put: VkStructureType pipelineViewportStateCreateInfo.
		viewportState pointerAt:   9  put: ExternalAddress null.
		viewportState unsignedLongAt: 17 put: 0.
		viewportState unsignedLongAt: 21 put: 1.
		viewportState pointerAt:   25 put: ExternalAddress null.
		viewportState unsignedLongAt: 33 put: 1.
		viewportState pointerAt:   41 put: ExternalAddress null.
		rasterState unsignedLongAt: 1  put: VkStructureType pipelineRasterizationStateCreateInfo.
		rasterState pointerAt:   9  put: ExternalAddress null.
		rasterState unsignedLongAt: 17 put: 0.
		rasterState unsignedLongAt: 21 put: 0.
		rasterState unsignedLongAt: 25 put: 0.
		rasterState unsignedLongAt: 29 put: 0.
		rasterState unsignedLongAt: 33 put: 0.
		rasterState unsignedLongAt: 37 put: 0.
		rasterState unsignedLongAt: 41 put: 0.
		rasterState unsignedLongAt: 45 put: 0.
		rasterState unsignedLongAt: 49 put: 0.
		rasterState unsignedLongAt: 53 put: 0.
		rasterState unsignedLongAt: 57 put: 1065353216.
		sampleState unsignedLongAt: 1  put: VkStructureType pipelineMultisampleStateCreateInfo.
		sampleState pointerAt:   9  put: ExternalAddress null.
		sampleState unsignedLongAt: 17 put: 0.
		sampleState unsignedLongAt: 21 put: VkRenderConfig sampleCount1Bit.
		sampleState unsignedLongAt: 25 put: 0.
		sampleState unsignedLongAt: 29 put: 1065353216.
		sampleState pointerAt:   33 put: ExternalAddress null.
		sampleState unsignedLongAt: 41 put: 0.
		sampleState unsignedLongAt: 45 put: 0.
		blendAttach unsignedLongAt: 1  put: 0.
		blendAttach unsignedLongAt: 5  put: 0.
		blendAttach unsignedLongAt: 9  put: 0.
		blendAttach unsignedLongAt: 13 put: 0.
		blendAttach unsignedLongAt: 17 put: 0.
		blendAttach unsignedLongAt: 21 put: 0.
		blendAttach unsignedLongAt: 25 put: 0.
		blendAttach unsignedLongAt: 29 put: VkRenderConfig colorWriteMaskRGBA.
		blendState unsignedLongAt: 1  put: VkStructureType pipelineColorBlendStateCreateInfo.
		blendState pointerAt:   9  put: ExternalAddress null.
		blendState unsignedLongAt: 17 put: 0.
		blendState unsignedLongAt: 21 put: 0.
		blendState unsignedLongAt: 25 put: 0.
		blendState unsignedLongAt: 29 put: 1.
		blendState pointerAt:   33 put: blendAttach.
		blendState unsignedLongAt: 41 put: 0.
		blendState unsignedLongAt: 45 put: 0.
		blendState unsignedLongAt: 49 put: 0.
		blendState unsignedLongAt: 53 put: 0.
		dynStates unsignedLongAt: 1 put: 0.
		dynStates unsignedLongAt: 5 put: 1.
		dynState unsignedLongAt: 1  put: VkStructureType pipelineDynamicStateCreateInfo.
		dynState pointerAt:   9  put: ExternalAddress null.
		dynState unsignedLongAt: 17 put: 0.
		dynState unsignedLongAt: 21 put: 2.
		dynState pointerAt:   25 put: dynStates.
		createInfo unsignedLongAt: 1  put: VkStructureType graphicsPipelineCreateInfo.
		createInfo pointerAt:   9  put: ExternalAddress null.
		createInfo unsignedLongAt: 17 put: 0.
		createInfo unsignedLongAt: 21 put: stages size.
		createInfo pointerAt:   25 put: stages first getHandle.
		createInfo pointerAt:   33 put: vertInput getHandle.
		createInfo pointerAt:   41 put: inputAssembly.
		createInfo pointerAt:   49 put: ExternalAddress null.
		createInfo pointerAt:   57 put: viewportState.
		createInfo pointerAt:   65 put: rasterState.
		createInfo pointerAt:   73 put: sampleState.
		createInfo pointerAt:   81 put: ExternalAddress null.
		createInfo pointerAt:   89 put: blendState.
		createInfo pointerAt:   97 put: dynState.
		createInfo pointerAt:  105 put: layout handle getHandle.
		createInfo pointerAt:  113 put: aRenderPass handle getHandle.
		createInfo unsignedLongAt: 121 put: 0.
		createInfo pointerAt:  129 put: ExternalAddress null.
		createInfo unsignedLongAt: 137 put: 16rFFFFFFFF.
		result := Vk createGraphicsPipelines: device handle pipelineCache: ExternalAddress null createInfoCount: 1 pCreateInfos: createInfo allocator: ExternalAddress null pPipelines: pipeBuf.
		Vk checkResult: result.
		handle := VkPipeline_H fromHandle: (pipeBuf pointerAt: 1)
	] ensure: [
		self class freeShaderStages: stages.
		self class freeVertexInputState: vertInput.
		inputAssembly free. viewportState free. rasterState free.
		sampleState free. blendAttach free. blendState free.
		dynStates free. dynState free. createInfo free. pipeBuf free ]
]

{ #category : 'accessing' }
VkGraphicsPipeline >> layout [
    ^ layout
]
