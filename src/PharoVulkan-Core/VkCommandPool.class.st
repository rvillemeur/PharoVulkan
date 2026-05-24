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
	#package : 'PharoVulkan-Core'
}

{ #category : 'factory' }
VkCommandPool class >> on: aHandle device: aDevice queueFamilyIndex: idx [
    ^ self new initializeWith: aHandle device: aDevice queueFamilyIndex: idx
]

{ #category : 'instance creation' }
VkCommandPool class >> on: aDevice queueFamilyIndex: idx [
	"VkCommandPoolCreateInfo (24 bytes):
     0:sType  8:pNext  16:flags  20:queueFamilyIndex"

	| info poolBuf result |
	info := ExternalAddress allocate: 24.
	^ [
		  info unsignedLongAt: 1 put: VkStructureType commandPoolCreateInfo.
		  info pointerAt: 9 put: ExternalAddress null.
		  info unsignedLongAt: 17 put: 1.
		  info unsignedLongAt: 21 put: idx.
		  poolBuf := ExternalAddress allocate: 8.
		  [
			  result := Vk
				            createCommandPool: aDevice handle
				            createInfo: info
				            allocator: ExternalAddress null
				            poolOut: poolBuf.
			  Vk checkResult: result.
			  self new
				  initializeWith:
				  (VkCommandPool_H fromHandle: (poolBuf pointerAt: 1))
				  device: aDevice
				  queueFamilyIndex: idx ] ensure: [ poolBuf free ] ] ensure: [
		  info free ]
]

{ #category : 'allocating' }
VkCommandPool >> allocateBuffer [
    "VkCommandBufferAllocateInfo (32 bytes):
     0:sType  8:pNext  16:commandPool  24:level  28:commandBufferCount"
    | info bufOut result cbHandle |
    info := ExternalAddress allocate: 32.
    [ info unsignedLongAt: 1 put: VkStructureType commandBufferAllocateInfo.
      info pointerAt: 9 put: ExternalAddress null.
      info pointerAt: 17 put: handle getHandle.
      info unsignedLongAt: 25 put: 0.
      info unsignedLongAt: 29 put: 1.
      bufOut := ExternalAddress allocate: 8.
      [ result := Vk allocateCommandBuffers: device handle allocateInfo: info commandBuffers: bufOut.
        Vk checkResult: result.
        cbHandle := VkCommandBuffer_H fromHandle: (bufOut pointerAt: 1).
        ^ VkCommandBuffer on: cbHandle pool: self
      ] ensure: [ bufOut free ]
    ] ensure: [ info free ]
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

{ #category : 'initialization' }
VkCommandPool >> initializeWith: aHandle device: aDevice queueFamilyIndex: idx [
    handle := aHandle. device := aDevice. queueFamilyIndex := idx
]

{ #category : 'operations' }
VkCommandPool >> reset [
    Vk resetCommandPool: device handle commandPool: handle flags: 0
]
