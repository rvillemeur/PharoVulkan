"
Vulkan swapchain. Holds the queue of presentable images for a surface, creates one image view per image, acquires images and presents frames. Key methods: on:surface:extent:, acquireNextImage:fence:, present:queue:waitSemaphore:.

Creation asks the surface what it allows and what it offers rather than assuming either: imageCountFor: is how many images it requests, one more than the surface demands, held down to what it allows, with a maximum of zero read as no maximum; the format and colour space are the pair VkSurface class >> formatPreferredFrom: chose. createInfoForSurface:format:capabilities:extent: builds the declared VkSwapchainCreateInfoKHR from those answers, and handleForCreateInfo:on: is the only sender of vkCreateSwapchainKHR, so there is one place where a swapchain comes into being. imagesFromDriver enumerates the images the driver actually gave back, which may be more than were asked for, and the count the swapchain reports is that number.

present:queue:waitSemaphore: still writes VkPresentInfoKHR at counted offsets; that structure has its own unit in LAYOUT-PLAN.md.
"
Class {
	#name : 'VkSwapchain',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'surface',
		'images',
		'imageViews',
		'format',
		'extent',
		'imageCount'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'constants' }
VkSwapchain class >> acceptablePresentResults [
	"Codes an acquire or a present may answer that are not failures. VK_SUBOPTIMAL_KHR means the
	 swapchain still presents but no longer matches the surface, usually after a resize; with no
	 recreation path in this project the only honest response is to carry on with the frame."

	^ { VkResult vkSuboptimalKHR }
]

{ #category : 'constants' }
VkSwapchain class >> clipObscuredPixels [
	"VK_TRUE for the clipped field: the driver may discard pixels another window covers.
	 Nothing here reads a presented image back, so the pixels that would be discarded are
	 never looked at, and discarding them is what lets a driver present without a copy."

	^ 1
]

{ #category : 'instance creation' }
VkSwapchain class >> createInfoForSurface: aSurfaceHandle format: aSurfaceFormat capabilities: aCapabilities extent: aPoint [
	"The request every swapchain here is created from. The transform is the one the surface
	 reports itself in, which is what a surface that is rotated demands; the format and colour
	 space are the pair the surface offered. The flags, the exclusive sharing mode, both queue
	 family fields and the old swapchain are the zeros a fresh block holds: no swapchain here
	 shares its images between queue families, and none replaces another, because there is no
	 recreation path. The caller frees getHandle."

	| info |
	info := VkSwapchainCreateInfoKHR externalInstance.
	info
		surface: aSurfaceHandle;
		minImageCount: (self imageCountFor: aCapabilities);
		imageFormat: aSurfaceFormat format;
		imageColorSpace: aSurfaceFormat colorSpace;
		imageArrayLayers: VkImage arrayLayerCount;
		imageUsage: VkImageUsage colorAttachmentBit;
		preTransform: aCapabilities currentTransform;
		compositeAlpha: VkCompositeAlpha opaqueBit;
		presentMode: VkRenderConfig presentModeFifo;
		clipped: self clipObscuredPixels.
	info imageExtent width: aPoint x; height: aPoint y.
	^ info
]

{ #category : 'instance creation' }
VkSwapchain class >> handleForCreateInfo: aCreateInfo on: aDevice [
	"The one call to vkCreateSwapchainKHR in the project. The out parameter is freed whichever
	 way the call goes, and the result is checked before the handle is read: reading it after a
	 failed call would dereference whatever the out parameter held."

	| out result |
	out := ExternalAddress allocate: ExternalAddress wordSize.
	^ [
	  result := Vk
		            createSwapchainKHR: aDevice handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            swapchain: out.
	  Vk checkResult: result.
	  VkSwapchainKHR_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'instance creation' }
VkSwapchain class >> imageCountFor: aCapabilities [
	"How many images to ask the surface for: one more than it demands, held down to what it
	 allows. A maximum of zero is no maximum, so the clamp is skipped there rather than
	 clamping the request to nothing."

	| wanted |
	wanted := aCapabilities minImageCount + self imagesBeyondMinimum.
	aCapabilities maxImageCount = self unlimitedImageCount ifTrue: [ ^ wanted ].
	^ wanted min: aCapabilities maxImageCount
]

{ #category : 'constants' }
VkSwapchain class >> imageHandleByteCount [
	"A swapchain image entry is one handle wide. The driver writes the run of image handles
	 into a plain block with no field specification to read a width from, so the stride is
	 named here."

	^ ExternalAddress wordSize
]

{ #category : 'constants' }
VkSwapchain class >> imagesBeyondMinimum [
	"One image more than the surface demands, so a frame can be drawn into one image while
	 another is being presented. Asking for exactly the minimum makes every frame wait for
	 the presentation engine to let go of an image."

	^ 1
]

{ #category : 'instance creation' }
VkSwapchain class >> on: aVkDevice surface: aVkSurface extent: aPoint [
    ^ self new initializeDevice: aVkDevice surface: aVkSurface extent: aPoint
]

{ #category : 'accessing' }
VkSwapchain class >> presentModeNameFor: aValue [
	"The name of a present mode, found by asking VkRenderConfig which of its present-mode
	 constants carries the value, so nothing showing a mode can name one the creation code
	 stopped using. VkRenderConfig holds constants of several kinds, so the selectors are
	 selected by prefix rather than by protocol. Answers the number itself where no constant
	 matches."

	^ (VkRenderConfig class selectors
		   detect: [ :each |
			   ('presentMode*' match: each) and: [
				   (VkRenderConfig perform: each) = aValue ] ]
		   ifNone: [ ^ aValue printString ]) asString
]

{ #category : 'constants' }
VkSwapchain class >> unlimitedImageCount [
	"What VkSurfaceCapabilitiesKHR reports as maxImageCount when the surface sets no upper
	 bound. It is a sentinel and not a count: clamping a request to it would ask for a
	 swapchain of no images."

	^ 0
]

{ #category : 'rendering' }
VkSwapchain >> acquireNextImage: semaphore fence: fence [

	| idxBuf result |
	idxBuf := ExternalAddress allocate: 4.
	^ [
	  result := Vk
		            acquireNextImageKHR: device handle
		            swapchain: handle
		            timeout: 18446744073709551615
		            semaphore: semaphore
		            fence: fence
		            pImageIndex: idxBuf.
	  Vk checkResult: result acceptable: self class acceptablePresentResults.
	  idxBuf unsignedLongAt: 1 ] ensure: [ idxBuf free ]
]

{ #category : 'initialization' }
VkSwapchain >> createImageViews [
	"One view per image the surface gave back, created from the same request the offscreen
	 attachment uses: VkImage class >> viewOn:image:format: writes it, so the swapchain no
	 longer keeps a second copy of the layout."

	imageViews := images collect: [ :each |
		              VkImage viewOn: device image: each format: format ]
]

{ #category : 'lifecycle' }
VkSwapchain >> destroy [

	imageViews ifNotNil: [
			imageViews do: [ :iv |
					Vk
						destroyImageView: device handle
						imageView: iv
						allocator: ExternalAddress null.
					iv invalidate ].
			imageViews := nil ].
	handle ifNotNil: [
			Vk
				destroySwapchainKHR: device handle
				swapchain: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ].
	images ifNotNil: [
			images do: [ :img | img invalidate ].
			images := nil ]
]

{ #category : 'accessing' }
VkSwapchain >> extent [
    ^ extent
]

{ #category : 'accessing' }
VkSwapchain >> format [
    ^ format
]

{ #category : 'accessing' }
VkSwapchain >> handle [
    ^ handle
]

{ #category : 'accessing' }
VkSwapchain >> imageCount [
    ^ imageCount
]

{ #category : 'accessing' }
VkSwapchain >> imageViews [
    ^ imageViews
]

{ #category : 'accessing' }
VkSwapchain >> images [
    ^ images
]

{ #category : 'initialization' }
VkSwapchain >> imagesFromDriver [
	"The images the driver made for this swapchain. The count comes back from a call with a
	 null run and stays in its buffer, because the call that fills the run needs it there as
	 well. The run is a block of handles with no field specification to read a width from, so
	 it is read by the stride this class names. Both blocks are freed whichever way the calls
	 go: the handles are copied out of the run before it goes."

	| countBuffer |
	countBuffer := ExternalAddress allocate: Vk countByteCount.
	^ [
	  | count run result |
	  result := Vk
		            getSwapchainImagesKHR: device handle
		            swapchain: handle
		            pSwapchainImageCount: countBuffer
		            pSwapchainImages: ExternalAddress null.
	  Vk checkResult: result.
	  count := countBuffer unsignedLongAt: 1.
	  run := ExternalAddress allocate:
		         count * self class imageHandleByteCount.
	  [
	  result := Vk
		            getSwapchainImagesKHR: device handle
		            swapchain: handle
		            pSwapchainImageCount: countBuffer
		            pSwapchainImages: run.
	  Vk checkResult: result.
	  (1 to: count) collect: [ :index |
		  VkImage_H fromHandle: (run
				   pointerAt: index - 1 * self class imageHandleByteCount + 1) ] ]
		  ensure: [ run free ] ] ensure: [ countBuffer free ]
]

{ #category : 'initialization' }
VkSwapchain >> initializeDevice: aVkDevice surface: aVkSurface extent: aPoint [
	"The surface is asked what it allows and what it offers, the request is built from those
	 answers, and the driver is asked for a swapchain. The request is freed whichever way the
	 creation goes: the driver reads it during the call and never afterwards. The image count
	 is what the driver answers rather than what was asked for, because it may make more
	 images than the request named."

	| capabilities info |
	device := aVkDevice.
	surface := aVkSurface.
	extent := aPoint.
	capabilities := aVkSurface capabilities.
	info := self class
		        createInfoForSurface: aVkSurface handle
		        format: aVkSurface preferredFormat
		        capabilities: capabilities
		        extent: aPoint.
	format := info imageFormat.
	handle := [ self class handleForCreateInfo: info on: device ] ensure: [
		          info getHandle free ].
	images := self imagesFromDriver.
	imageCount := images size.
	self createImageViews
]

{ #category : 'rendering' }
VkSwapchain >> present: imageIndex queue: aVkQueue waitSemaphore: semaphore [
    "VkPresentInfoKHR (64 bytes):
     0:sType  8:pNext  16:waitSemaphoreCount  20:pWaitSemaphores(ptr)
     28:swapchainCount  32:pSwapchains(ptr)  40:pImageIndices(ptr)  48:pResults(ptr)"
    | semBuf presentInfo result |
    semBuf := ExternalAddress allocate: 8.
    [ semBuf pointerAt: 1 put: semaphore getHandle.
      presentInfo := ExternalAddress allocate: 64.
      [ | idxBuf swapBuf |
        idxBuf := ExternalAddress allocate: 4.
        swapBuf := ExternalAddress allocate: 8.
        [ idxBuf unsignedLongAt: 1 put: imageIndex.
          swapBuf pointerAt: 1 put: handle getHandle.
          presentInfo unsignedLongAt: 1  put: VkStructureType presentInfoKHR.
          presentInfo pointerAt:   9  put: ExternalAddress null.
          presentInfo unsignedLongAt: 17 put: 1.
          presentInfo pointerAt:   25 put: semBuf.
          presentInfo unsignedLongAt: 33 put: 1.
          presentInfo pointerAt:   41 put: swapBuf.
          presentInfo pointerAt:   49 put: idxBuf.
          presentInfo pointerAt:   57 put: ExternalAddress null.
          result := Vk queuePresentKHR: aVkQueue handle pPresentInfo: presentInfo.
          Vk checkResult: result acceptable: self class acceptablePresentResults
        ] ensure: [ idxBuf free. swapBuf free ]
      ] ensure: [ presentInfo free ]
    ] ensure: [ semBuf free ]
]

{ #category : 'accessing' }
VkSwapchain >> presentMode [
	"The swapchain is always created with VkRenderConfig presentModeFifo, so this reads that
	 same constant rather than a copy stored at creation: the two cannot disagree."

	^ VkRenderConfig presentModeFifo
]

{ #category : 'accessing' }
VkSwapchain >> presentModeName [
	"The name of this swapchain's present mode. The lookup lives on the class side, because
	 the request's own report needs it too and one copy of it cannot drift from the other."

	^ self class presentModeNameFor: self presentMode
]
