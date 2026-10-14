"
The request `vkCreateCommandPool` reads: a chain header, the creation flags from `VkCommandPoolCreateFlag`, and the queue family whose command buffers the pool serves. `initializeConstantFields` stamps the structure type, which is the only field fixed by the type; the flags are a caller's choice, so a fresh block asks for a pool with none. `VkCommandPool class >> handleForCreateInfo:on:` is its one writer — `VkDevice >> createCommandPool:` delegates to the pool class rather than writing the request a second time.
"
Class {
	#name : 'VkCommandPoolCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_QUEUEFAMILYINDEX',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkCommandPoolCreateInfo class >> fieldsDesc [
	^ #( int32 sType; void* pNext; uint32 flags; uint32 queueFamilyIndex )
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkCommandPoolCreateInfo >> initializeConstantFields [
	"The structure type is all this request knows before a caller names a queue family. The
	 flags are a caller's choice and stay as the zeroed block left them."

	self sType: VkStructureType commandPoolCreateInfo
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> queueFamilyIndex [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEX
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> queueFamilyIndex: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEX put: anObject
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkCommandPoolCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
