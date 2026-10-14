"
The request passed to `vkAllocateMemory`: a chain header, the number of bytes to allocate and the index of the memory type to take them from. Both numbers come from a `VkMemoryRequirements` block the driver filled for the resource being backed, narrowed by `VkPhysicalDevice >> findMemoryType:properties:`. The layout is declared in `fieldsDesc` and `initializeConstantFields` writes only the structure type, because nothing else about an allocation is constant.

`VkBuffer >> allocate` and `VkImage >> allocate` both build one of these.
"
Class {
	#name : 'VkMemoryAllocateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ALLOCATIONSIZE',
		'OFFSET_MEMORYTYPEINDEX',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkMemoryAllocateInfo class >> exampleAllocationForAStorageBufferOnThisMachine [
	"One click: the allocation request a small storage buffer leads to on this machine. Both
	 numbers are answers, not choices: the size is what the driver demanded for the buffer, and
	 the memory type index is the first type on this device that both suits the buffer and is
	 host visible and coherent."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  | buffer requirements info |
	  buffer := VkBuffer
		            on: context device
		            size: VkBuffer exampleByteSize
		            usage: VkBuffer storageBufferUsage.
	  requirements := [ buffer memoryRequirements ] ensure: [ buffer destroy ].
	  info := self externalInstance.
	  [
	  info
		  allocationSize: requirements size;
		  memoryTypeIndex: (context device physicalDevice
				   findMemoryType: requirements memoryTypeBits
				   properties: VkMemoryProperty hostVisibleAndCoherent).
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ] ] ensure: [
		  context destroy ]
]

{ #category : 'field definition' }
VkMemoryAllocateInfo class >> fieldsDesc [
	"allocationSize is a VkDeviceSize and so eight bytes wide and eight byte aligned, which
	 pads the chain header out to sixteen before it."

	^ #( int32 sType; void* pNext; uint64 allocationSize; uint32 memoryTypeIndex )
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> allocationSize [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_ALLOCATIONSIZE
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> allocationSize: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_ALLOCATIONSIZE put: anObject
]

{ #category : 'initialization' }
VkMemoryAllocateInfo >> initializeConstantFields [
	"The structure type, and nothing else: the size and the memory type index come from the
	 requirements the driver answers for the resource being backed."

	self sType: VkStructureType memoryAllocateInfo
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> memoryTypeIndex [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MEMORYTYPEINDEX
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> memoryTypeIndex: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MEMORYTYPEINDEX put: anObject
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkMemoryAllocateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
