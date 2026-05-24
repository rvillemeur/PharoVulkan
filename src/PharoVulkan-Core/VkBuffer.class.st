"
Vulkan buffer resource. Allocates a VkBuffer + VkDeviceMemory pair on the device, maps/unmaps host-visible memory, and tracks size and usage flags. Key methods: allocate, copyFromByteArray:, map, unmap, destroy.
"
Class {
	#name : 'VkBuffer',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'memory',
		'size',
		'usage',
		'device',
		'mappedPointer'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan-Core'
}

{ #category : 'factory' }
VkBuffer class >> on: aDevice size: byteSize usage: usageFlags [
    ^ self new initializeDevice: aDevice size: byteSize usage: usageFlags
]

{ #category : 'lifecycle' }
VkBuffer >> allocate [
    "VkBufferCreateInfo: 1:sType 9:pNext 17:flags [pad] 25:size(u64) 33:usage 37:sharing 41:qCount [pad] 49:pQueues"
    | info bufBuf result memReqs memTypeIndex allocInfo memBuf |
    info := ExternalAddress allocate: 56.
    [ info unsignedLongAt: 1 put: VkStructureType bufferCreateInfo.
      info pointerAt: 9 put: ExternalAddress null.
      info unsignedLongAt: 17 put: 0.
      info unsignedLongLongAt: 25 put: size.
      info unsignedLongAt: 33 put: usage.
      info unsignedLongAt: 37 put: 0.
      info unsignedLongAt: 41 put: 0.
      info pointerAt: 49 put: ExternalAddress null.
      bufBuf := ExternalAddress allocate: 8.
      [ result := Vk createBuffer: device handle createInfo: info allocator: ExternalAddress null bufferOut: bufBuf.
        Vk checkResult: result.
        handle := VkBuffer_H fromHandle: (bufBuf pointerAt: 1)
      ] ensure: [ bufBuf free ]
    ] ensure: [ info free ].
    memReqs := ExternalAddress allocate: 24.
    [ Vk getBufferMemoryRequirements: device handle buffer: handle memoryRequirements: memReqs.
      memTypeIndex := device physicalDevice
          findMemoryType: (memReqs unsignedLongAt: 17)
          properties: VkMemoryProperty hostVisibleAndCoherent.
      allocInfo := ExternalAddress allocate: 32.
      [ allocInfo unsignedLongAt: 1 put: VkStructureType memoryAllocateInfo.
        allocInfo pointerAt: 9 put: ExternalAddress null.
        allocInfo unsignedLongLongAt: 17 put: (memReqs unsignedLongLongAt: 1).
        allocInfo unsignedLongAt: 25 put: memTypeIndex.
        memBuf := ExternalAddress allocate: 8.
        [ result := Vk allocateMemory: device handle allocateInfo: allocInfo allocator: ExternalAddress null memory: memBuf.
          Vk checkResult: result.
          memory := VkDeviceMemory_H fromHandle: (memBuf pointerAt: 1)
        ] ensure: [ memBuf free ]
      ] ensure: [ allocInfo free ]
    ] ensure: [ memReqs free ].
    result := Vk bindBufferMemory: device handle buffer: handle memory: memory memoryOffset: 0.
    Vk checkResult: result
]

{ #category : 'accessing' }
VkBuffer >> copyFromByteArray: aByteArray [
	| ptr |
	ptr := self map.
	1 to: aByteArray size do: [:i | ptr byteAt: i put: (aByteArray at: i)].
	self unmap
]

{ #category : 'accessing' }
VkBuffer >> copyToByteArray [
	| ptr result |
	result := ByteArray new: size.
	ptr := self map.
	1 to: size do: [:i | result at: i put: (ptr byteAt: i)].
	self unmap.
	^ result
]

{ #category : 'lifecycle' }
VkBuffer >> destroy [
    handle ifNotNil: [
        Vk destroyBuffer: device handle buffer: handle allocator: ExternalAddress null.
        handle := nil ].
    memory ifNotNil: [
        Vk freeMemory: device handle memory: memory allocator: ExternalAddress null.
        memory := nil ]
]

{ #category : 'accessing' }
VkBuffer >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkBuffer >> initializeDevice: aDevice size: byteSize usage: usageFlags [
    device := aDevice. size := byteSize. usage := usageFlags.
    self allocate
]

{ #category : 'mapping' }
VkBuffer >> map [
    | ptrBuf result |
    ptrBuf := ExternalAddress allocate: 8.
    [ result := Vk mapMemory: device handle memory: memory offset: 0 size: size flags: 0 ppData: ptrBuf.
      Vk checkResult: result.
      mappedPointer := ptrBuf pointerAt: 1.
      ^ mappedPointer
    ] ensure: [ ptrBuf free ]
]

{ #category : 'accessing' }
VkBuffer >> size [
    ^ size
]

{ #category : 'mapping' }
VkBuffer >> unmap [
    Vk unmapMemory: device handle memory: memory.
    mappedPointer := nil
]
