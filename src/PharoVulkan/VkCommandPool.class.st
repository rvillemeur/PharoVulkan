"
Vulkan command pool. Owns the memory from which VkCommandBuffer objects are allocated for a given queue family. Key methods: allocateBuffer, destroy.
"
Class {
	#name : 'VkCommandPool',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'queueFamilyIndex'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'constants' }
VkCommandPool class >> allocationLevel [
	"Every buffer this project records is submitted to a queue, never recorded into another
	 buffer, so the level is always primary."

	^ VkCommandBufferLevel primary
]

{ #category : 'constants' }
VkCommandPool class >> buffersPerAllocation [
	"allocateBuffer answers one buffer, so it asks for one and reads one handle back."

	^ 1
]

{ #category : 'constants' }
VkCommandPool class >> creationFlags [
	"The flags every pool here is created with, named once so the creation path and the Pool
	 tab cannot disagree about what was asked for."

	^ VkCommandPoolCreateFlag resetCommandBufferBit
]

{ #category : 'examples' }
VkCommandPool class >> examplePoolForTheComputeQueueOnThisMachine [
	"One click: the pool every compute dispatch here allocates its command buffer from, created
	 for this machine's compute queue family and then destroyed with its context. The family
	 and the flags live in the instance, so the Pool tab still answers afterwards. Where no
	 device is available it answers an unmade pool, which is what the inspector should show on
	 such a machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ self new ].
	^ [
	  | pool |
	  pool := context device createCommandPool: context computeQueueFamily.
	  pool destroy.
	  pool ] ensure: [ context destroy ]
]

{ #category : 'private' }
VkCommandPool class >> handleForCreateInfo: aCreateInfo on: aDevice [
	"The driver writes the new pool handle into an out parameter, which is read before the
	 block holding it is freed."

	| out result |
	out := ExternalAddress allocate: VkContext pointerSize.
	^ [
	  result := Vk
		            createCommandPool: aDevice handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            poolOut: out.
	  Vk checkResult: result.
	  VkCommandPool_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'factory' }
VkCommandPool class >> on: aHandle device: aDevice queueFamilyIndex: idx [
    ^ self new initializeWith: aHandle device: aDevice queueFamilyIndex: idx
]

{ #category : 'instance creation' }
VkCommandPool class >> on: aDevice queueFamilyIndex: idx [
	"The one place a command pool is created. Every pool here asks for the reset flag, so one
	 recorded buffer can be reset on its own between dispatches."

	| info |
	info := VkCommandPoolCreateInfo externalInstance.
	^ [
	  info
		  flags: self creationFlags;
		  queueFamilyIndex: idx.
	  self new
		  initializeWith: (self handleForCreateInfo: info on: aDevice)
		  device: aDevice
		  queueFamilyIndex: idx ] ensure: [ info getHandle free ]
]

{ #category : 'allocating' }
VkCommandPool >> allocateBuffer [
	"One primary buffer, cut from this pool. The request is freed whichever way the allocation
	 goes, and the allocation itself is a separate method so no return crosses this ensure:."

	| info |
	info := VkCommandBufferAllocateInfo externalInstance.
	^ [
	  info
		  commandPool: handle;
		  level: self class allocationLevel;
		  commandBufferCount: self class buffersPerAllocation.
	  VkCommandBuffer
		  on: (self handleForAllocateInfo: info)
		  pool: self
		  level: self class allocationLevel ] ensure: [ info getHandle free ]
]

{ #category : 'lifecycle' }
VkCommandPool >> destroy [

	handle ifNil: [ ^ self ].
	Vk
		destroyCommandPool: device handle
		commandPool: handle
		allocator: ExternalAddress null.
	handle invalidate.
	handle := nil
]

{ #category : 'accessing' }
VkCommandPool >> handle [
    ^ handle
]

{ #category : 'allocating' }
VkCommandPool >> handleForAllocateInfo: anAllocateInfo [
	"The driver writes the handles into a block the caller owns, one pointer per buffer asked
	 for, so the block is freed here and only the handle leaves."

	| out result |
	out := ExternalAddress allocate:
		       self class buffersPerAllocation * VkContext pointerSize.
	^ [
	  result := Vk
		            allocateCommandBuffers: device handle
		            allocateInfo: anAllocateInfo getHandle
		            commandBuffers: out.
	  Vk checkResult: result.
	  VkCommandBuffer_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'initialization' }
VkCommandPool >> initializeWith: aHandle device: aDevice queueFamilyIndex: idx [
    handle := aHandle. device := aDevice. queueFamilyIndex := idx
]

{ #category : 'inspector' }
VkCommandPool >> inspectorPool: aBuilder [
	"What the pool was created with: the queue family it serves, the creation flags and the
	 names of the bits in them, decoded by the constants class that owns them, and whether the
	 handle is still live. The rows are built fresh, so opening the tab cannot change the
	 pool."

	<inspectorPresentationOrder: 30 title: 'Pool'>
	| rows |
	rows := self poolRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Queue family'. (rows at: #queueFamilyIndex) }.
				  { 'Flags'. (rows at: #flagNames) }.
				  { 'Handle live'. (rows at: #live) } };
		  yourself
]

{ #category : 'accessing' }
VkCommandPool >> poolRows [
	"What the pool was created with, kept in the instance because the driver answers none of it
	 back: the queue family it serves, the creation flags, those flags named by the constants
	 class that owns the bits, and whether the handle is still live. Each call builds a fresh
	 row."

	^ (Dictionary newFrom: {
			   (#queueFamilyIndex -> queueFamilyIndex).
			   (#flags -> self class creationFlags).
			   (#flagNames
			    -> (VkCommandPoolCreateFlag nameForFlags: self class creationFlags)).
			   (#live -> handle notNil) }) beReadOnlyObject
]

{ #category : 'operations' }
VkCommandPool >> reset [
    Vk resetCommandPool: device handle commandPool: handle flags: 0
]
