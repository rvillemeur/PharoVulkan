"
Examples of the window path: what a surface might report of itself, the format and colour space pair this project renders in, the swapchain request built from those capabilities, the present request for one swapchain, and the suboptimal result a driver answers when a swapchain still works but no longer fits its surface.

No example here touches a display. The capabilities and the format are the values a real driver would report, built in object memory so that the request example can be read on a machine with no window at all, and the surface handle the request carries points nowhere.
"
Class {
	#name : 'VkSwapchainExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkSwapchainExamples class >> capabilitiesAWindowSurfaceMightReport [
	<sampleInstance>
	"One click: a plausible report for a window surface, built in object memory so a click
	 frees nothing. The driver is the only writer of this structure, so there is nothing to
	 call here and the fields are filled through the generated accessors: a surface needs a
	 display, and an example must run on a machine that has none. Every value is a constant
	 some other class already names, so this cannot drift from what the project asks a real
	 surface for."

	| capabilities |
	capabilities := VkSurfaceCapabilitiesKHR new.
	capabilities
		minImageCount: VkSurfaceCapabilitiesKHR exampleMinImageCount;
		maxImageCount: VkSwapchain unlimitedImageCount;
		maxImageArrayLayers: VkImage arrayLayerCount;
		supportedTransforms: VkSurfaceTransform identityBit;
		currentTransform: VkSurfaceTransform identityBit;
		supportedCompositeAlpha: VkCompositeAlpha opaqueBit;
		supportedUsageFlags: VkImageUsage colorAttachmentBit.
	{ capabilities currentExtent. capabilities minImageExtent.
	  capabilities maxImageExtent } do: [ :each |
		each width: VkImage exampleExtent x; height: VkImage exampleExtent y ].
	^ capabilities
]

{ #category : 'examples' }
VkSwapchainExamples class >> formatAWindowSurfaceMightReport [
	<sampleInstance>
	"One click: the format and colour space pair this project renders in, which is the one
	 every surface it has met offers. Built in object memory, so a click frees nothing, and
	 filled through the generated accessors: the driver is the only writer of this
	 structure."

	| surfaceFormat |
	surfaceFormat := VkSurfaceFormatKHR new.
	surfaceFormat
		format: VkSurface formatRenderedIn;
		colorSpace: VkColorSpace srgbNonlinearKHR.
	^ surfaceFormat
]

{ #category : 'examples' }
VkSwapchainExamples class >> presentRequestForOneSwapchain [
	<sampleInstance>
	"One click: the request this project makes to present one image, built by its one writer.
	 No device is touched. The three runs are given back before the copy is kept, which clears
	 the fields that pointed at them, so the example holds no address that has been freed; the
	 counts stay at what the writer wrote, and the Present tab then says the runs are not
	 there."

	| info |
	info := VkSwapchain
		        presentInfoForSwapchain: ExternalAddress null
		        imageIndex: VkSwapchain exampleImageIndex
		        waitSemaphore: ExternalAddress null.
	^ [
	  VkSwapchain freePresentRunsOf: info.
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'examples' }
VkSwapchainExamples class >> requestForAWindowSurface [
	<sampleInstance>
	"One click: the request this project makes of a window surface that reports the example
	 capabilities and offers the example format. Built by the one builder the creation path
	 uses, so the example cannot drift from what a real creation asks for, and answered as a
	 copy in object memory so a click frees nothing. The surface handle is null, because a
	 surface needs a display and an example must run on a machine that has none."

	| info |
	info := VkSwapchain
		        createInfoForSurface: VkSwapchainCreateInfoKHR exampleSurfaceHandle
		        format: self formatAWindowSurfaceMightReport
		        capabilities:
		        self capabilitiesAWindowSurfaceMightReport
		        extent: VkImage exampleExtent.
	^ [ info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'examples' }
VkSwapchainExamples class >> suboptimalPresentResult [
	"The code a present answers after the window has been resized: not a failure, which is the
	 distinction the Result codes inspector tab makes visible."

	<sampleInstance>
	^ VkResult withCode: VkResult vkSuboptimalKHR
]
