"
The request `vkCreateSemaphore` reads: a chain header and a word of flags Vulkan reserves and requires to be zero. `initializeConstantFields` stamps the structure type and nothing else, so no writer ever touches the flags — a fresh block is already the whole request. `VkSemaphoreWrapper >> handleForCreateInfo:` is its one writer, and `VkSemaphoreWrapper >> semaphoreRows` reads the reserved word back off this structure rather than restating the zero.
"
Class {
	#name : 'VkSemaphoreCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkSemaphoreCreateInfo class >> fieldsDesc [
	"VkSemaphoreCreateInfo, read by vkCreateSemaphore. The same shape as the fence request, but
	 the flags are reserved by Vulkan and must be zero, so no writer ever sets them."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
	 )
]

{ #category : 'accessing - structure variables' }
VkSemaphoreCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkSemaphoreCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkSemaphoreCreateInfo >> initializeConstantFields [
	"Only the structure type is fixed by the type. The flags are reserved and must be zero,
	 which a fresh block already is, so writing them here would say nothing."

	self sType: VkStructureType semaphoreCreateInfo
]

{ #category : 'accessing - structure variables' }
VkSemaphoreCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSemaphoreCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSemaphoreCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkSemaphoreCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
