"
A colour attachment this project creates, allocates, views and destroys itself.

A swapchain owns its images: it creates them from the surface, and VkSwapchain only reads them back. Rendering with no surface therefore has nothing to render into, so this class supplies the image instead. Key methods: create (writes the 88-byte VkImageCreateInfo), allocate (device-local memory for the size the driver asks for, kept in memorySize), createView (the VkImageView_H that VkFramebuffer takes) and destroy, which releases view, image and memory in that order and is safe to run twice.

The tiling is VkImageTiling optimal, so the host cannot read this memory by mapping it; a readback has to copy the image into a buffer.
"
Class {
	#name : 'VkImage',
	#superclass : 'Object',
	#instVars : [
		'device',
		'format',
		'extent',
		'usage',
		'handle',
		'memory',
		'view',
		'memorySize'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'examples' }
VkImage class >> exampleColorAttachmentOnThisMachine [
	"One click: the colour attachment an offscreen render would draw into on whatever device
	 this image finds, with its view created, then destroyed before it is handed back. Format,
	 extent, usage and the memory size the driver asked for live in the instance, so the
	 object still answers them after its handles and its context have gone."

	<sampleInstance>
	| context image |
	context := VkContext offscreenGraphicsContext.
	^ [
	  image := self
		           on: context device
		           format: VkFormat b8g8r8a8Unorm
		           extent: self exampleExtent
		           usage:
		           (VkImageUsage colorAttachmentBit bitOr: VkImageUsage transferSrcBit).
	  image createView.
	  image destroy.
	  image ] ensure: [ context destroy ]
]

{ #category : 'constants' }
VkImage class >> exampleExtent [
	"Small enough that a readback can be checked by eye, and a multiple of 64 so a driver
	 that pads rows still pads by whole tiles."

	^ 64 @ 64
]

{ #category : 'instance creation' }
VkImage class >> on: aDevice format: aFormat extent: anExtent usage: usageFlags [
	^ self new initializeDevice: aDevice format: aFormat extent: anExtent usage: usageFlags
]

{ #category : 'initialization' }
VkImage >> allocate [
	"Back the image with device-local memory and bind it. The size kept is the driver's, not
	 width * height * 4: optimal tiling pads rows and may add a header, so binding the
	 arithmetic size would bind too little."

	| requirements |
	requirements := self memoryRequirements.
	memorySize := requirements size.
	memory := device
		          allocateMemoryFor: requirements
		          properties: VkMemoryProperty deviceLocalBit.
	Vk checkResult: (Vk
			 bindImageMemory: device handle
			 image: handle
			 memory: memory
			 memoryOffset: 0)
]

{ #category : 'inspecting' }
VkImage >> attributeRows [
	"Name -> value for what the inspector shows. The format and usage names come from the
	 constant classes by reflection, so this list cannot name a format the image does not
	 carry or hide a usage bit the driver was asked for. Reads slots only."

	^ {
		  ('Format' -> ((VkFormat nameForValue: format)
			    ifNil: [ format printString ]
			    ifNotNil: [ :name | name , ' (' , format printString , ')' ])).
		  ('Extent' -> extent printString).
		  ('Usage' -> (VkImageUsage nameForFlags: usage)).
		  ('Memory size asked by driver' -> memorySize printString).
		  ('Memory size as width * height * 4'
		   -> (extent x * extent y * 4) printString).
		  ('View created' -> view notNil printString).
		  ('Live' -> handle notNil printString) }
]

{ #category : 'initialization' }
VkImage >> create [
	"VkImageCreateInfo, 88 bytes, 1-based offsets: 1:sType 9:pNext 17:flags 21:imageType
	 25:format 29,33,37:extent w,h,d 41:mipLevels 45:arrayLayers 49:samples 53:tiling
	 57:usage 61:sharingMode 65:queueFamilyIndexCount [69 pad] 73:pQueueFamilyIndices
	 81:initialLayout [85 pad]. Offsets 69 and 85 are padding and are deliberately not
	 written; ExternalAddress allocate: zeroes the block."

	| info outBuf result |
	info := ExternalAddress allocate: 88.
	[
	info unsignedLongAt: 1 put: VkStructureType imageCreateInfo.
	info pointerAt: 9 put: ExternalAddress null.
	info unsignedLongAt: 17 put: 0.
	info unsignedLongAt: 21 put: VkImageType type2D.
	info unsignedLongAt: 25 put: format.
	info unsignedLongAt: 29 put: extent x.
	info unsignedLongAt: 33 put: extent y.
	info unsignedLongAt: 37 put: 1.
	info unsignedLongAt: 41 put: 1.
	info unsignedLongAt: 45 put: 1.
	info unsignedLongAt: 49 put: VkRenderConfig sampleCount1Bit.
	info unsignedLongAt: 53 put: VkImageTiling optimal.
	info unsignedLongAt: 57 put: usage.
	info unsignedLongAt: 61 put: VkRenderConfig sharingModeExclusive.
	info unsignedLongAt: 65 put: 0.
	info pointerAt: 73 put: ExternalAddress null.
	info unsignedLongAt: 81 put: VkImageLayout undefined.
	outBuf := ExternalAddress allocate: 8.
	[
	result := Vk
		          createImage: device handle
		          createInfo: info
		          allocator: ExternalAddress null
		          pImage: outBuf.
	Vk checkResult: result.
	handle := VkImage_H fromHandle: (outBuf pointerAt: 1) ] ensure: [ outBuf free ] ]
		ensure: [ info free ]
]

{ #category : 'initialization' }
VkImage >> createView [
	"VkImageViewCreateInfo, 80 bytes, 1-based: 1:sType 9:pNext 17:flags 25:image 33:viewType
	 37:format 41..53:components r,g,b,a 57..73:subresourceRange aspectMask, baseMipLevel,
	 levelCount, baseArrayLayer, layerCount. Same layout VkSwapchain writes for its own
	 images; the component swizzles stay 0, which is VK_COMPONENT_SWIZZLE_IDENTITY."

	| info outBuf result |
	info := ExternalAddress allocate: 80.
	[
	info unsignedLongAt: 1 put: VkStructureType imageViewCreateInfo.
	info pointerAt: 9 put: ExternalAddress null.
	info unsignedLongAt: 17 put: 0.
	info pointerAt: 25 put: handle getHandle.
	info unsignedLongAt: 33 put: VkRenderConfig imageViewType2D.
	info unsignedLongAt: 37 put: format.
	info unsignedLongAt: 41 put: 0.
	info unsignedLongAt: 45 put: 0.
	info unsignedLongAt: 49 put: 0.
	info unsignedLongAt: 53 put: 0.
	info unsignedLongAt: 57 put: VkRenderConfig imageAspectColorBit.
	info unsignedLongAt: 61 put: 0.
	info unsignedLongAt: 65 put: 1.
	info unsignedLongAt: 69 put: 0.
	info unsignedLongAt: 73 put: 1.
	outBuf := ExternalAddress allocate: 8.
	[
	result := Vk
		          createImageView: device handle
		          createInfo: info
		          allocator: ExternalAddress null
		          pView: outBuf.
	Vk checkResult: result.
	view := VkImageView_H fromHandle: (outBuf pointerAt: 1) ] ensure: [ outBuf free ] ]
		ensure: [ info free ].
	^ view
]

{ #category : 'releasing' }
VkImage >> destroy [
	"Release in reverse creation order, nilling each slot so a second call is safe: this is
	 reached from ensure: blocks that may already have run once on the same image."

	view ifNotNil: [
		Vk
			destroyImageView: device handle
			imageView: view
			allocator: ExternalAddress null.
		view invalidate.
		view := nil ].
	handle ifNotNil: [
		Vk
			destroyImage: device handle
			image: handle
			allocator: ExternalAddress null.
		handle invalidate.
		handle := nil ].
	memory ifNotNil: [
		Vk
			freeMemory: device handle
			memory: memory
			allocator: ExternalAddress null.
		memory invalidate.
		memory := nil ]
]

{ #category : 'accessing' }
VkImage >> extent [
	^ extent
]

{ #category : 'accessing' }
VkImage >> format [
	^ format
]

{ #category : 'accessing' }
VkImage >> handle [
	^ handle
]

{ #category : 'initialization' }
VkImage >> initializeDevice: aDevice format: aFormat extent: anExtent usage: usageFlags [
	device := aDevice.
	format := aFormat.
	extent := anExtent.
	usage := usageFlags.
	self create.
	self allocate
]

{ #category : 'inspecting' }
VkImage >> inspectorImage: aBuilder [
	"Shows both memory sizes side by side, because the gap between them is the padding
	 optimal tiling adds and the reason the driver's number is the one bound."

	<inspectorPresentationOrder: 10 title: 'Image'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Attribute'
				   evaluated: [ :each | each key ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each | each value ]);
		  items: self attributeRows;
		  yourself
]

{ #category : 'accessing' }
VkImage >> memory [
	^ memory
]

{ #category : 'private' }
VkImage >> memoryRequirements [
	"What the driver demands to back this image. The block it writes lives outside the image
	 and is freed here, so the answer is a copy in object memory the caller can keep."

	| requirements |
	requirements := VkMemoryRequirements externalInstance.
	^ [
	  Vk
		  getImageMemoryRequirements: device handle
		  image: handle
		  memoryRequirements: requirements getHandle.
	  requirements copyIntoObjectMemory ] ensure: [
		  requirements getHandle free ]
]

{ #category : 'accessing' }
VkImage >> memorySize [
	"The byte count the driver asked for, which optimal tiling makes larger than
	 width * height * 4."

	^ memorySize
]

{ #category : 'accessing' }
VkImage >> usage [
	^ usage
]

{ #category : 'accessing' }
VkImage >> view [
	"Answers nil until createView has run; the image is usable as a transfer target
	 without one, and only a framebuffer attachment needs it."

	^ view
]
