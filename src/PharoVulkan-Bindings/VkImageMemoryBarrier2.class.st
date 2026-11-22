"
A VkImageMemoryBarrier2 as synchronization2 declares it: the stage and access masks of both
sides as quad words, the layout the image is in and the layout it is to be in, the queue
families it moves between, the image itself and the subresource range the transition covers.
It is the barrier a copy into an image needs, because a copy destination has to be in the
transfer destination layout and the layout before it is whatever the last user left.
VkCommandBuffer records it; fieldsDesc states the layout and VkStructure maps it.
"
Class {
	#name : 'VkImageMemoryBarrier2',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DSTACCESSMASK',
		'OFFSET_DSTQUEUEFAMILYINDEX',
		'OFFSET_DSTSTAGEMASK',
		'OFFSET_IMAGE',
		'OFFSET_NEWLAYOUT',
		'OFFSET_OLDLAYOUT',
		'OFFSET_PNEXT',
		'OFFSET_SRCACCESSMASK',
		'OFFSET_SRCQUEUEFAMILYINDEX',
		'OFFSET_SRCSTAGEMASK',
		'OFFSET_STYPE',
		'OFFSET_SUBRESOURCERANGE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkImageMemoryBarrier2 class >> fieldsDesc [
	"Synchronization2 widened the stage and access masks to sixty-four bits, so each of the four
	 is a quad word. The image is a handle, and the subresource range is carried by value, which
	 is why its getter answers a view onto this structure''s own store."

	^ #( int32 sType; void* pNext;
	     uint64 srcStageMask; uint64 srcAccessMask;
	     uint64 dstStageMask; uint64 dstAccessMask;
	     int32 oldLayout; int32 newLayout;
	     uint32 srcQueueFamilyIndex; uint32 dstQueueFamilyIndex;
	     VkImage_H* image; VkImageSubresourceRange subresourceRange )
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> dstAccessMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_DSTACCESSMASK
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> dstAccessMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_DSTACCESSMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> dstQueueFamilyIndex [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DSTQUEUEFAMILYINDEX
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> dstQueueFamilyIndex: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DSTQUEUEFAMILYINDEX put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> dstStageMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_DSTSTAGEMASK
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> dstStageMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_DSTSTAGEMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> image [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_IMAGE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> image: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_IMAGE put: anObject getHandle.
]

{ #category : 'initialization' }
VkImageMemoryBarrier2 >> initializeConstantFields [
	"Only the structure type is fixed by the type. The masks, the layouts, the queue families,
	 the image and the subresource range all belong to the recorder."

	self sType: VkStructureType imageMemoryBarrier2
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> newLayout [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_NEWLAYOUT
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> newLayout: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_NEWLAYOUT put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> oldLayout [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_OLDLAYOUT
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> oldLayout: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_OLDLAYOUT put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> srcAccessMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_SRCACCESSMASK
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> srcAccessMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_SRCACCESSMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> srcQueueFamilyIndex [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SRCQUEUEFAMILYINDEX
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> srcQueueFamilyIndex: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SRCQUEUEFAMILYINDEX put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> srcStageMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_SRCSTAGEMASK
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> srcStageMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_SRCSTAGEMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> subresourceRange [
	"This method was automatically generated"
	^ VkImageSubresourceRange fromHandle: (handle referenceStructAt: OFFSET_SUBRESOURCERANGE length: VkImageSubresourceRange byteSize)
]

{ #category : 'accessing - structure variables' }
VkImageMemoryBarrier2 >> subresourceRange: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_SUBRESOURCERANGE put: anObject getHandle length: VkImageSubresourceRange byteSize
]
