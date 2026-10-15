"
One subpass of a render pass: which pipeline slot it binds, and the attachment references it reads as input, colour, resolve, depth-stencil and preserved attachments. Every run of references is an array, which uFFI in this image cannot declare, so each is a pointer this project sets to one reference or leaves null. Carries no chain header and so has no initializer. VkRenderPass class >> subpassDescriptionReading: is its one writer.
"
Class {
	#name : 'VkSubpassDescription',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_COLORATTACHMENTCOUNT',
		'OFFSET_FLAGS',
		'OFFSET_INPUTATTACHMENTCOUNT',
		'OFFSET_PCOLORATTACHMENTS',
		'OFFSET_PDEPTHSTENCILATTACHMENT',
		'OFFSET_PINPUTATTACHMENTS',
		'OFFSET_PIPELINEBINDPOINT',
		'OFFSET_PPRESERVEATTACHMENTS',
		'OFFSET_PRESERVEATTACHMENTCOUNT',
		'OFFSET_PRESOLVEATTACHMENTS'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkSubpassDescription class >> exampleSubpassReadingOneColourAttachment [
	"One click: the one subpass of every pass here, written by its one writer. Its pointer to
	 the reference is cleared before the copy is kept, because the reference is freed with
	 the example: a kept address would say a run is there when its memory has gone back."

	<sampleInstance>
	| reference |
	reference := VkRenderPass colorAttachmentReference.
	^ [ | subpass |
	  subpass := VkRenderPass subpassDescriptionReading: reference.
	  [ subpass pColorAttachments: ExternalAddress null.
	    subpass copyIntoObjectMemory ] ensure: [ subpass getHandle free ] ] ensure: [
		  reference getHandle free ]
]

{ #category : 'field definition' }
VkSubpassDescription class >> fieldsDesc [
	"Five counts and the flags among five pointers to attachment references. Each pointer is
	 declared void*, because a run of references is an array and uFFI in this image cannot
	 declare an array field."

	^ #( uint32 flags; int32 pipelineBindPoint; uint32 inputAttachmentCount;
	     void* pInputAttachments; uint32 colorAttachmentCount;
	     void* pColorAttachments; void* pResolveAttachments;
	     void* pDepthStencilAttachment; uint32 preserveAttachmentCount;
	     void* pPreserveAttachments )
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> colorAttachmentCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_COLORATTACHMENTCOUNT
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> colorAttachmentCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_COLORATTACHMENTCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> inputAttachmentCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_INPUTATTACHMENTCOUNT
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> inputAttachmentCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_INPUTATTACHMENTCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pColorAttachments [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PCOLORATTACHMENTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pColorAttachments: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PCOLORATTACHMENTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pDepthStencilAttachment [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PDEPTHSTENCILATTACHMENT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pDepthStencilAttachment: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PDEPTHSTENCILATTACHMENT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pInputAttachments [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PINPUTATTACHMENTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pInputAttachments: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PINPUTATTACHMENTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pPreserveAttachments [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PPRESERVEATTACHMENTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pPreserveAttachments: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PPRESERVEATTACHMENTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pResolveAttachments [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PRESOLVEATTACHMENTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pResolveAttachments: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PRESOLVEATTACHMENTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pipelineBindPoint [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_PIPELINEBINDPOINT
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> pipelineBindPoint: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_PIPELINEBINDPOINT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> preserveAttachmentCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_PRESERVEATTACHMENTCOUNT
]

{ #category : 'accessing - structure variables' }
VkSubpassDescription >> preserveAttachmentCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_PRESERVEATTACHMENTCOUNT put: anObject
]
