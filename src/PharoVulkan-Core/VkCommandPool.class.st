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
	"VkCommandPoolCreateInfo: sType=39, flags=1 (RESET_COMMAND_BUFFER_BIT)"
	| info poolBuf result |
	info := ExternalAddress allocate: 24.
	[
		info unsignedLongAt: 1 put: 39.
		info pointerAt: 9 put: ExternalAddress null.
		info unsignedLongAt: 17 put: 1.
		info unsignedLongAt: 21 put: idx.
		poolBuf := ExternalAddress allocate: 8.
		[
			result := Vk createCommandPool: aDevice handle createInfo: info allocator: ExternalAddress null poolOut: poolBuf.
			Vk checkResult: result.
			^ self new
				initializeWith: (VkCommandPool_H fromHandle: (poolBuf pointerAt: 1))
				device: aDevice
				queueFamilyIndex: idx
		] ensure: [ poolBuf free ]
	] ensure: [ info free ]
]

{ #category : 'allocating' }
VkCommandPool >> allocateBuffer [
    "VkCommandBufferAllocateInfo: sType=40, pNext, commandPool, level=0 (PRIMARY), count=1"
    | info bufOut result cbHandle |
    info := ExternalAddress allocate: 32.
    [ info unsignedLongAt: 1 put: 40.
      info pointerAt: 9 put: ExternalAddress null.
      info pointerAt: 17 put: handle getHandle.
      info unsignedLongAt: 25 put: 0.  "level = PRIMARY"
      info unsignedLongAt: 29 put: 1.  "commandBufferCount"
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
    Vk destroyCommandPool: device handle commandPool: handle allocator: ExternalAddress null
]

{ #category : 'accessing' }
VkCommandPool >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkCommandPool >> initializeWith: aHandle device: aDevice queueFamilyIndex: idx [
    handle := aHandle. device := aDevice. queueFamilyIndex := idx
]
