"
Miscellaneous named constants for pipeline and swapchain configuration that do not belong to a more specific enum class. Covers color write mask, composite alpha, image aspect, image view type, present mode, primitive topology, sample count, and sharing mode.
"
Class {
	#name : 'VkRenderConfig',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkRenderConfig class >> colorWriteMaskRGBA [
	^ 15
]

{ #category : 'constants' }
VkRenderConfig class >> compositeAlphaOpaqueBit [
	^ 1
]

{ #category : 'constants' }
VkRenderConfig class >> imageAspectColorBit [
	^ 1
]

{ #category : 'constants' }
VkRenderConfig class >> imageViewType2D [
	^ 1
]

{ #category : 'constants' }
VkRenderConfig class >> presentModeFifo [
	^ 2
]

{ #category : 'constants' }
VkRenderConfig class >> primitiveTopologyTriangleList [
	^ 3
]

{ #category : 'constants' }
VkRenderConfig class >> sampleCount1Bit [
	^ 1
]

{ #category : 'constants' }
VkRenderConfig class >> sharingModeExclusive [
	^ 0
]
