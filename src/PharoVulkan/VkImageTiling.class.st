"
Named constants for VkImageTiling, how the driver arranges an image's texels in memory. Key method: optimal (VK_IMAGE_TILING_OPTIMAL = 0), which the host cannot read directly; a readback therefore copies the image into a buffer rather than mapping its memory.
"
Class {
	#name : 'VkImageTiling',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkImageTiling class >> optimal [
	"VK_IMAGE_TILING_OPTIMAL"

	^ 0
]
