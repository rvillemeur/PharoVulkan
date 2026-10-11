"
Named constants for VkImageLayout enum values used in render-pass attachment descriptions and image memory barriers. Key methods: undefined, colorAttachmentOptimal, presentSrcKHR.
"
Class {
	#name : 'VkImageLayout',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkImageLayout class >> colorAttachmentOptimal [
	^ 2
]

{ #category : 'constants' }
VkImageLayout class >> presentSrcKHR [
	^ 1000001002
]

{ #category : 'constants' }
VkImageLayout class >> transferSrcOptimal [
	"VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL — the layout a copy out of an image reads from."

	^ 6
]

{ #category : 'constants' }
VkImageLayout class >> undefined [
	^ 0
]
