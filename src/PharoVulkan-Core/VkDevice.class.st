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
	#category : 'PharoVulkan-Core-Device',
	#package : 'PharoVulkan-Core',
	#tag : 'Device'
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
	"Delegated to the pool class, as the other factories here are: the create info is written
	 in one place."

	^ VkCommandPool on: self queueFamilyIndex: queueFamilyIndex
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
