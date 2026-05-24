"
Named constants for the sType field present in most Vulkan structs.
All methods are class-side and return the integer discriminant value.
Generated from vk.xml; the Phase 1 subset is hand-written here.
Key methods: applicationInfo, instanceCreateInfo (class-side).
"
Class {
	#name : 'VkStructureType',
	#superclass : 'Object',
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'structure-types' }
VkStructureType class >> applicationInfo [           ^ 0
]

{ #category : 'structure-types' }
VkStructureType class >> bufferCreateInfo [          ^ 12
]

{ #category : 'structure-types' }
VkStructureType class >> commandBufferAllocateInfo [ ^ 40
]

{ #category : 'structure-types' }
VkStructureType class >> commandBufferBeginInfo [    ^ 42
]

{ #category : 'structure-types' }
VkStructureType class >> commandBufferSubmitInfo [
    ^ 1000314006
]

{ #category : 'structure-types' }
VkStructureType class >> commandPoolCreateInfo [     ^ 39
]

{ #category : 'structure-types' }
VkStructureType class >> computePipelineCreateInfo [ ^ 29
]

{ #category : 'structure-types' }
VkStructureType class >> descriptorPoolCreateInfo [  ^ 33
]

{ #category : 'structure-types' }
VkStructureType class >> descriptorSetLayoutCreateInfo [
    ^ 32
]

{ #category : 'structure-types' }
VkStructureType class >> deviceCreateInfo [          ^ 3
]

{ #category : 'structure-types' }
VkStructureType class >> deviceQueueCreateInfo [     ^ 2
]

{ #category : 'structure-types' }
VkStructureType class >> fenceCreateInfo [
    ^ 8
]

{ #category : 'structure-types' }
VkStructureType class >> framebufferCreateInfo [
    ^ 37
]

{ #category : 'structure-types' }
VkStructureType class >> graphicsPipelineCreateInfo [
    ^ 28
]

{ #category : 'structure-types' }
VkStructureType class >> imageViewCreateInfo [
    ^ 15
]

{ #category : 'structure-types' }
VkStructureType class >> instanceCreateInfo [        ^ 1
]

{ #category : 'structure-types' }
VkStructureType class >> memoryAllocateInfo [        ^ 5
]

{ #category : 'structure-types' }
VkStructureType class >> physicalDeviceSynchronization2Features [
    ^ 1000314007
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineColorBlendStateCreateInfo [
    ^ 26
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineDynamicStateCreateInfo [
    ^ 27
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineInputAssemblyStateCreateInfo [
    ^ 20
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineLayoutCreateInfo [  ^ 30
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineMultisampleStateCreateInfo [
    ^ 24
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineRasterizationStateCreateInfo [
    ^ 23
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineShaderStageCreateInfo [
    ^ 18
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineVertexInputStateCreateInfo [
    ^ 19
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineViewportStateCreateInfo [
    ^ 22
]

{ #category : 'structure-types' }
VkStructureType class >> presentInfoKHR [
    ^ 1000001001
]

{ #category : 'structure-types' }
VkStructureType class >> renderPassBeginInfo [
    ^ 43
]

{ #category : 'structure-types' }
VkStructureType class >> renderPassCreateInfo [
    ^ 38
]

{ #category : 'structure-types' }
VkStructureType class >> semaphoreCreateInfo [
    ^ 9
]

{ #category : 'structure-types' }
VkStructureType class >> semaphoreSubmitInfo [
    ^ 1000314005
]

{ #category : 'structure-types' }
VkStructureType class >> shaderModuleCreateInfo [    ^ 16
]

{ #category : 'structure-types' }
VkStructureType class >> submitInfo [                ^ 4
]

{ #category : 'structure-types' }
VkStructureType class >> submitInfo2 [
    ^ 1000314004
]

{ #category : 'structure-types' }
VkStructureType class >> swapchainCreateInfoKHR [
    ^ 1000001000
]

{ #category : 'structure-types' }
VkStructureType class >> writeDescriptorSet [        ^ 35
]
