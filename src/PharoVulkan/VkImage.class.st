"
A colour attachment this project creates, allocates, views and destroys itself.

A swapchain owns its images: it creates them from the surface, and VkSwapchain only reads them back. Rendering with no surface therefore has nothing to render into, so this class supplies the image instead. Key methods: create, which pairs createInfoForFormat:extent:usage: with handleForCreateInfo:on: — the only caller of vkCreateImage — allocate (device-local memory for the size the driver asks for, kept in memorySize), createView (the VkImageView_H that VkFramebuffer takes) and destroy, which releases view, image and memory in that order and is safe to run twice.

Both structures the driver reads here are declared rather than counted out in bytes: VkImageCreateInfo and VkImageViewCreateInfo, each with one writer on this class side. mipLevelCount and arrayLayerCount serve both — the view covers every level and layer the image was created with — and imageDepth is one, because every image here is flat.

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

{ #category : 'constants' }
VkImage class >> arrayLayerCount [
	"One layer: no path here renders into a layered image. The view covers every layer the
	 image has, so this is the count the image is created with and the count the view reads."

	^ 1
]

{ #category : 'instance creation' }
VkImage class >> createInfoForFormat: aFormat extent: aPoint usage: usageFlags [
	"The request every image here is created from. The flags, the tiling, the sharing mode,
	 the initial layout and both queue family fields are the zeros a fresh block holds:
	 VkImageTiling optimal, VkRenderConfig sharingModeExclusive and VkImageLayout undefined
	 are all zero, and no image here is shared between queue families. The caller frees
	 getHandle."

	| info |
	info := VkImageCreateInfo externalInstance.
	info
		imageType: VkImageType type2D;
		format: aFormat;
		mipLevels: self mipLevelCount;
		arrayLayers: self arrayLayerCount;
		samples: VkRenderConfig sampleCount1Bit;
		usage: usageFlags.
	info extent
		width: aPoint x;
		height: aPoint y;
		depth: self imageDepth.
	^ info
]

{ #category : 'instance creation' }
VkImage class >> handleForCreateInfo: aCreateInfo on: aDevice [
	"The one call to vkCreateImage in the project. The out parameter is freed whichever way
	 the call goes, and the result is checked before the handle is read: reading it after a
	 failed call would hand a null image to vkGetImageMemoryRequirements, which is undefined
	 behaviour and killed the image once."

	| out result |
	out := ExternalAddress allocate: ExternalAddress wordSize.
	^ [ result := Vk
		           createImage: aDevice handle
		           createInfo: aCreateInfo getHandle
		           allocator: ExternalAddress null
		           pImage: out.
	  Vk checkResult: result.
	  VkImage_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'instance creation' }
VkImage class >> handleForViewRequest: aCreateInfo on: aDevice [
	"The one call to vkCreateImageView in the project. The out parameter is freed whichever
	 way the call goes; the result is checked before the handle is read, because reading it
	 after a failed call would dereference whatever the out parameter held."

	| out result |
	out := ExternalAddress allocate: ExternalAddress wordSize.
	^ [ result := Vk
		           createImageView: aDevice handle
		           createInfo: aCreateInfo getHandle
		           allocator: ExternalAddress null
		           pView: out.
	  Vk checkResult: result.
	  VkImageView_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'constants' }
VkImage class >> imageDepth [
	"One texel deep: every image this project creates is a flat colour target, which is also
	 why its dimensionality is type2D. The depth is written rather than left at zero, because
	 a two dimensional image must still be one deep — a zero depth is refused by the driver."

	^ 1
]

{ #category : 'constants' }
VkImage class >> mipLevelCount [
	"One level: nothing here samples an image with a mip chain. The view covers every level
	 the image has, so this is the count the image is created with and the count the view
	 reads."

	^ 1
]

{ #category : 'instance creation' }
VkImage class >> on: aDevice format: aFormat extent: anExtent usage: usageFlags [
	^ self new initializeDevice: aDevice format: aFormat extent: anExtent usage: usageFlags
]

{ #category : 'instance creation' }
VkImage class >> viewOn: aDevice image: anImageHandle format: aFormat [
	"A view over one image, from the request every view here shares. The request is freed
	 whichever way the creation goes."

	| info |
	info := self viewRequestFor: anImageHandle format: aFormat.
	^ [ self handleForViewRequest: info on: aDevice ] ensure: [
		  info getHandle free ]
]

{ #category : 'instance creation' }
VkImage class >> viewRequestFor: anImageHandle format: aFormat [
	"The request both view paths are created from: a two dimensional colour view over the
	 whole of one image. The level and layer counts are the image's own, because the view
	 covers every level and layer the image was created with. The base level, the base layer
	 and the swizzle are the zeros a fresh block holds, and a zero swizzle is the identity
	 swizzle. The caller frees getHandle."

	| info |
	info := VkImageViewCreateInfo externalInstance.
	info
		image: anImageHandle;
		viewType: VkRenderConfig imageViewType2D;
		format: aFormat.
	info subresourceRange
		aspectMask: VkImageAspect colorBit;
		levelCount: self mipLevelCount;
		layerCount: self arrayLayerCount.
	^ info
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

{ #category : 'lifecycle' }
VkImage >> create [
	"The request is freed whichever way the creation goes: the driver reads it during the
	 call and never afterwards."

	| info |
	info := self class
		        createInfoForFormat: format
		        extent: extent
		        usage: usage.
	handle := [ self class handleForCreateInfo: info on: device ] ensure: [
		          info getHandle free ]
]

{ #category : 'initialization' }
VkImage >> createView [
	"The view VkFramebuffer takes. The request and the call both live on the class side,
	 shared with the swapchain's images, so this method only keeps what it is given."

	view := self class viewOn: device image: handle format: format.
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
