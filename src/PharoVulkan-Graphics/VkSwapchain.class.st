"
Vulkan swapchain. Holds the queue of presentable images for a surface, creates one image view per image, acquires images and presents frames. Key methods: on:surface:extent:, acquireNextImage:fence:, present:queue:waitSemaphore:.

Creation asks the surface what it allows and what it offers rather than assuming either: imageCountFor: is how many images it requests, one more than the surface demands, held down to what it allows, with a maximum of zero read as no maximum; the format and colour space are the pair VkSurface class >> formatPreferredFrom: chose. createInfoForSurface:format:capabilities:extent: builds the declared VkSwapchainCreateInfoKHR from those answers, and handleForCreateInfo:on: is the only sender of vkCreateSwapchainKHR, so there is one place where a swapchain comes into being. imagesFromDriver enumerates the images the driver actually gave back, which may be more than were asked for, and the count the swapchain reports is that number.

Presentation is the mirror of that: presentInfoForSwapchain:imageIndex:waitSemaphore: builds the declared VkPresentInfoKHR together with the three runs of one entry it points at, and freePresentInfo: gives all four blocks back. What is left outside a declared structure are the blocks that are runs rather than structures — the out parameter a creation answers through, the index an acquire is given, the count and run of image handles, and those three present runs — each allocated by a named width.
"
Class {
	#name : 'VkSwapchain',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'images',
		'imageViews',
		'format',
		'extent',
		'imageCount'
	],
	#category : 'PharoVulkan-Graphics-Presentation',
	#package : 'PharoVulkan-Graphics',
	#tag : 'Presentation'
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
	"Delegates so the value has one home: whether a driver may discard obscured pixels is render
	 configuration."

	^ VkRenderConfig clipObscuredPixels
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

{ #category : 'constants' }
VkSwapchain class >> exampleImageIndex [
	"The first image of a swapchain, which is the one an acquire answers for the first frame.
	 An example and a test both need an index to present, and neither reaches a driver that
	 would hand one out."

	^ 0
]

{ #category : 'structures' }
VkSwapchain class >> freePresentInfo: aPresentInfo [
	"Gives back everything presentInfoForSwapchain:imageIndex:waitSemaphore: allocated: the
	 three runs first, because the request is where their addresses are kept, and then the
	 request itself."

	self freePresentRunsOf: aPresentInfo.
	aPresentInfo getHandle free
]

{ #category : 'structures' }
VkSwapchain class >> freePresentRunsOf: aPresentInfo [
	"Gives back the three runs the request points at and clears each field as it goes. The runs
	 were allocated for the request, so the request is the only record of where they are; a
	 field left holding a freed address would read as a run that is there. The results run is
	 never asked for, so there is nothing to free for that field."

	aPresentInfo pWaitSemaphores getHandle free.
	aPresentInfo pSwapchains getHandle free.
	aPresentInfo pImageIndices getHandle free.
	aPresentInfo
		pWaitSemaphores: ExternalAddress null;
		pSwapchains: ExternalAddress null;
		pImageIndices: ExternalAddress null
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

{ #category : 'private' }
VkSwapchain class >> imageCountFor: aCapabilities [
	"Delegates so the rule has one home: every value it reads is a field of the capabilities, so
	 the capabilities answer the count and this class asks."

	^ aCapabilities swapchainImageCount
]

{ #category : 'constants' }
VkSwapchain class >> imageHandleByteCount [
	"A swapchain image entry is one handle wide. The driver writes the run of image handles
	 into a plain block with no field specification to read a width from, so the stride is
	 named here."

	^ ExternalAddress wordSize
]

{ #category : 'constants' }
VkSwapchain class >> imageIndexByteCount [
	"An image index is a uint32, the same width as the counts Vk names. An index is not a
	 structure field, so there is no field specification to read the width from: both the
	 block an acquire writes the index into and the run a present reads it from are plain
	 blocks of this many bytes."

	^ Vk countByteCount
]

{ #category : 'constants' }
VkSwapchain class >> imagesBeyondMinimum [
	"Delegates so the value has one home: how many images beyond the minimum to ask for is render
	 configuration."

	^ VkRenderConfig swapchainImagesBeyondMinimum
]

{ #category : 'instance creation' }
VkSwapchain class >> on: aVkDevice surface: aVkSurface extent: aPoint [
    ^ self new initializeDevice: aVkDevice surface: aVkSurface extent: aPoint
]

{ #category : 'structures' }
VkSwapchain class >> presentInfoForSwapchain: aSwapchainHandle imageIndex: anImageIndex waitSemaphore: aSemaphoreHandle [
	"The request vkQueuePresentKHR reads: one swapchain, the index of the image in it that is
	 ready, and the semaphore that says when the rendering into that image finished. No run of
	 per-swapchain results is asked for, because a present of one swapchain learns everything
	 from the code the call itself answers. The request owns the three runs it points at, so
	 freePresentInfo: is what gives all four blocks back."

	| info |
	info := VkPresentInfoKHR externalInstance.
	^ info
		  waitSemaphoreCount: self semaphoresPerPresent;
		  pWaitSemaphores: (self runOfOneHandle: aSemaphoreHandle);
		  swapchainCount: self swapchainsPerPresent;
		  pSwapchains: (self runOfOneHandle: aSwapchainHandle);
		  pImageIndices: (self runOfOneImageIndex: anImageIndex);
		  yourself
]

{ #category : 'constants' }
VkSwapchain class >> presentModeNameFor: aValue [
	"Delegates so the lookup has one home: the names are the present-mode constants
	 VkRenderConfig holds, and it is the class that can answer which one carries a value."

	^ VkRenderConfig presentModeNameFor: aValue
]

{ #category : 'structures' }
VkSwapchain class >> runOfOneHandle: aHandle [
	"A Vulkan list of handles is a pointer to a run of them, and a present names lists of one.
	 A run is not a structure, so there is no field specification to read its width from: one
	 entry is one pointer wide. The request that points at the run owns it, and
	 freePresentInfo: gives it back."

	| run |
	run := ExternalAddress allocate: VkContext pointerSize.
	run pointerAt: 1 put: aHandle getHandle.
	^ run
]

{ #category : 'structures' }
VkSwapchain class >> runOfOneImageIndex: anImageIndex [
	"The present request points at one image index per swapchain, so the index travels as a
	 run of one rather than as a value. The request that points at the run owns it, and
	 freePresentInfo: gives it back."

	| run |
	run := ExternalAddress allocate: self imageIndexByteCount.
	run unsignedLongAt: 1 put: anImageIndex.
	^ run
]

{ #category : 'constants' }
VkSwapchain class >> semaphoresPerPresent [
	"One semaphore per present: the frame waits for its own rendering to finish and for
	 nothing else. The count is a caller's choice rather than a property of the request, so
	 it is named here and written by the builder."

	^ 1
]

{ #category : 'constants' }
VkSwapchain class >> swapchainsPerPresent [
	"One swapchain per present. A present call can carry several, one per window, which this
	 project never has: a scene draws into one surface."

	^ 1
]

{ #category : 'constants' }
VkSwapchain class >> unlimitedImageCount [
	"Delegates so the value has one home: the sentinel belongs to the structure that reports it."

	^ VkSurfaceCapabilitiesKHR unlimitedImageCount
]

{ #category : 'presenting' }
VkSwapchain >> acquireNextImage: semaphore fence: fence [
	"The unbounded acquire: it waits for an image for as long as the presentation engine takes.
	 That wait is inside a plain uFFI call, so it blocks the whole virtual machine, the user
	 interface included. A caller that drives frames should give a bound and send
	 acquireNextImage:fence:timeout: instead."

	^ self acquireNextImage: semaphore fence: fence timeout: Vk noTimeout
]

{ #category : 'presenting' }
VkSwapchain >> acquireNextImage: semaphore fence: fence timeout: nanoseconds [
	"Asks the presentation engine for the next image to draw into and answers its index. The
	 driver writes the index into a plain block, which is not a structure and so keeps its
	 named width, and the block goes back whatever the call answers. A suboptimal swapchain is
	 not a failure here, as it is not in a present; a timeout is, and it raises, because the
	 caller that gave a bound wants to hear about it rather than present a stale image."

	| indexBlock result |
	indexBlock := ExternalAddress allocate: self class imageIndexByteCount.
	^ [
	  result := Vk
		            acquireNextImageKHR: device handle
		            swapchain: handle
		            timeout: nanoseconds
		            semaphore: semaphore
		            fence: fence
		            pImageIndex: indexBlock.
	  Vk checkResult: result acceptable: self class acceptablePresentResults.
	  indexBlock unsignedLongAt: 1 ] ensure: [ indexBlock free ]
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
	"Hands one image of this swapchain to the presentation engine, once the rendering into it
	 has signalled the semaphore. The request and the three runs it points at go back together
	 whatever the driver answers, and a suboptimal swapchain is not a failure: there is no
	 recreation path here, so the honest response is to carry on with the frame."

	| info result |
	info := self class
		        presentInfoForSwapchain: handle
		        imageIndex: imageIndex
		        waitSemaphore: semaphore.
	[
	result := Vk queuePresentKHR: aVkQueue handle pPresentInfo: info getHandle.
	Vk checkResult: result acceptable: self class acceptablePresentResults ]
		ensure: [ self class freePresentInfo: info ]
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
