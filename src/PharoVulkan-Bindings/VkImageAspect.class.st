"
Named constants for VkImageAspectFlagBits, the aspect of an image a copy, a view or a barrier names. Key methods: colorBit, and namedBits, through which the inherited nameForFlags: decodes a mask for a view. VkRenderConfig imageAspectColorBit delegates here, so the value has one home.
"
Class {
	#name : 'VkImageAspect',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkImageAspect class >> colorBit [
	"VK_IMAGE_ASPECT_COLOR_BIT, bit 0."

	^ 1
]

{ #category : 'constants' }
VkImageAspect class >> depthBit [
	"VK_IMAGE_ASPECT_DEPTH_BIT, bit 1."

	^ 2
]

{ #category : 'decoding' }
VkImageAspect class >> namedBits [
	"Lowest bit first, as the inherited decoder expects. A mask carrying a bit no constant here
	 names shows it as hex rather than hiding it."

	^ {
		  (self colorBit -> 'Color').
		  (self depthBit -> 'Depth').
		  (self stencilBit -> 'Stencil') }
]

{ #category : 'constants' }
VkImageAspect class >> stencilBit [
	"VK_IMAGE_ASPECT_STENCIL_BIT, bit 2."

	^ 4
]
