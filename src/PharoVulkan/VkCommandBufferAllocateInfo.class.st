"
The request `vkAllocateCommandBuffers` reads: a chain header, the pool the buffers are cut from, the level from `VkCommandBufferLevel`, and how many buffers to allocate. `initializeConstantFields` stamps the structure type, which is the only field fixed by the type; a primary buffer happens to read out of a zeroed block because primary is zero in Vulkan, but the writer sets the level all the same. `VkCommandPool >> handleForAllocateInfo:` is its one writer — every command buffer in the project comes from a pool.
"
Class {
	#name : 'VkCommandBufferAllocateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_COMMANDBUFFERCOUNT',
		'OFFSET_COMMANDPOOL',
		'OFFSET_LEVEL',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkCommandBufferAllocateInfo class >> fieldsDesc [
	"VkCommandBufferAllocateInfo, read by vkAllocateCommandBuffers. The pool is a handle and
	 therefore pointer wide; the level and the count are uint32 and together fill the eight
	 bytes after it, so uFFI needs no pad and the structure is thirty-two bytes."

	^ #(
		int32 sType;
		void* pNext;
		VkCommandPool_H* commandPool;
		uint32 level;
		uint32 commandBufferCount;
	 )
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> commandBufferCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_COMMANDBUFFERCOUNT
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> commandBufferCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_COMMANDBUFFERCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> commandPool [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_COMMANDPOOL) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> commandPool: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_COMMANDPOOL put: anObject getHandle.
]

{ #category : 'initialization' }
VkCommandBufferAllocateInfo >> initializeConstantFields [
	"Only the structure type is fixed by the type. The level a caller wants and the number of
	 buffers it asks for are the caller's, and a fresh block is already zeroed."

	self sType: VkStructureType commandBufferAllocateInfo
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> level [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LEVEL
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> level: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LEVEL put: anObject
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkCommandBufferAllocateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
