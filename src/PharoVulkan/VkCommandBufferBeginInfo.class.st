"
The request `vkBeginCommandBuffer` reads: a chain header, the usage flags from `VkCommandBufferUsageFlag`, and an inheritance pointer a secondary buffer needs and a primary buffer must leave null. `initializeConstantFields` stamps the structure type, which is the only field fixed by the type; the flags are the recorder's choice and a fresh block carries a null inheritance pointer already. `VkCommandBuffer >> begin` is its one writer, and `VkCommandBuffer class >> recordingFlags` names the flag every recording in this project asks for.
"
Class {
	#name : 'VkCommandBufferBeginInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PINHERITANCEINFO',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkCommandBufferBeginInfo class >> fieldsDesc [
	"VkCommandBufferBeginInfo, read by vkBeginCommandBuffer. The usage flags from
	 VkCommandBufferUsageFlag are one word, and the inheritance pointer after them is eight byte
	 aligned, so uFFI pads between the two and the structure is thirty-two bytes. The
	 inheritance pointer is read for a secondary buffer only."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		void* pInheritanceInfo;
	 )
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkCommandBufferBeginInfo >> initializeConstantFields [
	"Only the structure type is fixed by the type. The usage flags are the recorder's choice,
	 and the inheritance pointer must stay null for a primary buffer, which a fresh block
	 already is."

	self sType: VkStructureType commandBufferBeginInfo
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> pInheritanceInfo [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PINHERITANCEINFO) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> pInheritanceInfo: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PINHERITANCEINFO put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkCommandBufferBeginInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
