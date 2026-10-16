"
Named constants for VkImageTiling, how the driver arranges an image's texels in memory. Key method: optimal (VK_IMAGE_TILING_OPTIMAL = 0), which the host cannot read directly; a readback therefore copies the image into a buffer rather than mapping its memory. A VkValueConstants subclass, so the inherited nameForValue: names a tiling for the Image tab.
"
Class {
	#name : 'VkImageTiling',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkImageTiling class >> constantProtocol [
	"Where this class files its constants, for the inherited reverse lookup."

	^ 'constants'
]

{ #category : 'constants' }
VkImageTiling class >> optimal [
	"VK_IMAGE_TILING_OPTIMAL"

	^ 0
]
