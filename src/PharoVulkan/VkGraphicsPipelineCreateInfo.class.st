"
Declared VkGraphicsPipelineCreateInfo: the one request a graphics pipeline is created from. Every nested state is pointed at rather than nested by value, unlike the single stage inside a compute request, so the fields are nine state pointers, the stage run, the pipeline layout, the render pass and the subpass, and the base pipeline a derivative would name.

VkGraphicsPipeline class >> requestForStages:vertexInput:layout:renderPass: is the only writer: it builds the six states that need no device and points at the stage run and the vertex input state the caller passed in, which need a module and a vertex layout to build. The request owns the six it built — freeNestedStatesOf: gives them back and nulls each field, freeRequest: does that and then the request's own store. The states this project does not ask for, tessellation and depth stencil, stay as the zeroed block left them.

statesGiven reads which state pointers are there, over the field names stateFieldNames takes from the declared layout, so a state added to fieldsDesc is reported without the report being touched; graphicsRequestRows adds the counts and the handles and is what the Request tab shows. No row follows a pointer, because a request whose states have been given back holds freed addresses.
"
Class {
	#name : 'VkGraphicsPipelineCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BASEPIPELINEHANDLE',
		'OFFSET_BASEPIPELINEINDEX',
		'OFFSET_FLAGS',
		'OFFSET_LAYOUT',
		'OFFSET_PCOLORBLENDSTATE',
		'OFFSET_PDEPTHSTENCILSTATE',
		'OFFSET_PDYNAMICSTATE',
		'OFFSET_PINPUTASSEMBLYSTATE',
		'OFFSET_PMULTISAMPLESTATE',
		'OFFSET_PNEXT',
		'OFFSET_PRASTERIZATIONSTATE',
		'OFFSET_PSTAGES',
		'OFFSET_PTESSELLATIONSTATE',
		'OFFSET_PVERTEXINPUTSTATE',
		'OFFSET_PVIEWPORTSTATE',
		'OFFSET_RENDERPASS',
		'OFFSET_STAGECOUNT',
		'OFFSET_STYPE',
		'OFFSET_SUBPASS'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkGraphicsPipelineCreateInfo class >> exampleRequestOfTheTriangleThisProjectDraws [
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

{ #category : 'field definition' }
VkGraphicsPipelineCreateInfo class >> fieldsDesc [
	"The one request a graphics pipeline is created from. Every nested state is pointed at
	 rather than nested by value, unlike the single stage of a compute request, so each of those
	 fields is one pointer wide and the states are allocated and freed separately. flags and
	 stageCount are a uint32 pair at sixteen and twenty; subpass is a word at one hundred and
	 twenty which uFFI pads to one hundred and twenty-eight for the handle after it. layout,
	 renderPass and basePipelineHandle are handles and therefore pointer wide. basePipelineIndex
	 is a signed int32, which is why the sentinel for no base pipeline is minus one rather than
	 the unsigned value with every bit set."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 stageCount;
		void* pStages;
		void* pVertexInputState;
		void* pInputAssemblyState;
		void* pTessellationState;
		void* pViewportState;
		void* pRasterizationState;
		void* pMultisampleState;
		void* pDepthStencilState;
		void* pColorBlendState;
		void* pDynamicState;
		VkPipelineLayout_H* layout;
		VkRenderPass_H* renderPass;
		uint32 subpass;
		VkPipeline_H* basePipelineHandle;
		int32 basePipelineIndex
	)
]

{ #category : 'accessing' }
VkGraphicsPipelineCreateInfo class >> stateFieldNames [
	"The nested state fields of a request, read out of the declared layout rather than listed
	 here: a state added to fieldsDesc is reported by the Request tab without this method being
	 touched. Every such field in Vulkan is named for the state it points at."

	^ (self layoutRows collect: [ :each | each first ]) select: [ :each |
		  each endsWith: 'State' ]
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> basePipelineHandle [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_BASEPIPELINEHANDLE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> basePipelineHandle: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_BASEPIPELINEHANDLE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> basePipelineIndex [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_BASEPIPELINEINDEX
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> basePipelineIndex: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_BASEPIPELINEINDEX put: anObject
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing' }
VkGraphicsPipelineCreateInfo >> graphicsRequestRows [
	"What this request asks for, read out of its own fields rather than restated from the
	 arguments the builder was given: how many stages, which nested states are there, whether
	 the layout and the render pass are named, which subpass it draws in and whether it derives
	 from another pipeline. Each call builds fresh rows and follows no pointer, so a view built
	 from this leaves the store alone."

	^ (Dictionary newFrom: {
			   (#stageCount -> self stageCount).
			   (#stagesGiven -> self pStages isNull not).
			   (#statesGiven -> (', ' join: self statesGiven)).
			   (#layoutGiven -> self layout isNull not).
			   (#renderPassGiven -> self renderPass isNull not).
			   (#subpass -> self subpass).
			   (#derivesFromAPipeline -> self basePipelineHandle isNull not).
			   (#basePipelineIndex -> self basePipelineIndex) })
		  beReadOnlyObject
]

{ #category : 'initialization' }
VkGraphicsPipelineCreateInfo >> initializeConstantFields [
	"The structure type is the only field fixed by the type of request. Every state pointer, the
	 layout, the render pass and the subpass belong to the caller, and the zeroed block already
	 reads as a request with no stages."

	self sType: VkStructureType graphicsPipelineCreateInfo
]

{ #category : 'inspector' }
VkGraphicsPipelineCreateInfo >> inspectorGraphicsRequest: aBuilder [
	"What the driver is asked to build, laid out from the report: the stage count, the nested
	 states that are given, the layout and render pass the pipeline draws through, the subpass
	 and the base pipeline. The rows are read only and follow no pointer, so opening the tab
	 cannot change the request or read a state that has been given back."

	<inspectorPresentationOrder: 30 title: 'Request'>
	| rows |
	rows := self graphicsRequestRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Stages'. (rows at: #stageCount) }.
				  { 'Stage run given'. (rows at: #stagesGiven) }.
				  { 'States given'. (rows at: #statesGiven) }.
				  { 'Layout given'. (rows at: #layoutGiven) }.
				  { 'Render pass given'. (rows at: #renderPassGiven) }.
				  { 'Subpass'. (rows at: #subpass) }.
				  { 'Derives from a pipeline'. (rows at: #derivesFromAPipeline) }.
				  { 'Base pipeline index'. (rows at: #basePipelineIndex) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> layout [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_LAYOUT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> layout: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_LAYOUT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pColorBlendState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PCOLORBLENDSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pColorBlendState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PCOLORBLENDSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pDepthStencilState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PDEPTHSTENCILSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pDepthStencilState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PDEPTHSTENCILSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pDynamicState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PDYNAMICSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pDynamicState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PDYNAMICSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pInputAssemblyState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PINPUTASSEMBLYSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pInputAssemblyState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PINPUTASSEMBLYSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pMultisampleState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PMULTISAMPLESTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pMultisampleState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PMULTISAMPLESTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pRasterizationState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PRASTERIZATIONSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pRasterizationState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PRASTERIZATIONSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pStages [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSTAGES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pStages: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSTAGES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pTessellationState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PTESSELLATIONSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pTessellationState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PTESSELLATIONSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pVertexInputState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PVERTEXINPUTSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pVertexInputState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PVERTEXINPUTSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pViewportState [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PVIEWPORTSTATE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> pViewportState: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PVIEWPORTSTATE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> renderPass [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_RENDERPASS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> renderPass: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_RENDERPASS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> stageCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STAGECOUNT
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> stageCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STAGECOUNT put: anObject
]

{ #category : 'accessing' }
VkGraphicsPipelineCreateInfo >> statesGiven [
	"Which of the nested state fields this request points at. A state is reported as given
	 rather than followed: a request whose states have been given back holds freed addresses,
	 and reading one through the pointer would read memory that has gone."

	^ self class stateFieldNames select: [ :each |
		  (self perform: each) isNull not ]
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> subpass [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUBPASS
]

{ #category : 'accessing - structure variables' }
VkGraphicsPipelineCreateInfo >> subpass: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUBPASS put: anObject
]
