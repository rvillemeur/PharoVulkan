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
VkRenderConfig class >> clearColorBlackOpaque [
	"The clear colour the window path has always used, as r, g, b, a floats."

	^ #( 0.0 0.0 0.0 1.0 )
]

{ #category : 'constants' }
VkRenderConfig class >> colorWriteMaskRGBA [
	"Delegates so the value has one home. The channel bits moved to VkColorComponent when the
	 blend attachment's view had to name which channels are written."

	^ VkColorComponent allChannels
]

{ #category : 'constants' }
VkRenderConfig class >> compositeAlphaOpaqueBit [
	"Delegates so the value has one home. The composite alpha bits moved to VkCompositeAlpha
	 when the surface capabilities view had to name which modes a surface accepts, and this
	 method keeps its sender until the swapchain request unit reaches it."

	^ VkCompositeAlpha opaqueBit
]

{ #category : 'constants' }
VkRenderConfig class >> imageAspectColorBit [
	"Delegates so the value has one home. The aspect bits moved to VkImageAspect when the copy
	 region's view had to name them, and this method keeps its three senders — the image, the
	 swapchain's views and the copy — until each of their units reaches them."

	^ VkImageAspect colorBit
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
	"Delegates so the value has one home. The topology moved to VkPrimitiveTopology when the
	 input assembly state's view had to name it, and this method keeps its senders until each
	 of them is reached."

	^ VkPrimitiveTopology triangleList
]

{ #category : 'constants' }
VkRenderConfig class >> sampleCount1Bit [
	"Delegates so the value has one home. The sample count bits moved to VkSampleCount when
	 the multisample state's view had to name them, and this method keeps its senders — the
	 image request and the attachment description — until each of their units reaches them."

	^ VkSampleCount count1Bit
]

{ #category : 'constants' }
VkRenderConfig class >> sharingModeExclusive [
	^ 0
]
