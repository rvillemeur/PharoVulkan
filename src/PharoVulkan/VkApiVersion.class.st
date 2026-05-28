"
Named constants for Vulkan API version numbers, packed as VK_MAKE_API_VERSION integers. Use these instead of raw integers in VkContext or instance-creation code. Key methods: vulkan12, vulkan13.
"
Class {
	#name : 'VkApiVersion',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkApiVersion class >> vulkan12 [
	^ 4198400
]

{ #category : 'constants' }
VkApiVersion class >> vulkan13 [
	^ 4206592
]
