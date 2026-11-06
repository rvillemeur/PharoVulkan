"
The request vkCreateFramebuffer reads: which render pass's attachments are bound, the attachment views as a count and a pointer, the extent they cover and how many layers deep the framebuffer is. The attachment views are a run of handles rather than a structure, so uFFI cannot declare them as a field: VkFramebuffer class >> attachmentsOutsideObjectMemory: writes the run by a named stride and this request points at it. VkFramebuffer class >> createInfoForRenderPass:attachments:extent: is its one writer, and framebufferRows is what the Framebuffer tab reads.
"
Class {
	#name : 'VkFramebufferCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ATTACHMENTCOUNT',
		'OFFSET_FLAGS',
		'OFFSET_HEIGHT',
		'OFFSET_LAYERS',
		'OFFSET_PATTACHMENTS',
		'OFFSET_PNEXT',
		'OFFSET_RENDERPASS',
		'OFFSET_STYPE',
		'OFFSET_WIDTH'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'constants' }
VkFramebufferCreateInfo class >> attachmentByteCount [
	"An attachment entry is one handle wide. The run this request points at has no field
	 specification to read a width from, because uFFI in this image cannot declare an array
	 field, so the stride is named by the structure that declares the pointer."

	^ ExternalAddress wordSize
]

{ #category : 'field definition' }
VkFramebufferCreateInfo class >> fieldsDesc [
	"The render pass is a handle, so it is declared as one. The attachment views are a run of
	 handles rather than a structure, so they are pointed at: uFFI in this image cannot declare
	 an array field, and the run is written and read by a named stride."

	^ #( int32 sType; void* pNext; uint32 flags; VkRenderPass_H* renderPass;
	     uint32 attachmentCount; void* pAttachments; uint32 width; uint32 height;
	     uint32 layers )
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> attachmentCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ATTACHMENTCOUNT
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> attachmentCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ATTACHMENTCOUNT put: anObject
]

{ #category : 'accessing' }
VkFramebufferCreateInfo >> attachmentHandlesSet [
	"Whether each attachment handle in the run this request points at is set, one boolean per
	 attachment the request names. The run is a block of handles with no field specification, so
	 it is read by the stride this class names rather than by an offset counted here. A request
	 pointing nowhere answers none, so a reader is never shown a handle read from address zero."

	self pAttachments isNull ifTrue: [ ^ #(  ) ].
	^ (1 to: self attachmentCount) collect: [ :index |
		  (self pAttachments getHandle pointerAt:
			   index - 1 * self class attachmentByteCount + 1) isNull not ]
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'reporting' }
VkFramebufferCreateInfo >> framebufferRows [
	"What this request binds: the extent as a point, the layer count, and the attachment views
	 as how many the request names and whether each handle in the run is set. The run has no
	 field specification to read an offset from, so the handles are read by the stride
	 VkFramebuffer names; a request pointing nowhere answers no handles rather than reading
	 whatever lies at address zero. The render pass is reported as set or not, because its
	 address says nothing to a reader. Read only, so the tab leaves the store alone."

	^ Dictionary new
		  at: #renderPassSet put: self renderPass isNull not;
		  at: #extent put: self width @ self height;
		  at: #layers put: self layers;
		  at: #attachmentCount put: self attachmentCount;
		  at: #attachmentsSet put: self attachmentHandlesSet;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> height [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_HEIGHT
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> height: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_HEIGHT put: anObject
]

{ #category : 'initialization' }
VkFramebufferCreateInfo >> initializeConstantFields [
	"The structure type is the only field fixed by the type. The layer count is one for every
	 framebuffer this project creates, but it is a caller's choice rather than a property of
	 the structure, and a request naming no attachment must not claim a layer."

	self sType: VkStructureType framebufferCreateInfo
]

{ #category : 'inspector' }
VkFramebufferCreateInfo >> inspectorFramebuffer: aBuilder [
	"What the driver is asked to bind, rather than where the fields sit: the Layout and Fields
	 tabs answer that. The rows come from framebufferRows, which reads the store and the
	 attachment run through the named stride, so opening the tab changes nothing and no handle
	 is dereferenced."

	<inspectorPresentationOrder: 30 title: 'Framebuffer'>
	| rows |
	rows := self framebufferRows.
	^ PVFactRow
		  tableOf: {
				  (PVFactRow
					   name: 'Render pass set'
					   value: (rows at: #renderPassSet)).
				  (PVFactRow name: 'Extent' value: (rows at: #extent)).
				  (PVFactRow name: 'Layers' value: (rows at: #layers)).
				  (PVFactRow
					   name: 'Attachments'
					   value: (rows at: #attachmentCount)).
				  (PVFactRow
					   name: 'Attachment handles set'
					   value: (rows at: #attachmentsSet)) }
		  nameColumn: 'Binds'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> layers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LAYERS
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> layers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LAYERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> pAttachments [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PATTACHMENTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> pAttachments: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PATTACHMENTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> renderPass [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_RENDERPASS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> renderPass: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_RENDERPASS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> width [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_WIDTH
]

{ #category : 'accessing - structure variables' }
VkFramebufferCreateInfo >> width: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_WIDTH put: anObject
]
