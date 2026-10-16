"
The request `vkCreateFence` reads: a chain header and the creation flags from `VkFenceCreateFlag`. `initializeConstantFields` stamps the structure type, which is the only field fixed by the type; whether the fence starts signalled is the caller's choice, so a fresh block asks for an unsignalled fence. `VkFenceWrapper >> handleForCreateInfo:` is its one writer.
"
Class {
	#name : 'VkFenceCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkFenceCreateInfo class >> fieldsDesc [
	"VkFenceCreateInfo, read by vkCreateFence. A chain header and one word of flags from
	 VkFenceCreateFlag, so the structure is twenty-four bytes: the flags are followed by four
	 bytes of padding to the alignment the chain pointer demands."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
	 )
]

{ #category : 'accessing - structure variables' }
VkFenceCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkFenceCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkFenceCreateInfo >> initializeConstantFields [
	"Only the structure type is fixed by the type. Whether the fence starts signalled is the
	 caller's choice, and a fresh block asks for an unsignalled one."

	self sType: VkStructureType fenceCreateInfo
]

{ #category : 'accessing - structure variables' }
VkFenceCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkFenceCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkFenceCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkFenceCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
