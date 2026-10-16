"
VkPipelineColorBlendAttachmentState: what becomes of one colour attachment's fragments — whether they are blended with what is already there, with which factors and operations, and which channels they are written to. Declared field by field, so uFFI computes the eight offsets; there is no chain header, because an attachment state is pointed at by a create info rather than being one, which makes it thirty-two bytes.

VkGraphicsPipeline class >> colorBlendState is the one writer: it allocates the run of attachments the colour blend state points at and writes the channel mask into each, leaving the factors and the operations as the zeroed block left them, which the driver ignores while blending is off. There is no initializeConstantFields, because no field here is fixed by the type. blendAttachmentRows decodes it for the Blending tab, naming the channels through VkColorComponent.
"
Class {
	#name : 'VkPipelineColorBlendAttachmentState',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ALPHABLENDOP',
		'OFFSET_BLENDENABLE',
		'OFFSET_COLORBLENDOP',
		'OFFSET_COLORWRITEMASK',
		'OFFSET_DSTALPHABLENDFACTOR',
		'OFFSET_DSTCOLORBLENDFACTOR',
		'OFFSET_SRCALPHABLENDFACTOR',
		'OFFSET_SRCCOLORBLENDFACTOR'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPipelineColorBlendAttachmentState class >> exampleAttachmentThisProjectWritesEveryChannelOf [
	"One click: the one attachment state every pipeline here is created from, read out of the
	 run the colour blend state owns. The copy lives in object memory, so it still reads after
	 the run and the state have gone."

	<sampleInstance>
	| state |
	state := VkGraphicsPipeline colorBlendState.
	^ [ (self fromHandle: state pAttachments getHandle) copyIntoObjectMemory ]
		  ensure: [ VkGraphicsPipeline freeColorBlendState: state ]
]

{ #category : 'field definition' }
VkPipelineColorBlendAttachmentState class >> fieldsDesc [
	"Eight four-byte fields and no chain header: an attachment state is pointed at by a create
	 info rather than being one, so it carries no sType and no pNext. blendEnable is a VkBool32
	 and declared as the uint32 it is; the factors and the operations are enumerations and so
	 declared signed, as every other enumeration field here is; the write mask is a bitmask and
	 unsigned."

	^ #(
		uint32 blendEnable;
		int32 srcColorBlendFactor;
		int32 dstColorBlendFactor;
		int32 colorBlendOp;
		int32 srcAlphaBlendFactor;
		int32 dstAlphaBlendFactor;
		int32 alphaBlendOp;
		uint32 colorWriteMask
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> alphaBlendOp [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_ALPHABLENDOP
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> alphaBlendOp: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_ALPHABLENDOP put: anObject
]

{ #category : 'accessing' }
VkPipelineColorBlendAttachmentState >> blendAttachmentRows [
	"What becomes of this attachment's fragments, rather than where the fields sit: whether
	 the fragment is blended with what is already there, and which channels it is written to,
	 named through VkColorComponent rather than shown as a mask. Read only, so a view built
	 from this leaves the store alone."

	^ Dictionary new
		  at: #blending put: self blendEnable ~= 0;
		  at: #colorWriteMaskNames
		  put: (VkColorComponent nameForFlags: self colorWriteMask);
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> blendEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BLENDENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> blendEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BLENDENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> colorBlendOp [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_COLORBLENDOP
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> colorBlendOp: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_COLORBLENDOP put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> colorWriteMask [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_COLORWRITEMASK
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> colorWriteMask: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_COLORWRITEMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> dstAlphaBlendFactor [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_DSTALPHABLENDFACTOR
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> dstAlphaBlendFactor: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_DSTALPHABLENDFACTOR put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> dstColorBlendFactor [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_DSTCOLORBLENDFACTOR
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> dstColorBlendFactor: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_DSTCOLORBLENDFACTOR put: anObject
]

{ #category : 'inspector' }
VkPipelineColorBlendAttachmentState >> inspectorBlendAttachment: aBuilder [
	"What becomes of this attachment's fragments, rather than where the fields sit: the Layout
	 and Fields tabs answer that. The rows come from blendAttachmentRows, which only reads, so
	 opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Blending'>
	| rows |
	rows := self blendAttachmentRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Blending'. (rows at: #blending) }.
				  { 'Channels written'. (rows at: #colorWriteMaskNames) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> srcAlphaBlendFactor [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_SRCALPHABLENDFACTOR
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> srcAlphaBlendFactor: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_SRCALPHABLENDFACTOR put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> srcColorBlendFactor [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_SRCCOLORBLENDFACTOR
]

{ #category : 'accessing - structure variables' }
VkPipelineColorBlendAttachmentState >> srcColorBlendFactor: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_SRCCOLORBLENDFACTOR put: anObject
]
