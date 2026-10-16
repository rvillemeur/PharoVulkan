"
Miscellaneous named constants for pipeline and swapchain configuration that do not belong to a more specific enum class. Covers color write mask, composite alpha, image aspect, image view type, present mode, primitive topology, sample count, and sharing mode.
"
Class {
	#name : 'VkRenderConfig',
	#superclass : 'Object',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkRenderConfig class >> clearColorBlackOpaque [
	"The clear colour the window path has always used, as r, g, b, a floats."

	^ #( 0.0 0.0 0.0 1.0 )
]

{ #category : 'constants' }
VkRenderConfig class >> clipObscuredPixels [
	"VK_TRUE for the clipped field: the driver may discard pixels another window covers.
	 Nothing here reads a presented image back, so the pixels that would be discarded are
	 never looked at, and discarding them is what lets a driver present without a copy. It is a
	 choice this project makes, read by the creation code above and by the request report below."

	^ 1
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
VkRenderConfig class >> formatRenderedIn [
	"The format the render pass, the shaders and the readback of this project are all written
	 for. It is taken whenever a surface offers it so that a presented frame and an offscreen
	 frame are the same bytes in the same order. It is a choice this project makes rather than a
	 property of any surface, so it sits with the other render configuration constants."

	^ VkFormat b8g8r8a8Unorm
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
VkRenderConfig class >> presentModeNameFor: aValue [
	"The name of a present mode, found by asking which of this class's present-mode constants
	 carries the value, so nothing showing a mode can name one the creation code stopped using.
	 This class holds constants of several kinds, so the selectors are selected by prefix; the
	 unary ones are the constants, and this lookup itself shares the prefix. Answers the number
	 itself where no constant matches."

	^ (self class selectors
		   detect: [ :each |
			   each numArgs isZero and: [
				   ('presentMode*' match: each) and: [ (self perform: each) = aValue ] ] ]
		   ifNone: [ ^ aValue printString ]) asString
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

{ #category : 'constants' }
VkRenderConfig class >> subpassContents [
	"Every subpass in this project is recorded in the buffer that begins the pass, because the
	 pool allocates primary buffers only. It is a choice this project makes rather than a fact of
	 any one structure, so it sits with the other render configuration constants, where the
	 recorder above and the report below both read it."

	^ VkSubpassContents inline
]

{ #category : 'constants' }
VkRenderConfig class >> swapchainImagesBeyondMinimum [
	"One image more than the surface demands, so a frame can be drawn into one image while
	 another is being presented. Asking for exactly the minimum makes every frame wait for the
	 presentation engine to let go of an image. It is this project's choice, so it sits with the
	 other render configuration constants and both the creation code and the surface report read
	 it from here."

	^ 1
]
