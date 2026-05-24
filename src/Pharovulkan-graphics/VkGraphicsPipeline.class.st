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
	#category : 'Pharovulkan-graphics',
	#package : 'Pharovulkan-graphics'
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
        Vk destroyPipeline: device handle pipeline: handle allocator: ExternalAddress null.
        handle := nil ].
    layout ifNotNil: [ layout destroy. layout := nil ]
]

{ #category : 'accessing' }
VkGraphicsPipeline >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkGraphicsPipeline >> initializeDevice: aVkDevice renderPass: aRenderPass vertexModule: aVertexModule fragmentModule: aFragmentModule extent: aPoint [
    | emptyLayout nameBuf stagesBuf bindDesc attrDesc vertInput inputAssembly viewportState rasterState sampleState blendAttach blendState dynStates dynState createInfo pipeBuf result |
    device := aVkDevice.
    emptyLayout := VkPipelineLayout new.
    emptyLayout initializeOn: aVkDevice setLayouts: #().
    layout := emptyLayout.
    nameBuf := ExternalAddress allocate: 5.
    stagesBuf := ExternalAddress allocate: 96.
    bindDesc := ExternalAddress allocate: 12.
    attrDesc := ExternalAddress allocate: 32.
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
    [   nameBuf byteAt: 1 put: 109.
        nameBuf byteAt: 2 put: 97.
        nameBuf byteAt: 3 put: 105.
        nameBuf byteAt: 4 put: 110.
        nameBuf byteAt: 5 put: 0.
        stagesBuf unsignedLongAt: 1 put: 18.
        stagesBuf pointerAt: 9 put: ExternalAddress null.
        stagesBuf unsignedLongAt: 17 put: 0.
        stagesBuf unsignedLongAt: 21 put: 1.
        stagesBuf pointerAt: 25 put: aVertexModule handle getHandle.
        stagesBuf pointerAt: 33 put: nameBuf.
        stagesBuf pointerAt: 41 put: ExternalAddress null.
        stagesBuf unsignedLongAt: 49 put: 18.
        stagesBuf pointerAt: 57 put: ExternalAddress null.
        stagesBuf unsignedLongAt: 65 put: 0.
        stagesBuf unsignedLongAt: 69 put: 16.
        stagesBuf pointerAt: 73 put: aFragmentModule handle getHandle.
        stagesBuf pointerAt: 81 put: nameBuf.
        stagesBuf pointerAt: 89 put: ExternalAddress null.
        bindDesc unsignedLongAt: 1 put: 0.
        bindDesc unsignedLongAt: 5 put: 20.
        bindDesc unsignedLongAt: 9 put: 0.
        attrDesc unsignedLongAt: 1 put: 0.
        attrDesc unsignedLongAt: 5 put: 0.
        attrDesc unsignedLongAt: 9 put: 103.
        attrDesc unsignedLongAt: 13 put: 0.
        attrDesc unsignedLongAt: 17 put: 1.
        attrDesc unsignedLongAt: 21 put: 0.
        attrDesc unsignedLongAt: 25 put: 106.
        attrDesc unsignedLongAt: 29 put: 8.
        vertInput unsignedLongAt: 1 put: 19.
        vertInput pointerAt: 9 put: ExternalAddress null.
        vertInput unsignedLongAt: 17 put: 0.
        vertInput unsignedLongAt: 21 put: 1.
        vertInput pointerAt: 25 put: bindDesc.
        vertInput unsignedLongAt: 33 put: 2.
        vertInput pointerAt: 41 put: attrDesc.
        inputAssembly unsignedLongAt: 1 put: 20.
        inputAssembly pointerAt: 9 put: ExternalAddress null.
        inputAssembly unsignedLongAt: 17 put: 0.
        inputAssembly unsignedLongAt: 21 put: 3.
        inputAssembly unsignedLongAt: 25 put: 0.
        viewportState unsignedLongAt: 1 put: 22.
        viewportState pointerAt: 9 put: ExternalAddress null.
        viewportState unsignedLongAt: 17 put: 0.
        viewportState unsignedLongAt: 21 put: 1.
        viewportState pointerAt: 25 put: ExternalAddress null.
        viewportState unsignedLongAt: 33 put: 1.
        viewportState pointerAt: 41 put: ExternalAddress null.
        rasterState unsignedLongAt: 1 put: 23.
        rasterState pointerAt: 9 put: ExternalAddress null.
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
        sampleState unsignedLongAt: 1 put: 24.
        sampleState pointerAt: 9 put: ExternalAddress null.
        sampleState unsignedLongAt: 17 put: 0.
        sampleState unsignedLongAt: 21 put: 1.
        sampleState unsignedLongAt: 25 put: 0.
        sampleState unsignedLongAt: 29 put: 1065353216.
        sampleState pointerAt: 33 put: ExternalAddress null.
        sampleState unsignedLongAt: 41 put: 0.
        sampleState unsignedLongAt: 45 put: 0.
        blendAttach unsignedLongAt: 1 put: 0.
        blendAttach unsignedLongAt: 5 put: 0.
        blendAttach unsignedLongAt: 9 put: 0.
        blendAttach unsignedLongAt: 13 put: 0.
        blendAttach unsignedLongAt: 17 put: 0.
        blendAttach unsignedLongAt: 21 put: 0.
        blendAttach unsignedLongAt: 25 put: 0.
        blendAttach unsignedLongAt: 29 put: 15.
        blendState unsignedLongAt: 1 put: 26.
        blendState pointerAt: 9 put: ExternalAddress null.
        blendState unsignedLongAt: 17 put: 0.
        blendState unsignedLongAt: 21 put: 0.
        blendState unsignedLongAt: 25 put: 0.
        blendState unsignedLongAt: 29 put: 1.
        blendState pointerAt: 33 put: blendAttach.
        blendState unsignedLongAt: 41 put: 0.
        blendState unsignedLongAt: 45 put: 0.
        blendState unsignedLongAt: 49 put: 0.
        blendState unsignedLongAt: 53 put: 0.
        dynStates unsignedLongAt: 1 put: 0.
        dynStates unsignedLongAt: 5 put: 1.
        dynState unsignedLongAt: 1 put: 27.
        dynState pointerAt: 9 put: ExternalAddress null.
        dynState unsignedLongAt: 17 put: 0.
        dynState unsignedLongAt: 21 put: 2.
        dynState pointerAt: 25 put: dynStates.
        createInfo unsignedLongAt: 1 put: 28.
        createInfo pointerAt: 9 put: ExternalAddress null.
        createInfo unsignedLongAt: 17 put: 0.
        createInfo unsignedLongAt: 21 put: 2.
        createInfo pointerAt: 25 put: stagesBuf.
        createInfo pointerAt: 33 put: vertInput.
        createInfo pointerAt: 41 put: inputAssembly.
        createInfo pointerAt: 49 put: ExternalAddress null.
        createInfo pointerAt: 57 put: viewportState.
        createInfo pointerAt: 65 put: rasterState.
        createInfo pointerAt: 73 put: sampleState.
        createInfo pointerAt: 81 put: ExternalAddress null.
        createInfo pointerAt: 89 put: blendState.
        createInfo pointerAt: 97 put: dynState.
        createInfo pointerAt: 105 put: layout handle getHandle.
        createInfo pointerAt: 113 put: aRenderPass handle getHandle.
        createInfo unsignedLongAt: 121 put: 0.
        createInfo pointerAt: 129 put: ExternalAddress null.
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
