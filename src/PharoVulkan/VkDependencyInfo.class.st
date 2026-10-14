"
The VkDependencyInfo vkCmdPipelineBarrier2 takes: a dependency flag word and three count-and-pointer pairs, one pair per kind of barrier — memory, buffer and image. This project records memory barriers only, so the other two pairs stay at zero and null. The fields are declared, so uFFI places them and pads after the counts that a pointer follows. VkCommandBuffer class >> dependencyForBarrier: is the only writer.
"
Class {
	#name : 'VkDependencyInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BUFFERMEMORYBARRIERCOUNT',
		'OFFSET_DEPENDENCYFLAGS',
		'OFFSET_IMAGEMEMORYBARRIERCOUNT',
		'OFFSET_MEMORYBARRIERCOUNT',
		'OFFSET_PBUFFERMEMORYBARRIERS',
		'OFFSET_PIMAGEMEMORYBARRIERS',
		'OFFSET_PMEMORYBARRIERS',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDependencyInfo class >> exampleDependencyCarryingOneMemoryBarrier [
	"One click: the dependency the recorder hands to vkCmdPipelineBarrier2, carrying one memory
	 barrier and no buffer or image barrier. The barrier it points at is freed with the example,
	 so the pointer is shown for its placement, not to be followed."

	<sampleInstance>
	| barrier |
	barrier := VkCommandBuffer hostReadBarrier.
	^ [
	  | info |
	  info := VkCommandBuffer dependencyForBarrier: barrier.
	  [ info copyIntoObjectMemory ] ensure: [ info getHandle free ] ] ensure: [
		  barrier getHandle free ]
]

{ #category : 'field definition' }
VkDependencyInfo class >> fieldsDesc [
	"Each count is one word and each pointer eight byte aligned, so uFFI pads after the second
	 and the third count. Declaring the pairs is what keeps that padding out of our hands."

	^ #( int32 sType; void* pNext; uint32 dependencyFlags;
	     uint32 memoryBarrierCount; void* pMemoryBarriers;
	     uint32 bufferMemoryBarrierCount; void* pBufferMemoryBarriers;
	     uint32 imageMemoryBarrierCount; void* pImageMemoryBarriers )
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> bufferMemoryBarrierCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BUFFERMEMORYBARRIERCOUNT
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> bufferMemoryBarrierCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BUFFERMEMORYBARRIERCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> dependencyFlags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPENDENCYFLAGS
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> dependencyFlags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPENDENCYFLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> imageMemoryBarrierCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_IMAGEMEMORYBARRIERCOUNT
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> imageMemoryBarrierCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_IMAGEMEMORYBARRIERCOUNT put: anObject
]

{ #category : 'initialization' }
VkDependencyInfo >> initializeConstantFields [
	"Only the structure type is fixed by the type. Every count and pointer belongs to the
	 recorder, and a dependency carrying no barrier of any kind is a fresh block as it stands."

	self sType: VkStructureType dependencyInfo
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> memoryBarrierCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MEMORYBARRIERCOUNT
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> memoryBarrierCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MEMORYBARRIERCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pBufferMemoryBarriers [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PBUFFERMEMORYBARRIERS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pBufferMemoryBarriers: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PBUFFERMEMORYBARRIERS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pImageMemoryBarriers [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PIMAGEMEMORYBARRIERS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pImageMemoryBarriers: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PIMAGEMEMORYBARRIERS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pMemoryBarriers [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PMEMORYBARRIERS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pMemoryBarriers: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PMEMORYBARRIERS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkDependencyInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
