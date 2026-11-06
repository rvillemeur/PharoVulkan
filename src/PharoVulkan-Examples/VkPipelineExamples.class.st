"
Examples of every structure a pipeline is created from: the compute request and the graphics request, the shader stages, and each piece of fixed-function state the graphics pipeline of this project names — vertex input, input assembly, viewport, rasterization, multisample, colour blend and dynamic state — together with the vertex binding and attribute, the viewport and the scissor the triangle is drawn through.

The graphics request example owns the nested states it points at and frees them before it answers, so a click leaves nothing allocated. The others are built in object memory with their pointers null. Reading them in the order the graphics request names them shows the whole tree the driver is handed.
"
Class {
	#name : 'VkPipelineExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPipelineExamples class >> bindingOfTheVertexThisProjectDraws [
	<sampleInstance>
	"One click: the one buffer binding this project's pipeline reads its vertices from, which is
	 the description VkGraphicsPipeline hands the driver. Built in object memory, so a click
	 frees nothing, and rebuilt on every call."

	^ VkGraphicsPipeline vertexBindingDescriptions first
]

{ #category : 'examples' }
VkPipelineExamples class >> blendAttachmentThisProjectWritesEveryChannelOf [
	"One click: the one attachment state every pipeline here is created from, read out of the
	 run the colour blend state owns. The copy lives in object memory, so it still reads after
	 the run and the state have gone."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline colorBlendState.
	^ [ (VkPipelineColorBlendAttachmentState fromHandle: state pAttachments getHandle) copyIntoObjectMemory ]
		  ensure: [ VkGraphicsPipeline freeColorBlendState: state ]
]

{ #category : 'examples' }
VkPipelineExamples class >> colourBlendStateOfTheOneAttachmentThisProjectWritesTo [
	"One click: the colour blend state every pipeline here is created from, needing no device.
	 The attachment run is given back before the copy is taken, because the run goes with the
	 state it was built with and a copy pointing at freed memory would read it; the copy lives
	 in object memory, so it still reads after the external store goes."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline colorBlendState.
	^ [
	  VkGraphicsPipeline freeColorBlendAttachmentsOf: state.
	  state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> dynamicStateOfTheRectanglesThisProjectSetsWhileRecording [
	"One click: the dynamic state every pipeline here is created from, needing no device. The
	 run of state values is given back before the copy is taken, because the run goes with the
	 state it was built with and a copy pointing at freed memory would read it; the copy lives
	 in object memory, so it still reads after the external store goes."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline dynamicState.
	^ [
	  VkGraphicsPipeline freeDynamicStatesOf: state.
	  state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> inputAssemblyStateOfTheTriangleListThisProjectDraws [
	"One click: the input assembly state every pipeline here is created from, needing no device.
	 The copy lives in object memory, so it still reads after the external store goes."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline inputAssemblyState.
	^ [ state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> multisampleStateOfTheOneSamplePerPixelThisProjectTakes [
	"One click: the multisample state every pipeline here is created from, needing no device.
	 The copy lives in object memory, so it still reads after the external store goes."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline multisampleState.
	^ [ state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> positionAttributeOfTheVertexThisProjectDraws [
	<sampleInstance>
	"One click: the position attribute of the vertex this project draws — two floats at the
	 start of each vertex. Built in object memory, so a click frees nothing, and rebuilt on
	 every call; the colour attribute that follows it is the second of the same list."

	^ VkGraphicsPipeline vertexAttributeDescriptions first
]

{ #category : 'examples' }
VkPipelineExamples class >> rasterizationStateOfTheFilledTrianglesThisProjectDraws [
	"One click: the rasterization state every pipeline here is created from, needing no device.
	 The copy lives in object memory, so it still reads after the external store goes."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline rasterizationState.
	^ [ state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> requestForAComputeShader [
	"One click: the request this project creates a compute pipeline from, built with null
	 handles so no device is needed. The entry point string is given back and the field nulled
	 before the copy is taken, so the copy names no freed address; the copy lives in object
	 memory, so it still reads after the external store goes."

	<sampleInstance>
	| request |
	request := VkComputePipeline
		           createInfoForModule:
		           (VkShaderModule_H fromHandle: ExternalAddress null)
		           entryPoint: VkShaderModule defaultEntryPoint
		           layout: (VkPipelineLayout_H fromHandle: ExternalAddress null).
	^ [
	  VkComputePipeline freeEntryPointOf: request.
	  request copyIntoObjectMemory ] ensure: [ request getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> requestOfTheTriangleThisProjectDraws [
	"One click: the request the triangle this project draws is created from, built with null
	 handles so no device is needed. Everything the request points at is given back before the
	 copy is taken — the six states it owns through the pipeline, and then the stage run and the
	 vertex input state, which belong to the caller and are freed after the copy — so the
	 answered request says those addresses are not there rather than naming memory that has
	 gone. The copy lives in object memory, so the Request tab still reads after every external
	 store goes."

	<sampleInstance>
	| stages vertInput request |
	stages := VkGraphicsPipeline
		          shaderStagesForVertexModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null)
		          fragmentModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null).
	vertInput := VkGraphicsPipeline
		             vertexInputStateForBindings:
		             VkGraphicsPipeline vertexBindingDescriptions
		             attributes: VkGraphicsPipeline vertexAttributeDescriptions.
	request := VkGraphicsPipeline
		           requestForStages: stages
		           vertexInput: vertInput
		           layout: (VkPipelineLayout_H fromHandle: ExternalAddress null)
		           renderPass: (VkRenderPass_H fromHandle: ExternalAddress null).
	^ [
	  VkGraphicsPipeline freeNestedStatesOf: request.
	  request
		  pStages: ExternalAddress null;
		  pVertexInputState: ExternalAddress null.
	  request copyIntoObjectMemory ] ensure: [
		  request getHandle free.
		  VkGraphicsPipeline freeVertexInputState: vertInput.
		  VkGraphicsPipeline freeShaderStages: stages ]
]

{ #category : 'examples' }
VkPipelineExamples class >> scissorCoveringAnExampleTarget [
	"One click: the scissor rectangle every draw in this project binds, built by the recorder
	 for a non-square example extent. It clips nothing, which is what an offset of zero and an
	 extent of the whole target mean. The structure holds no pointer, so the object memory copy
	 is the whole rectangle."

	<sampleInstance>
	| scissor |
	scissor := VkCommandBuffer scissorForExtent:
		           VkBufferImageCopy exampleExtent.
	^ [ scissor copyIntoObjectMemory ] ensure: [ scissor getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> shaderModuleRequestForTheVectorAddKernel [
	"One click: the request VkShaderModule builds for the README's playground kernel, compiled
	 here and measured. No device is asked, so no module is created; the byte count the
	 project fills and the degenerate state of the rest can be read in the Layout and Fields
	 tabs. The answer lives in object memory with its code pointer cleared, because the block
	 the pointer named has been freed."

	<sampleInstance>
	| info bytes code kept |
	info := VkShaderModuleCreateInfo externalInstance.
	bytes := PVKernelCompiler compileMethod:
		         PVComputeKernel exampleKernelMethod.
	code := VkShaderModule codeOutsideObjectMemory: bytes.
	^ [
	  info
		  codeSize: bytes size;
		  pCode: code.
	  kept := info copyIntoObjectMemory.
	  kept pCode: ExternalAddress null.
	  kept ] ensure: [
		  code free.
		  info getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> stagesOfTheTriangleThisProjectDraws [
	"One click: the two stages the triangle this project draws is created from, built with null
	 module handles so no device is needed. The entry point strings are given back before the
	 copies are taken, so each copy says the name is gone rather than naming an address that
	 has been freed; the copies live in object memory, so they still read after the run goes."

	<sampleInstance>
	| stages |
	stages := VkGraphicsPipeline
		          shaderStagesForVertexModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null)
		          fragmentModule: (VkShaderModule_H fromHandle: ExternalAddress null).
	^ [
	  VkGraphicsPipeline freeShaderStageEntryPointsOf: stages.
	  stages collect: [ :each | each copyIntoObjectMemory ] ] ensure: [
		  stages first getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> vertexInputStateOfTheTriangleThisProjectDraws [
	<sampleInstance>
	"One click: the vertex input state this project's pipeline is created with, rebuilt on every
	 call. The two runs are freed and their fields nulled before the copy, so the answered state
	 in object memory says the runs are not there rather than pointing at memory that has gone,
	 and the external store is freed whatever happens. The Binding and Attribute tabs of the
	 description examples show what those runs held."

	| state |
	state := VkGraphicsPipeline
		         vertexInputStateForBindings:
		         VkGraphicsPipeline vertexBindingDescriptions
		         attributes: VkGraphicsPipeline vertexAttributeDescriptions.
	^ [
	  VkGraphicsPipeline freeVertexInputRunsOf: state.
	  state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> viewportCoveringAnExampleTarget [
	"One click: the viewport every draw in this project binds, built by the recorder for a
	 non-square example extent so the width and the height cannot be read for each other. No
	 device is touched. The structure is copied into object memory and its block freed, and it
	 holds no pointer, so the copy is the whole viewport."

	<sampleInstance>
	| viewport |
	viewport := VkCommandBuffer viewportForExtent:
		            VkBufferImageCopy exampleExtent.
	^ [ viewport copyIntoObjectMemory ] ensure: [ viewport getHandle free ]
]

{ #category : 'examples' }
VkPipelineExamples class >> viewportStateOfTheDynamicViewportThisProjectUses [
	"One click: the viewport state every pipeline here is created from, needing no device. Both
	 counts are there and neither run is, which is how a dynamic rectangle is declared. The
	 copy lives in object memory, so it still reads after the external store goes."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline viewportState.
	^ [ state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]
