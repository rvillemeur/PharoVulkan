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
	#package : 'PharoVulkan-Core'
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
VkDevice >> createCommandPool: queueFamilyIndex [
    "VkCommandPoolCreateInfo: sType=39, pNext=null, flags=1 (TRANSIENT), queueFamilyIndex"
    | info poolBuf result poolHandle |
    info := ExternalAddress allocate: 24.
    [ info unsignedLongAt: 1 put: 39.         "sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO"
      info pointerAt: 9 put: ExternalAddress null.
      info unsignedLongAt: 17 put: 1.         "flags = RESET_COMMAND_BUFFER_BIT"
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
VkDevice >> createDescriptorPool: maxSets [
    ^ VkDescriptorPool on: self maxSets: maxSets
]

{ #category : 'factory' }
VkDevice >> createShaderModule: spirvBytes [
    ^ VkShaderModule fromBytes: spirvBytes device: self
]

{ #category : 'lifecycle' }
VkDevice >> destroy [
    handle ifNotNil: [
        Vk destroyDevice: handle allocator: ExternalAddress null.
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
