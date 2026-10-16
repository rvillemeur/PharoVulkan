"
One command buffer inside a submit batch: the handle, and the device mask that says which devices of a device group run it. Thirty-two bytes, with the chain header Vulkan requires of every synchronization2 submit structure. Built by VkQueue class >> commandBufferSubmitInfoFor:; one per batch in this project.
"
Class {
	#name : 'VkCommandBufferSubmitInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_COMMANDBUFFER',
		'OFFSET_DEVICEMASK',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkCommandBufferSubmitInfo class >> fieldsDesc [
	^ #( int32 sType; void* pNext; VkCommandBuffer_H* commandBuffer;
	     uint32 deviceMask )
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> commandBuffer [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_COMMANDBUFFER) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> commandBuffer: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_COMMANDBUFFER put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> deviceMask [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEVICEMASK
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> deviceMask: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEVICEMASK put: anObject
]

{ #category : 'initialization' }
VkCommandBufferSubmitInfo >> initializeConstantFields [
	self sType: VkStructureType commandBufferSubmitInfo
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkCommandBufferSubmitInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
