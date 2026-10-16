"
The vertex input stage of a graphics pipeline: a run of VkVertexInputBindingDescription saying which buffers are read and how wide a vertex is, and a run of VkVertexInputAttributeDescription saying what sits inside one. Declared field by field, so uFFI computes all seven offsets; forty-eight bytes, the padding after the flags and count pair putting the first run pointer on a pointer boundary. Both runs are pointed at rather than carried, so each pointer field is one pointer wide however many entries sit behind it. initializeConstantFields stamps sType alone: both counts and both pointers are a caller's choice.

VkGraphicsPipeline class >> vertexInputStateForBindings:attributes: is the one writer. The state owns the two runs it points at and is the record of where they are, so freeVertexInputRunsOf: frees each and nulls its field and freeVertexInputState: then frees the state. vertexInputRows is what the Vertex input tab reads; it says a run is given rather than following it, because the state is freed with its runs. Key methods: vertexInputRows, class-side exampleStateOfTheVertexThisProjectDraws.
"
Class {
	#name : 'VkPipelineVertexInputStateCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_PVERTEXATTRIBUTEDESCRIPTIONS',
		'OFFSET_PVERTEXBINDINGDESCRIPTIONS',
		'OFFSET_STYPE',
		'OFFSET_VERTEXATTRIBUTEDESCRIPTIONCOUNT',
		'OFFSET_VERTEXBINDINGDESCRIPTIONCOUNT'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPipelineVertexInputStateCreateInfo class >> fieldsDesc [
	"The vertex input stage of a pipeline: a run of binding descriptions and a run of attribute
	 descriptions, each with its count. Both runs are pointed at rather than carried, so each
	 pointer field is one pointer wide however many entries sit behind it."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 vertexBindingDescriptionCount;
		void* pVertexBindingDescriptions;
		uint32 vertexAttributeDescriptionCount;
		void* pVertexAttributeDescriptions
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkPipelineVertexInputStateCreateInfo >> initializeConstantFields [
	"The structure type is the only field fixed by this type. Both counts and both run pointers
	 are a caller's choice, and a pointer written in an initializer would be written again on
	 every read of a field pointing at this structure."

	self sType: VkStructureType pipelineVertexInputStateCreateInfo
]

{ #category : 'inspector' }
VkPipelineVertexInputStateCreateInfo >> inspectorVertexInput: aBuilder [
	"What the vertex stage is told to read, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from vertexInputRows, which only reads and never
	 follows a run, so opening the tab changes nothing and cannot read memory already given
	 back."

	<inspectorPresentationOrder: 30 title: 'Vertex input'>
	| rows |
	rows := self vertexInputRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Reads' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Buffer bindings'. (rows at: #vertexBindingDescriptionCount) }.
				  { 'Binding run given'. (rows at: #bindingRunGiven) }.
				  { 'Attributes'. (rows at: #vertexAttributeDescriptionCount) }.
				  { 'Attribute run given'. (rows at: #attributeRunGiven) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> pVertexAttributeDescriptions [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PVERTEXATTRIBUTEDESCRIPTIONS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> pVertexAttributeDescriptions: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PVERTEXATTRIBUTEDESCRIPTIONS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> pVertexBindingDescriptions [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PVERTEXBINDINGDESCRIPTIONS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> pVertexBindingDescriptions: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PVERTEXBINDINGDESCRIPTIONS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> vertexAttributeDescriptionCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VERTEXATTRIBUTEDESCRIPTIONCOUNT
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> vertexAttributeDescriptionCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VERTEXATTRIBUTEDESCRIPTIONCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> vertexBindingDescriptionCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VERTEXBINDINGDESCRIPTIONCOUNT
]

{ #category : 'accessing - structure variables' }
VkPipelineVertexInputStateCreateInfo >> vertexBindingDescriptionCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VERTEXBINDINGDESCRIPTIONCOUNT put: anObject
]

{ #category : 'reporting' }
VkPipelineVertexInputStateCreateInfo >> vertexInputRows [
	"How many of each description this state names, and whether each run is there. A run is
	 reported as given rather than followed: the state is handed to the driver and then freed
	 with its runs, so a view that read through a pointer could read memory already given back.
	 Read only, so a view built from this leaves the store alone."

	^ Dictionary new
		  at: #vertexBindingDescriptionCount
		  put: self vertexBindingDescriptionCount;
		  at: #bindingRunGiven put: self pVertexBindingDescriptions isNull not;
		  at: #vertexAttributeDescriptionCount
		  put: self vertexAttributeDescriptionCount;
		  at: #attributeRunGiven put: self pVertexAttributeDescriptions isNull not;
		  yourself
]
