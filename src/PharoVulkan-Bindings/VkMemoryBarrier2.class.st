"
The VkMemoryBarrier2 a recording carries inside a dependency info: the stage and access masks a barrier waits on and the ones it makes visible. The masks are sixty-four bits wide because this project uses VK_KHR_synchronization2 only, so each one is a full quad word rather than the thirty-two bit mask of the original barrier. The fields are declared, so uFFI places them; nothing here counts bytes. VkCommandBuffer class >> hostReadBarrier is the only writer, and VkPipelineStage2 and VkAccess2 name the bits.
"
Class {
	#name : 'VkMemoryBarrier2',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DSTACCESSMASK',
		'OFFSET_DSTSTAGEMASK',
		'OFFSET_PNEXT',
		'OFFSET_SRCACCESSMASK',
		'OFFSET_SRCSTAGEMASK',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkMemoryBarrier2 class >> fieldsDesc [
	"Synchronization2 widened all four masks to sixty-four bits, so each is a quad word and the
	 structure needs no padding anywhere."

	^ #( int32 sType; void* pNext; uint64 srcStageMask; uint64 srcAccessMask;
	     uint64 dstStageMask; uint64 dstAccessMask )
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> dstAccessMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_DSTACCESSMASK
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> dstAccessMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_DSTACCESSMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> dstStageMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_DSTSTAGEMASK
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> dstStageMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_DSTSTAGEMASK put: anObject
]

{ #category : 'initialization' }
VkMemoryBarrier2 >> initializeConstantFields [
	"Only the structure type is fixed by the type. All four masks belong to the recorder, and a
	 barrier that waits on nothing and makes nothing visible is a fresh block as it stands."

	self sType: VkStructureType memoryBarrier2
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> srcAccessMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_SRCACCESSMASK
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> srcAccessMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_SRCACCESSMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> srcStageMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_SRCSTAGEMASK
]

{ #category : 'accessing - structure variables' }
VkMemoryBarrier2 >> srcStageMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_SRCSTAGEMASK put: anObject
]
