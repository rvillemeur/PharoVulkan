"
VkPipelineColorBlendStateCreateInfo: how the fragments of every colour attachment are combined with what is already in them — the run of per-attachment states, the logic operation that can replace blending, and the four blend constants. Declared field by field, so uFFI computes the eleven offsets; C declares the constants as one array of four floats, which uFFI here cannot do, so they are declared one component at a time at the same offsets and the structure is fifty-six bytes either way.

VkGraphicsPipeline class >> colorBlendState is the one writer: it allocates the attachment run, writes it and points the state at it. The state owns that run, so freeColorBlendState: frees the run and nulls the field before freeing the state's own store. initializeConstantFields stamps sType, the only field fixed by the type. colorBlendRows decodes it for the Colour blend tab and nests the attachment's own report where the run is there.
"
Class {
	#name : 'VkPipelineColorBlendStateCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ATTACHMENTCOUNT',
		'OFFSET_BLENDCONSTANTALPHA',
		'OFFSET_BLENDCONSTANTBLUE',
		'OFFSET_BLENDCONSTANTGREEN',
		'OFFSET_BLENDCONSTANTRED',
		'OFFSET_FLAGS',
		'OFFSET_LOGICOP',
		'OFFSET_LOGICOPENABLE',
		'OFFSET_PATTACHMENTS',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPipelineColorBlendStateCreateInfo class >> exampleStateOfTheOneAttachmentThisProjectWritesTo [
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

{ #category : 'field definition' }
VkPipelineColorBlendStateCreateInfo class >> fieldsDesc [
	"The logic operation flag and its operation are a pair at twenty and twenty-four, the
	 attachment count follows at twenty-eight and the run pointer re-aligns to thirty-two.
	 C declares the blend constants as one array of four floats at forty; uFFI here cannot
	 declare an array field, so the four components are declared one at a time and land at the
	 same offsets, which makes the same fifty-six bytes."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 logicOpEnable;
		int32 logicOp;
		uint32 attachmentCount;
		void* pAttachments;
		float blendConstantRed;
		float blendConstantGreen;
		float blendConstantBlue;
		float blendConstantAlpha
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> attachmentCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ATTACHMENTCOUNT
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> attachmentCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ATTACHMENTCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantAlpha [
	"This method was automatically generated"
	^handle floatAt: OFFSET_BLENDCONSTANTALPHA
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantAlpha: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_BLENDCONSTANTALPHA put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantBlue [
	"This method was automatically generated"
	^handle floatAt: OFFSET_BLENDCONSTANTBLUE
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantBlue: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_BLENDCONSTANTBLUE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantGreen [
	"This method was automatically generated"
	^handle floatAt: OFFSET_BLENDCONSTANTGREEN
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantGreen: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_BLENDCONSTANTGREEN put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantRed [
	"This method was automatically generated"
	^handle floatAt: OFFSET_BLENDCONSTANTRED
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> blendConstantRed: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_BLENDCONSTANTRED put: anObject
]

{ #category : 'accessing' }
VkPipelineColorBlendStateCreateInfo >> colorBlendRows [
	"What this state asks for, rather than where its fields sit: how many attachments the run
	 holds, whether the run is given, and whether a logic operation replaces blending. Where
	 the run is there, the attachment's own report is nested in, because the attachment decodes
	 its own fields and this state would only restate them. Read only, so a view built from
	 this leaves the store alone."

	| rows |
	rows := Dictionary new
		        at: #attachmentCount put: self attachmentCount;
		        at: #attachmentRunGiven put: self pAttachments isNull not;
		        at: #logicOperation put: self logicOpEnable ~= 0;
		        yourself.
	self pAttachments isNull ifTrue: [ ^ rows ].
	^ rows
		  addAll:
			  (VkPipelineColorBlendAttachmentState fromHandle:
				   self pAttachments getHandle) blendAttachmentRows;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkPipelineColorBlendStateCreateInfo >> initializeConstantFields [

	self sType: VkStructureType pipelineColorBlendStateCreateInfo
]

{ #category : 'inspector' }
VkPipelineColorBlendStateCreateInfo >> inspectorColorBlend: aBuilder [
	"What this state asks the driver for, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The attachment's own rows show only where the run is there, so a
	 state whose run has been given back shows the three rows it can still answer. The rows
	 come from colorBlendRows, which only reads, so opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Colour blend'>
	| rows items |
	rows := self colorBlendRows.
	items := OrderedCollection new
		         add: { 'Attachments'. (rows at: #attachmentCount) };
		         add:
			         { 'Attachment run given'. (rows at: #attachmentRunGiven) };
		         add: { 'Logic operation'. (rows at: #logicOperation) };
		         yourself.
	(rows includesKey: #blending) ifTrue: [
		items
			add: { 'Blending'. (rows at: #blending) };
			add: { 'Channels written'. (rows at: #colorWriteMaskNames) } ].
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: items;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> logicOp [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_LOGICOP
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> logicOp: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_LOGICOP put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> logicOpEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LOGICOPENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> logicOpEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LOGICOPENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> pAttachments [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PATTACHMENTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> pAttachments: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PATTACHMENTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendStateCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
