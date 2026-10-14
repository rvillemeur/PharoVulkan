"
Tests for VkImage, the colour attachment this project owns rather than borrows from a swapchain.

Separate from VkCoreTest for two reasons: every test here builds VkContext offscreenGraphicsContext itself, because a colour attachment needs a device that can draw and VkCoreTest's shared compute context does not ask for one; and VkCoreTest had reached the method count Renraku refuses.
"
Class {
	#name : 'VkImageTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Graphics',
	#package : 'PharoVulkan-Tests',
	#tag : 'Graphics'
}

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
