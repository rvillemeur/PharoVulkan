"
An offscreen render target: a colour image this project owns, a render pass that leaves it ready to be copied, a framebuffer over it, and a host-visible buffer the rendered pixels are copied into. It is what makes a rendered picture assertable, because a swapchain image is presented to a surface and cannot be read back.

Build one with `on:extent:`, set `clearColor:` if the default black will not do, then `renderWith:on:pool:` to record and submit one frame; the block it evaluates receives the command buffer, so a caller can draw inside the render pass. Afterwards `pixels` answers the raw bytes and `pixelAtX:y:` answers one pixel as r, g, b, a integers. `destroy` releases the Vulkan objects but keeps the bytes, so a destroyed target still answers what it rendered.
"
Class {
	#name : 'PVOffscreenTarget',
	#superclass : 'Object',
	#instVars : [
		'extent',
		'image',
		'renderPass',
		'framebuffer',
		'readbackBuffer',
		'clearColor',
		'pixelBytes'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'constants' }
PVOffscreenTarget class >> bytesPerPixel [
	"Four, because the target renders in the one format it supports."

	^ 4
]

{ #category : 'constants' }
PVOffscreenTarget class >> colorFormat [
	"The same format the swapchain path uses, so a picture rendered offscreen is the picture a
	 window would have shown. pixelAtX:y: knows this format's b, g, r, a byte order.
	 Not named format: that selector already means the instance specification on Behaviour, and
	 a class-side format here would override it."

	^ VkFormat b8g8r8a8Unorm
]

{ #category : 'constants' }
PVOffscreenTarget class >> exampleClearColor [
	"Visibly not black, so an example that rendered nothing cannot be mistaken for one that
	 rendered a clear."

	^ #( 0.25 0.5 0.75 1.0 )
]

{ #category : 'constants' }
PVOffscreenTarget class >> exampleExtent [
	"Small enough that every sampled pixel can be checked by eye in the inspector."

	^ 32 @ 32
]

{ #category : 'instance creation' }
PVOffscreenTarget class >> on: aDevice extent: aPoint [
	^ self new initializeDevice: aDevice extent: aPoint
]

{ #category : 'constants' }
PVOffscreenTarget class >> swatchDepth [
	"32 bits, so a swatch needs no palette and shows the exact channel values read back."

	^ 32
]

{ #category : 'constants' }
PVOffscreenTarget class >> swatchExtent [
	"Size of one colour cell in the inspector table."

	^ 16 @ 16
]

{ #category : 'accessing' }
PVOffscreenTarget >> byteSize [
	^ extent x * extent y * self class bytesPerPixel
]

{ #category : 'accessing' }
PVOffscreenTarget >> clearColor [
	^ clearColor
]

{ #category : 'accessing' }
PVOffscreenTarget >> clearColor: anArray [
	"r, g, b, a floats in 0.0 to 1.0. Defaults to the black the window path clears to, so a
	 target behaves like a window unless told otherwise."

	clearColor := anArray
]

{ #category : 'releasing' }
PVOffscreenTarget >> destroy [
	"Reverse creation order, and safe to call twice. pixelBytes survives on purpose: that is
	 what lets an example hand back a target that still answers what it rendered."

	readbackBuffer ifNotNil: [
		readbackBuffer destroy.
		readbackBuffer := nil ].
	framebuffer ifNotNil: [
		framebuffer destroy.
		framebuffer := nil ].
	renderPass ifNotNil: [
		renderPass destroy.
		renderPass := nil ].
	image ifNotNil: [
		image destroy.
		image := nil ]
]

{ #category : 'accessing' }
PVOffscreenTarget >> extent [
	^ extent
]

{ #category : 'initialization' }
PVOffscreenTarget >> initializeDevice: aDevice extent: aPoint [
	"The device is not kept: every Vulkan object built here holds the device it needs, so a
	 slot for it would be state nothing reads.
	 ifCurtailed: so a target that fails half way through cannot strand the objects it did
	 manage to create, as PVHelloTriangleScene class >> prepare:backendWindow: does."

	extent := aPoint.
	clearColor := VkRenderConfig clearColorBlackOpaque.
	[
	image := VkImage
		         on: aDevice
		         format: self class colorFormat
		         extent: extent
		         usage:
		         (VkImageUsage colorAttachmentBit bitOr: VkImageUsage transferSrcBit).
	image createView.
	renderPass := VkRenderPass
		              createOffscreenColorPassDevice: aDevice
		              format: self class colorFormat.
	framebuffer := VkFramebuffer
		               on: aDevice
		               renderPass: renderPass
		               imageView: image view
		               extent: extent.
	readbackBuffer := VkBuffer
		                  on: aDevice
		                  size: self byteSize
		                  usage: VkBufferUsage transferDstBit ] ifCurtailed: [
		self destroy ]
]

{ #category : 'inspector' }
PVOffscreenTarget >> inspectorPixels: aBuilder [
	"Each row reads the bytes through pixelAtX:y:, the same method a test asserts with, so the
	 swatch cannot show a colour the assertions would not see. Nothing is submitted and the
	 buffer is never re-mapped, so opening the inspector cannot change what is inspected."

	<inspectorPresentationOrder: 10 title: 'Pixels'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Coordinate'
				   evaluated: [ :each | each printString ]);
		  addColumn: (SpStringTableColumn title: 'R G B A' evaluated: [ :each |
					   ((self pixelAtX: each x y: each y)
						    collect: [ :channel | channel printString ])
						   inject: ''
						   into: [ :acc :channel |
							   acc isEmpty
								   ifTrue: [ channel ]
								   ifFalse: [ acc , ' ' , channel ] ] ]);
		  addColumn: (SpImageTableColumn evaluated: [ :each |
					   self swatchFor: (self pixelAtX: each x y: each y) ]);
		  items: self pixelProbeCoordinates;
		  yourself
]

{ #category : 'accessing' }
PVOffscreenTarget >> pixelAtX: x y: y [
	"An Array of r, g, b, a integers in 0 to 255. The format stores b, g, r, a, and this is the
	 only place that order is known. Coordinates outside the extent raise, rather than reading
	 the neighbouring row the arithmetic would otherwise land in."

	| base |
	((x between: 0 and: extent x - 1) and: [
		 y between: 0 and: extent y - 1 ]) ifFalse: [
		^ self error:
			  'Coordinate ' , (x @ y) printString , ' is outside the extent '
			  , extent printString ].
	base := y * extent x + x * self class bytesPerPixel.
	^ {
		  (pixelBytes at: base + 3).
		  (pixelBytes at: base + 2).
		  (pixelBytes at: base + 1).
		  (pixelBytes at: base + 4) }
]

{ #category : 'accessing' }
PVOffscreenTarget >> pixelProbeCoordinates [
	"The coordinates the inspector samples: the four corners and the centre, derived from the
	 extent rather than listed, so they stay inside any target, and de-duplicated so a one
	 pixel target shows one row. Empty until a frame has been rendered."

	| last |
	(pixelBytes isNil or: [ extent isNil ]) ifTrue: [ ^ OrderedCollection new ].
	last := extent - (1 @ 1).
	^ {
		  (0 @ 0).
		  (last x @ 0).
		  (0 @ last y).
		  last.
		  (last // 2) } asOrderedCollection removeDuplicates
]

{ #category : 'accessing' }
PVOffscreenTarget >> pixels [
	"The readback bytes, or nil until a frame has been rendered."

	^ pixelBytes
]

{ #category : 'accessing' }
PVOffscreenTarget >> renderPass [
	"The target owns this render pass; a pipeline drawn into the target must be built against
	 it, so a scene needs to see it."

	^ renderPass
]

{ #category : 'rendering' }
PVOffscreenTarget >> renderWith: aBlock on: aQueue pool: aCommandPool [
	"Records one frame, submits it, waits, and reads the pixels back. aBlock is evaluated with
	 the command buffer inside the render pass, so a caller can draw; an empty block renders
	 nothing but the clear."

	| cmd |
	cmd := aCommandPool allocateBuffer.
	cmd do: [ :c |
		c
			beginRenderPass: renderPass
			framebuffer: framebuffer
			extent: extent
			clearColor: clearColor.
		aBlock value: c.
		c endRenderPass.
		c
			copyImage: image
			layout: VkImageLayout transferSrcOptimal
			toBuffer: readbackBuffer
			extent: extent.
		c barrierForHostRead ].
	aQueue submit: cmd andWait: true.
	pixelBytes := readbackBuffer copyToByteArray
]

{ #category : 'inspector' }
PVOffscreenTarget >> swatchFor: anArray [
	"A colour cell for one r, g, b, a pixel. Built from the pixel the table read, never from
	 clearColor, so a readback that disagrees with what was asked for is visible."

	| form |
	form := Form
		        extent: self class swatchExtent
		        depth: self class swatchDepth.
	form fillColor: (Color
			 r: (anArray at: 1) / 255
			 g: (anArray at: 2) / 255
			 b: (anArray at: 3) / 255).
	^ form
]
