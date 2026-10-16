"
What vkGetPhysicalDeviceSurfaceCapabilitiesKHR reports for a surface: how many images it allows a swapchain to hold, the smallest, largest and current extents it accepts, the transforms and composite alpha modes it supports, and the ways its images may be used. Fifty-two bytes, with three VkExtent2D carried by value.

The driver is the only writer, so this structure carries no chain header and declares no initializeConstantFields; VkSurface >> capabilities allocates the block, hands it over and answers a copy in object memory the caller can keep. surfaceRows is what the Surface tab reads, and its image count row asks VkSwapchain what it would request for these capabilities rather than restating that rule. The example fills the fields through the generated accessors, because an example must run on a machine with no display and so with no surface to ask.
"
Class {
	#name : 'VkSurfaceCapabilitiesKHR',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_CURRENTEXTENT',
		'OFFSET_CURRENTTRANSFORM',
		'OFFSET_MAXIMAGEARRAYLAYERS',
		'OFFSET_MAXIMAGECOUNT',
		'OFFSET_MAXIMAGEEXTENT',
		'OFFSET_MINIMAGECOUNT',
		'OFFSET_MINIMAGEEXTENT',
		'OFFSET_SUPPORTEDCOMPOSITEALPHA',
		'OFFSET_SUPPORTEDTRANSFORMS',
		'OFFSET_SUPPORTEDUSAGEFLAGS'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkSurfaceCapabilitiesKHR class >> fieldsDesc [
	"The capabilities the driver reports for a surface. The three extents are VkExtent2D
	 carried by value. supportedTransforms and supportedCompositeAlpha are masks;
	 currentTransform is a single bit of the same set."

	^ #( uint32 minImageCount; uint32 maxImageCount; VkExtent2D currentExtent;
	     VkExtent2D minImageExtent; VkExtent2D maxImageExtent;
	     uint32 maxImageArrayLayers; uint32 supportedTransforms;
	     uint32 currentTransform; uint32 supportedCompositeAlpha;
	     uint32 supportedUsageFlags )
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> currentExtent [
	"This method was automatically generated"
	^ VkExtent2D fromHandle: (handle referenceStructAt: OFFSET_CURRENTEXTENT length: VkExtent2D byteSize)
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> currentExtent: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_CURRENTEXTENT put: anObject getHandle length: VkExtent2D byteSize
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> currentTransform [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_CURRENTTRANSFORM
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> currentTransform: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_CURRENTTRANSFORM put: anObject
]

{ #category : 'inspector' }
VkSurfaceCapabilitiesKHR >> inspectorSurface: aBuilder [
	"What the surface allows, rather than where the fields sit: the Layout and Fields tabs
	 answer that. The rows come from surfaceRows, which only reads, so opening the tab changes
	 nothing, and the image count row is the one VkSwapchain would ask this surface for."

	<inspectorPresentationOrder: 30 title: 'Surface'>
	| rows |
	rows := self surfaceRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Allows' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Images at least'. (rows at: #minImageCount) }.
				  { 'Images at most'. (rows at: #maxImageCount) }.
				  { 'Image maximum unlimited'. (rows at: #maxImageCountIsUnlimited) }.
				  { 'Images a swapchain would ask for'. (rows at: #swapchainImageCount) }.
				  { 'Current extent'. (rows at: #currentExtent) }.
				  { 'Smallest extent'. (rows at: #minImageExtent) }.
				  { 'Largest extent'. (rows at: #maxImageExtent) }.
				  { 'Array layers at most'. (rows at: #maxImageArrayLayers) }.
				  { 'Current transform'. (rows at: #currentTransformName) }.
				  { 'Transforms supported'. (rows at: #supportedTransformNames) }.
				  { 'Composite alpha supported'.
				  (rows at: #supportedCompositeAlphaNames) }.
				  { 'Image usage supported'. (rows at: #supportedUsageNames) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> maxImageArrayLayers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXIMAGEARRAYLAYERS
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> maxImageArrayLayers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXIMAGEARRAYLAYERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> maxImageCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXIMAGECOUNT
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> maxImageCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXIMAGECOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> maxImageExtent [
	"This method was automatically generated"
	^ VkExtent2D fromHandle: (handle referenceStructAt: OFFSET_MAXIMAGEEXTENT length: VkExtent2D byteSize)
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> maxImageExtent: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_MAXIMAGEEXTENT put: anObject getHandle length: VkExtent2D byteSize
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> minImageCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MINIMAGECOUNT
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> minImageCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MINIMAGECOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> minImageExtent [
	"This method was automatically generated"
	^ VkExtent2D fromHandle: (handle referenceStructAt: OFFSET_MINIMAGEEXTENT length: VkExtent2D byteSize)
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> minImageExtent: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_MINIMAGEEXTENT put: anObject getHandle length: VkExtent2D byteSize
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> supportedCompositeAlpha [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUPPORTEDCOMPOSITEALPHA
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> supportedCompositeAlpha: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUPPORTEDCOMPOSITEALPHA put: anObject
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> supportedTransforms [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUPPORTEDTRANSFORMS
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> supportedTransforms: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUPPORTEDTRANSFORMS put: anObject
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> supportedUsageFlags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUPPORTEDUSAGEFLAGS
]

{ #category : 'accessing - structure variables' }
VkSurfaceCapabilitiesKHR >> supportedUsageFlags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUPPORTEDUSAGEFLAGS put: anObject
]

{ #category : 'reporting' }
VkSurfaceCapabilitiesKHR >> surfaceRows [
	"What this surface allows, in Vulkan's own terms: the image counts, the three extents as
	 points, the transform and composite alpha masks decoded through their constant classes,
	 and the ways its images may be used. The image count row asks VkSwapchain what it would
	 request for these capabilities rather than restating the rule, so the report cannot
	 disagree with what creation does. A maximum of zero is no maximum, which is reported as
	 such because a reader shown nothing but the zero would read it as no images allowed.
	 Read only, so a view built from this leaves the store alone."

	^ Dictionary new
		  at: #minImageCount put: self minImageCount;
		  at: #maxImageCount put: self maxImageCount;
		  at: #maxImageCountIsUnlimited
		  put: self maxImageCount = VkSwapchain unlimitedImageCount;
		  at: #swapchainImageCount put: (VkSwapchain imageCountFor: self);
		  at: #currentExtent put: self currentExtent width @ self currentExtent height;
		  at: #minImageExtent
		  put: self minImageExtent width @ self minImageExtent height;
		  at: #maxImageExtent
		  put: self maxImageExtent width @ self maxImageExtent height;
		  at: #maxImageArrayLayers put: self maxImageArrayLayers;
		  at: #supportedTransformNames
		  put: (VkSurfaceTransform nameForFlags: self supportedTransforms);
		  at: #currentTransformName
		  put: (VkSurfaceTransform nameForFlags: self currentTransform);
		  at: #supportedCompositeAlphaNames
		  put: (VkCompositeAlpha nameForFlags: self supportedCompositeAlpha);
		  at: #supportedUsageNames
		  put: (VkImageUsage nameForFlags: self supportedUsageFlags);
		  yourself
]
