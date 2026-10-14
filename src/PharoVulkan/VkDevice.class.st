"
Wrapper around a VkDevice_H logical device handle. Provides access to the associated VkPhysicalDevice and owning VkContext. Passed to all resource constructors.
"
Class {
	#name : 'VkDevice',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'physicalDevice',
		'context'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'factory' }
VkDevice class >> on: aHandle physicalDevice: aPD context: aCtx [
    ^ self new initializeWith: aHandle physicalDevice: aPD context: aCtx
]

{ #category : 'factory' }
VkDevice >> allocateBuffer: byteSize usage: usageFlags [
    ^ VkBuffer on: self size: byteSize usage: usageFlags
]

{ #category : 'factory' }
VkDevice >> allocateMemoryFor: someRequirements properties: propertyFlags [
	"Memory for a resource this device owns: the bytes the driver demanded for it, taken from
	 the first memory type that both satisfies the resource and carries the properties asked
	 for. Buffers and images differ in what they demand and in how they bind, but not in this
	 step, so the allocate info is written here and nowhere else."

	| info buf result |
	info := VkMemoryAllocateInfo externalInstance.
	^ [
	  info
		  allocationSize: someRequirements size;
		  memoryTypeIndex: (physicalDevice
				   findMemoryType: someRequirements memoryTypeBits
				   properties: propertyFlags).
	  buf := ExternalAddress allocate: VkContext pointerSize.
	  [
	  result := Vk
		            allocateMemory: handle
		            allocateInfo: info getHandle
		            allocator: ExternalAddress null
		            memory: buf.
	  Vk checkResult: result.
	  VkDeviceMemory_H fromHandle: (buf pointerAt: 1) ] ensure: [ buf free ] ]
		  ensure: [ info getHandle free ]
]

{ #category : 'factory' }
VkDevice >> createCommandPool: queueFamilyIndex [
    "VkCommandPoolCreateInfo: sType, pNext=null, flags=1 (RESET_COMMAND_BUFFER_BIT), queueFamilyIndex"
    | info poolBuf result poolHandle |
    info := ExternalAddress allocate: 24.
    [ info unsignedLongAt: 1 put: VkStructureType commandPoolCreateInfo.
      info pointerAt: 9 put: ExternalAddress null.
      info unsignedLongAt: 17 put: 1.
      info unsignedLongAt: 21 put: queueFamilyIndex.
      poolBuf := ExternalAddress allocate: 8.
      [ result := Vk createCommandPool: handle createInfo: info allocator: ExternalAddress null poolOut: poolBuf.
        Vk checkResult: result.
        poolHandle := VkCommandPool_H fromHandle: (poolBuf pointerAt: 1).
        ^ VkCommandPool on: poolHandle device: self queueFamilyIndex: queueFamilyIndex
      ] ensure: [ poolBuf free ]
    ] ensure: [ info free ]
]

{ #category : 'factory' }
VkDevice >> createDescriptorPool: aMaxSetCount descriptorCount: aDescriptorCount [
    ^ VkDescriptorPool
	      on: self
	      maxSets: aMaxSetCount
	      descriptorCount: aDescriptorCount
]

{ #category : 'factory' }
VkDevice >> createShaderModule: spirvBytes [
    ^ VkShaderModule fromBytes: spirvBytes device: self
]

{ #category : 'lifecycle' }
VkDevice >> destroy [

	handle ifNotNil: [
			Vk destroyDevice: handle allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkDevice >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkDevice >> initializeWith: aHandle physicalDevice: aPD context: aCtx [
    handle := aHandle. physicalDevice := aPD. context := aCtx
]

{ #category : 'accessing' }
VkDevice >> physicalDevice [
    ^ physicalDevice
]
