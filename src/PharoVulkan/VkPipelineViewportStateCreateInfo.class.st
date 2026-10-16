"
VkPipelineViewportStateCreateInfo: how many viewports and scissor rectangles the pipeline draws into, and the runs of rectangles themselves where they are fixed at creation. Declared field by field, so uFFI computes the seven offsets; each count is followed by a pointer that re-aligns to eight, which makes the structure forty-eight bytes.

VkGraphicsPipeline class >> viewportState is the one writer, and it owns nothing: it gives both counts and no runs, because both rectangles are dynamic states here and the command buffer sets them while recording. initializeConstantFields stamps sType, the only field fixed by the type. viewportRows decodes it for the Viewport tab.
"
Class {
	#name : 'VkPipelineViewportStateCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_PSCISSORS',
		'OFFSET_PVIEWPORTS',
		'OFFSET_SCISSORCOUNT',
		'OFFSET_STYPE',
		'OFFSET_VIEWPORTCOUNT'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPipelineViewportStateCreateInfo class >> exampleStateOfTheDynamicViewportThisProjectUses [
	"One click: the viewport state every pipeline here is created from, needing no device. Both
	 counts are there and neither run is, which is how a dynamic rectangle is declared. The
	 copy lives in object memory, so it still reads after the external store goes."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline viewportState.
	^ [ state copyIntoObjectMemory ] ensure: [ state getHandle free ]
]

{ #category : 'field definition' }
VkPipelineViewportStateCreateInfo class >> fieldsDesc [
	"A count and a run pointer for the viewports, then the same pair for the scissors. Each
	 count is a uint32 and each pointer re-aligns to eight, so uFFI lays them out at twenty,
	 twenty-four, thirty-two and forty, which makes forty-eight bytes."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 viewportCount;
		void* pViewports;
		uint32 scissorCount;
		void* pScissors
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkPipelineViewportStateCreateInfo >> initializeConstantFields [

	self sType: VkStructureType pipelineViewportStateCreateInfo
]

{ #category : 'inspector' }
VkPipelineViewportStateCreateInfo >> inspectorViewport: aBuilder [
	"What this state asks the driver for, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from viewportRows, which only reads, so opening
	 the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Viewport'>
	| rows |
	rows := self viewportRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Viewports'. (rows at: #viewportCount) }.
				  { 'Viewport run given'. (rows at: #viewportRunGiven) }.
				  { 'Scissors'. (rows at: #scissorCount) }.
				  { 'Scissor run given'. (rows at: #scissorRunGiven) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> pScissors [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSCISSORS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> pScissors: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSCISSORS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> pViewports [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PVIEWPORTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> pViewports: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PVIEWPORTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> scissorCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SCISSORCOUNT
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> scissorCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SCISSORCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> viewportCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VIEWPORTCOUNT
]

{ #category : 'accessing - structure variables' }
VkPipelineViewportStateCreateInfo >> viewportCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VIEWPORTCOUNT put: anObject
]

{ #category : 'accessing' }
VkPipelineViewportStateCreateInfo >> viewportRows [
	"What this state asks for, rather than where its fields sit: how many of each rectangle the
	 pipeline draws into, and whether a run of either is given. A count with no run is how a
	 dynamic rectangle is declared: the command buffer sets it while recording. Read only, so a
	 view built from this leaves the store alone."

	^ Dictionary new
		  at: #viewportCount put: self viewportCount;
		  at: #viewportRunGiven put: self pViewports isNull not;
		  at: #scissorCount put: self scissorCount;
		  at: #scissorRunGiven put: self pScissors isNull not;
		  yourself
]
