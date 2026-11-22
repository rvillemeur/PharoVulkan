"
Tests for VkImage, the colour attachment this project owns rather than borrows from a swapchain.

Separate from VkCoreTest for two reasons: every test here builds VkContext offscreenGraphicsContext itself, because a colour attachment needs a device that can draw and VkCoreTest's shared compute context does not ask for one; and VkCoreTest had reached the method count Renraku refuses.
"
Class {
	#name : 'VkImageTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Graphics-Tests-Tests',
	#package : 'PharoVulkan-Graphics-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
VkImageTest >> testABorrowedImageDoesNotOwnItsHandle [
	"A swapchain hands out the images it created, and nothing that draws into one may destroy
	 it: the swapchain destroys them with itself. VkBorrowedImage says so, and that is the one
	 thing its teardown reads."

	| context owner borrowed |
	context := VkContext offscreenGraphicsContext.
	[
	owner := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage colorAttachmentBit.
	borrowed := VkBorrowedImage
		            on: context device
		            handle: owner handle
		            format: VkFormat b8g8r8a8Unorm
		            extent: 64 @ 64
		            usage: VkImageUsage transferDstBit.
	self assert: owner ownsHandle.
	self deny: borrowed ownsHandle.
	self assert: borrowed handle equals: owner handle ] ensure: [
		owner ifNotNil: [ owner destroy ].
		context destroy ]
]

{ #category : 'tests' }
VkImageTest >> testAnImageCanBeToldTheLayoutSomethingElseLeftItIn [
	"A render pass moves an image to the layout its attachment description ends in, and it does
	 that without a barrier of this image's own. The layout is what the recorded commands say,
	 so whoever recorded the pass says which layout it left — otherwise the next frame records
	 a barrier from a layout the image is no longer in. No driver is asked anything here: a
	 declaration records nothing."

	| image |
	image := VkBorrowedImage
		         on: nil
		         handle: nil
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage colorAttachmentBit.
	self assert: image layout equals: VkImageLayout undefined.
	image declareLayout: VkImageLayout presentSrcKHR.
	self assert: image layout equals: VkImageLayout presentSrcKHR.
	image declareLayoutUndefined.
	self assert: image layout equals: VkImageLayout undefined
]

{ #category : 'tests' }
VkImageTest >> testAnImageDeclaredUndefinedForgetsTheLayoutItWasLeftIn [
	"An image handed out again — a swapchain image acquired for the next frame — keeps nothing
	 of what the last frame left in it: its contents after a present are not guaranteed, so
	 whatever draws into it transitions from undefined, which discards them and is the cheapest
	 transition there is. Declaring it says so without recording anything."

	| context lender borrowed pool |
	context := VkContext offscreenGraphicsContext.
	[
	lender := VkImage
		          on: context device
		          format: VkFormat b8g8r8a8Unorm
		          extent: 64 @ 64
		          usage: VkImageUsage transferDstBit.
	borrowed := VkBorrowedImage
		            on: context device
		            handle: lender handle
		            format: VkFormat b8g8r8a8Unorm
		            extent: 64 @ 64
		            usage: VkImageUsage transferDstBit.
	pool := context device createCommandPool: context computeQueueFamily.
	[
	| buffer |
	buffer := pool allocateBuffer.
	buffer begin.
	borrowed transitionTo: VkImageLayout transferDstOptimal in: buffer.
	buffer end.
	context computeQueue submit: buffer andWait: true.
	self assert: borrowed layout equals: VkImageLayout transferDstOptimal.
	borrowed declareLayoutUndefined.
	self assert: borrowed layout equals: VkImageLayout undefined ]
		ensure: [ pool destroy ] ] ensure: [
		lender ifNotNil: [ lender destroy ].
		context destroy ]
]

{ #category : 'tests' }
VkImageTest >> testAttributeRowsNameTheLayoutAndWhoOwnsTheHandle [
	"The two facts a frame that copies into an image is read by: which layout the recorded
	 commands have left it in, named through the constant class rather than printed as a number,
	 and whether tearing this image down destroys the handle or lets go of it."

	| context owner borrowed rowsOf |
	context := VkContext offscreenGraphicsContext.
	rowsOf := [ :anImage :key |
	          (anImage attributeRows detect: [ :each | each key = key ]) value ].
	[
	owner := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage transferDstBit.
	borrowed := VkBorrowedImage
		            on: context device
		            handle: owner handle
		            format: VkFormat b8g8r8a8Unorm
		            extent: 64 @ 64
		            usage: VkImageUsage transferDstBit.
	self assert: (rowsOf value: owner value: 'Owns handle') equals: 'true'.
	self assert: (rowsOf value: borrowed value: 'Owns handle') equals: 'false'.
	self
		assert: ((rowsOf value: owner value: 'Layout') includesSubstring: 'undefined') ]
		ensure: [
			owner ifNotNil: [ owner destroy ].
			context destroy ]
]

{ #category : 'tests - image' }
VkImageTest >> testColorAttachmentImageIsCreatedAndBound [
	"A colour attachment needs a device that can draw, which setUp's compute context does not
	 ask for, so this test builds the offscreen context by name instead of reusing ctx."

	| context image |
	context := VkContext offscreenGraphicsContext.
	[
	image := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: (VkImageUsage colorAttachmentBit bitOr: VkImageUsage transferSrcBit).
	[
	self deny: image handle getHandle isNull.
	self deny: image memory isNil.
	self assert: image extent equals: 64 @ 64.
	self assert: image format equals: VkFormat b8g8r8a8Unorm ] ensure: [ image destroy ] ]
		ensure: [ context destroy ]
]

{ #category : 'tests' }
VkImageTest >> testDestroyingABorrowedImageLeavesTheHandleWithItsOwner [
	"Teardown of a borrowed image lets go of the handle and destroys nothing: the owner still
	 holds the image it created, and destroys it itself. Without this a frame that ends in a
	 swapchain image would free an image the swapchain frees again."

	| context owner borrowed |
	context := VkContext offscreenGraphicsContext.
	[
	owner := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage colorAttachmentBit.
	borrowed := VkBorrowedImage
		            on: context device
		            handle: owner handle
		            format: VkFormat b8g8r8a8Unorm
		            extent: 64 @ 64
		            usage: VkImageUsage transferDstBit.
	borrowed destroy.
	borrowed destroy.
	self assert: borrowed handle isNil.
	self deny: owner handle isNil.
	self deny: owner handle isNull ] ensure: [
		owner ifNotNil: [ owner destroy ].
		context destroy ]
]

{ #category : 'tests - image' }
VkImageTest >> testImageAttributeRowsAgreeWithTheImageAndChangeNothing [
	"The inspector reads these rows, so they must agree with the accessors, decode the
	 format and usage through the constant classes rather than restating them, and leave
	 the image exactly as it was."

	| context image rows valueFor |
	context := VkContext offscreenGraphicsContext.
	[
	image := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: (VkImageUsage colorAttachmentBit bitOr: VkImageUsage transferSrcBit).
	[
	rows := image attributeRows.
	valueFor := [ :key |
	            (rows detect: [ :each | each key = key ]) value ].
	self assert: ((valueFor value: 'Format') includesSubstring: 'b8g8r8a8Unorm').
	self assert: (valueFor value: 'Extent') equals: image extent printString.
	self
		assert: (valueFor value: 'Usage')
		equals: (VkImageUsage nameForFlags: image usage).
	self
		assert: (valueFor value: 'Memory size asked by driver')
		equals: image memorySize printString.
	self
		assert: (valueFor value: 'Memory size as width * height * 4')
		equals: (64 * 64 * 4) printString.
	self assert: (valueFor value: 'View created') equals: 'false'.
	self assert: (valueFor value: 'Live') equals: 'true'.
	self assert: image handle notNil.
	self assert: image memory notNil.
	self assert: image view isNil.
	image createView.
	self
		assert: ((image attributeRows detect: [ :each | each key = 'View created' ]) value)
		equals: 'true' ] ensure: [ image destroy ].
	self
		assert: ((image attributeRows detect: [ :each | each key = 'Live' ]) value)
		equals: 'false' ] ensure: [ context destroy ]
]

{ #category : 'tests - image' }
VkImageTest >> testImageDestroyIsIdempotent [
	"destroy is reached from ensure: blocks that may already have run once on the same
	 image, so the second call must do nothing rather than free a freed handle."

	| context image |
	context := VkContext offscreenGraphicsContext.
	[
	image := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage colorAttachmentBit.
	image createView.
	image destroy.
	image destroy.
	self assert: image handle isNil.
	self assert: image memory isNil.
	self assert: image view isNil ] ensure: [ context destroy ]
]

{ #category : 'tests' }
VkImageTest >> testImageMemoryRequirementsAnswerWhatTheDriverAsked [
	"The image's requirements come from the driver through the same declared structure the
	 buffer uses, and the answer is a copy in object memory, still readable after the image and
	 the external block have gone. The size demanded is at least the arithmetic size of the
	 pixels, because optimal tiling pads rows and may add a header."

	| context requirements |
	context := VkContext offscreenGraphicsContext.
	requirements := [
	                | image |
	                image := VkImage
		                         on: context device
		                         format: VkFormat b8g8r8a8Unorm
		                         extent: 64 @ 64
		                         usage: VkImageUsage colorAttachmentBit.
	                [ image memoryRequirements ] ensure: [ image destroy ] ]
		                ensure: [ context destroy ].
	self assert: requirements size >= (64 * 64 * 4).
	self assert: requirements alignment isPowerOfTwo.
	self assert: requirements memoryTypeBits > 0
]

{ #category : 'tests' }
VkImageTest >> testImageReportsTheMemorySizeTheDriverAsked [
	"The size bound must be the driver's, never width * height * 4: optimal tiling pads rows,
	 so arithmetic would bind too little. The driver is asked again here, independently of
	 the slot, which is the only way the two numbers can be seen to disagree; this machine
	 answers 20480 for a 64 by 64 image whose arithmetic size is 16384."

	| context image |
	context := VkContext offscreenGraphicsContext.
	[
	image := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage colorAttachmentBit.
	[
	self assert: image memorySize equals: image memoryRequirements size.
	self assert: image memorySize >= (64 * 64 * 4) ] ensure: [ image destroy ] ]
		ensure: [ context destroy ]
]

{ #category : 'tests - image' }
VkImageTest >> testOneBuilderServesImagesOfSeveralExtentsOnThisMachine [
	"Three images of three extents from the one request builder, on a real device. This is
	 the shape that would break if the builder kept state between calls, wrote the extent
	 into a block it shared, or freed the request before vkCreateImage had read it. Each
	 image is destroyed here, and each reports back the extent it was asked for rather than
	 the last one built."

	| context extents images |
	context := VkContext offscreenGraphicsContext.
	[
		extents := {
			           (16 @ 16).
			           VkImage exampleExtent.
			           (32 @ 64) }.
		images := extents collect: [ :each |
			          VkImage
				          on: context device
				          format: VkFormat b8g8r8a8Unorm
				          extent: each
				          usage: VkImageUsage colorAttachmentBit ].
		[
			images with: extents do: [ :image :extent |
				self deny: image handle getHandle isNull.
				self assert: image extent equals: extent.
				self assert: image memorySize >= (extent x * extent y * 4) ].
			self
				assert: (images collect: [ :each | each handle getHandle asInteger ])
						asSet size
				equals: images size ] ensure: [ images do: [ :each | each destroy ] ] ]
			ensure: [ context destroy ]
]

{ #category : 'tests - image' }
VkImageTest >> testOneRequestServesSeveralViewsOfOneImageOnThisMachine [
	"The swapchain creates one view per image it got from the surface, in a loop over the same
	 builder, and no machine without a window can run that loop: a swapchain needs a surface.
	 This leg runs the loop headlessly over one image instead, which is the shape that would
	 break if the builder kept state between calls or freed the request too early. The views
	 are separate objects and separate handles, and each is destroyed here because the image
	 owns only the one in its own slot."

	| context image views |
	context := VkContext offscreenGraphicsContext.
	[
		image := VkImage
			         on: context device
			         format: VkFormat b8g8r8a8Unorm
			         extent: VkImage exampleExtent
			         usage: VkImageUsage colorAttachmentBit.
		[
			views := (1 to: 3) collect: [ :each |
				         VkImage
					         viewOn: context device
					         image: image handle
					         format: image format ].
			[
				views do: [ :each | self deny: each getHandle isNull ].
				self
					assert: (views collect: [ :each | each getHandle asInteger ]) asSet size
					equals: views size ] ensure: [
				views do: [ :each |
					Vk
						destroyImageView: context device handle
						imageView: each
						allocator: ExternalAddress null.
					each invalidate ] ] ] ensure: [ image destroy ] ] ensure: [
		context destroy ]
]

{ #category : 'tests' }
VkImageTest >> testTheBarrierOfATransitionNamesBothLayoutsAndTheImage [
	"The structure a transition hands the driver: the layout the image is in, the layout it is
	 to be in, the image itself and the whole of its colour aspect. The transfer stage is both
	 sides of it, because the copy that follows is the reader and whatever wrote before it is
	 the writer this frame knows about."

	| context image barrier |
	context := VkContext offscreenGraphicsContext.
	[
	image := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage transferDstBit.
	barrier := VkCommandBuffer
		           imageBarrierFrom: VkImageLayout undefined
		           to: VkImageLayout transferDstOptimal
		           image: image.
	[
	self assert: barrier sType equals: VkStructureType imageMemoryBarrier2.
	self assert: barrier oldLayout equals: VkImageLayout undefined.
	self assert: barrier newLayout equals: VkImageLayout transferDstOptimal.
	self assert: barrier dstAccessMask equals: VkAccess2 transferWriteBit.
	self
		assert: barrier subresourceRange aspectMask
		equals: VkImageAspect colorBit.
	self assert: barrier subresourceRange layerCount equals: 1.
	self assert: barrier subresourceRange levelCount equals: 1 ] ensure: [
		barrier getHandle free ] ] ensure: [
		image ifNotNil: [ image destroy ].
		context destroy ]
]

{ #category : 'tests' }
VkImageTest >> testTransitioningAnImageMovesTheLayoutTheDriverAccepts [
	"The driver leg: a real command buffer on this machine records the transition, the queue
	 runs it, and the image says it is in the layout asked for. A barrier at a wrong offset or
	 with a count the dependency does not carry fails here rather than inside the copy."

	| context image pool buffer |
	context := VkContext offscreenGraphicsContext.
	[
	image := VkImage
		         on: context device
		         format: VkFormat b8g8r8a8Unorm
		         extent: 64 @ 64
		         usage: VkImageUsage transferDstBit.
	self assert: image layout equals: VkImageLayout undefined.
	pool := context device createCommandPool: context computeQueueFamily.
	[
	buffer := pool allocateBuffer.
	buffer begin.
	image transitionTo: VkImageLayout transferDstOptimal in: buffer.
	buffer end.
	context computeQueue submit: buffer andWait: true.
	self assert: image layout equals: VkImageLayout transferDstOptimal ]
		ensure: [ pool destroy ] ] ensure: [
		image ifNotNil: [ image destroy ].
		context destroy ]
]

{ #category : 'tests - image' }
VkImageTest >> testZeroExtentImageIsRefused [
	"Pins what the driver here actually answers, observed before the test was written:
	 vkCreateImage itself fails for a 0 by 0 extent, with VK_ERROR_OUT_OF_DEVICE_MEMORY
	 rather than an invalid-argument code. The exact code is the driver's choice, so only
	 that a result code was reported is asserted, not which one.

	 The substring check is what makes this test discriminate. With the result of
	 vkCreateImage left unchecked, a VkError is still raised, but it is 'No suitable memory
	 type found' from findMemoryType: further down, which would hide where the refusal
	 really was. That was established once by removing the check, and must not be repeated:
	 the unchecked path hands a null image handle to vkGetImageMemoryRequirements, which is
	 undefined behaviour and killed the image on the third run."

	| context raised |
	context := VkContext offscreenGraphicsContext.
	[
	raised := nil.
	[
	VkImage
		on: context device
		format: VkFormat b8g8r8a8Unorm
		extent: 0 @ 0
		usage: VkImageUsage colorAttachmentBit ]
		on: VkError
		do: [ :e | raised := e ].
	self deny: raised isNil.
	self assert: (raised messageText includesSubstring: 'VK_ERROR') ]
		ensure: [ context destroy ]
]
