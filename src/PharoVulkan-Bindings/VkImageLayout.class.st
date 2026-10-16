"
Named constants for VkImageLayout enum values used in render-pass attachment descriptions and image memory barriers. Key methods: undefined, colorAttachmentOptimal, transferSrcOptimal, presentSrcKHR. A VkValueConstants subclass, so the inherited nameForValue: names a layout by reflection over these constants; every value here is distinct, so a value maps to at most one name.
"
Class {
	#name : 'VkImageLayout',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkImageLayout class >> colorAttachmentOptimal [
	^ 2
]

{ #category : 'reflecting' }
VkImageLayout class >> constantProtocol [
	"Where this class files its constants, for the inherited reverse lookup. Every layout
	 value here is distinct, so a value maps to at most one name."

	^ 'constants'
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
