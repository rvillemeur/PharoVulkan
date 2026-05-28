"
Graphics pipeline for hello-triangle. Wraps VkPipeline + embedded VkPipelineLayout (no descriptor sets). Create with #createDevice:renderPass:vertexModule:fragmentModule:extent:, destroy with #destroy.
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

{ #category : 'instance creation' }
VkGraphicsPipeline class >> createDevice: aVkDevice renderPass: aRenderPass vertexModule: aVertexModule fragmentModule: aFragmentModule extent: aPoint [
    | obj |
    obj := self new.
    obj initializeDevice: aVkDevice renderPass: aRenderPass vertexModule: aVertexModule fragmentModule: aFragmentModule extent: aPoint.
    ^ obj
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
	"VkPipelineShaderStageCreateInfo (48 bytes each): 0:sType 8:pNext 16:flags 20:stage 24:module(ptr) 32:pName(ptr) 40:pSpecializationInfo(ptr)
	 VkVertexInputBindingDescription (12 bytes): 0:binding 4:stride 8:inputRate
	 VkVertexInputAttributeDescription (16 bytes): 0:location 4:binding 8:format 12:offset
	 VkPipelineVertexInputStateCreateInfo (48 bytes): 0:sType 8:pNext 16:flags 20:bindingCount 24:pBindings(ptr) 32:attrCount 40:pAttribs(ptr)"
	| emptyLayout nameBuf stagesBuf bindDesc attrDesc vertInput inputAssembly viewportState rasterState sampleState blendAttach blendState dynStates dynState createInfo pipeBuf result bindings attrs |
	device := aVkDevice.
	emptyLayout := VkPipelineLayout new.
	emptyLayout initializeOn: aVkDevice setLayouts: #().
	layout := emptyLayout.
	nameBuf := ExternalAddress allocate: 5.
	stagesBuf := ExternalAddress allocate: 96.
	bindings := self vertexBindingDescriptions.
	attrs := self vertexAttributeDescriptions.
	bindDesc := ExternalAddress allocate: bindings size * 12.
	attrDesc := ExternalAddress allocate: attrs size * 16.
	vertInput := ExternalAddress allocate: 48.
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
	[	nameBuf byteAt: 1 put: 109.
		nameBuf byteAt: 2 put: 97.
		nameBuf byteAt: 3 put: 105.
		nameBuf byteAt: 4 put: 110.
		nameBuf byteAt: 5 put: 0.
		stagesBuf unsignedLongAt: 1  put: VkStructureType pipelineShaderStageCreateInfo.
		stagesBuf pointerAt:   9  put: ExternalAddress null.
		stagesBuf unsignedLongAt: 17 put: 0.
		stagesBuf unsignedLongAt: 21 put: VkShaderStage vertexBit.
		stagesBuf pointerAt:   25 put: aVertexModule handle getHandle.
		stagesBuf pointerAt:   33 put: nameBuf.
		stagesBuf pointerAt:   41 put: ExternalAddress null.
		stagesBuf unsignedLongAt: 49 put: VkStructureType pipelineShaderStageCreateInfo.
		stagesBuf pointerAt:   57 put: ExternalAddress null.
		stagesBuf unsignedLongAt: 65 put: 0.
		stagesBuf unsignedLongAt: 69 put: VkShaderStage fragmentBit.
		stagesBuf pointerAt:   73 put: aFragmentModule handle getHandle.
		stagesBuf pointerAt:   81 put: nameBuf.
		stagesBuf pointerAt:   89 put: ExternalAddress null.
		bindings doWithIndex: [:b :i |
			| base |
			base := (i - 1) * 12 + 1.
			bindDesc unsignedLongAt: base     put: b binding.
			bindDesc unsignedLongAt: base + 4 put: b stride.
			bindDesc unsignedLongAt: base + 8 put: b inputRate].
		attrs doWithIndex: [:a :i |
			| base |
			base := (i - 1) * 16 + 1.
			attrDesc unsignedLongAt: base      put: a location.
			attrDesc unsignedLongAt: base + 4  put: a binding.
			attrDesc unsignedLongAt: base + 8  put: a format.
			attrDesc unsignedLongAt: base + 12 put: a offset].
		vertInput unsignedLongAt: 1  put: VkStructureType pipelineVertexInputStateCreateInfo.
		vertInput pointerAt:   9  put: ExternalAddress null.
		vertInput unsignedLongAt: 17 put: 0.
		vertInput unsignedLongAt: 21 put: bindings size.
		vertInput pointerAt:   25 put: bindDesc.
		vertInput unsignedLongAt: 33 put: attrs size.
		vertInput pointerAt:   41 put: attrDesc.
		inputAssembly unsignedLongAt: 1  put: VkStructureType pipelineInputAssemblyStateCreateInfo.
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
		createInfo unsignedLongAt: 21 put: 2.
		createInfo pointerAt:   25 put: stagesBuf.
		createInfo pointerAt:   33 put: vertInput.
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
		nameBuf free. stagesBuf free. bindDesc free. attrDesc free.
		vertInput free. inputAssembly free. viewportState free. rasterState free.
		sampleState free. blendAttach free. blendState free.
		dynStates free. dynState free. createInfo free. pipeBuf free ]
]

{ #category : 'accessing' }
VkGraphicsPipeline >> layout [
    ^ layout
]

{ #category : 'vertex input' }
VkGraphicsPipeline >> vertexAttributeDescriptions [
	"Default: location 0 = vec2 position at byte 0, location 1 = vec3 color at byte 8."
	^ {
		VkVertexAttributeDescription location: 0 binding: 0 format: VkFormat r32g32Sfloat offset: 0.
		VkVertexAttributeDescription location: 1 binding: 0 format: VkFormat r32g32b32Sfloat offset: 8 }
]

{ #category : 'vertex input' }
VkGraphicsPipeline >> vertexBindingDescriptions [
	"Default: binding 0, stride 20 bytes (vec2 pos + vec3 color), per-vertex rate."
	^ { VkVertexBindingDescription binding: 0 stride: 20 inputRate: 0 }
]
