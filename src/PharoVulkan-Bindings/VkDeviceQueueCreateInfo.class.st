"
Generated Vulkan struct binding for VkDeviceQueueCreateInfo.
Fields match the C struct layout. See VkStructure for base behaviour.
"
Class {
	#name : 'VkDeviceQueueCreateInfo',
	#superclass : 'VkStructure',
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'field definition' }
VkDeviceQueueCreateInfo class >> fieldsDesc [
    ^ #((#sType #pointer) (#queueFamilyIndex #uint32) )
]
