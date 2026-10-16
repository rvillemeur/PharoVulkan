"
The request vkCreateSwapchainKHR reads: which surface to present to, how many images to hold, in which format and colour space, at which extent, for which usage, with which transform, composite alpha and present mode. One hundred and four bytes, with the extent carried by value as a VkExtent2D.

Only VkSwapchain class >> createInfoForSurface:format:capabilities:extent: fills it, from what the surface itself reported, and only VkSwapchain class >> handleForCreateInfo:on: passes it to the driver. The flags, the exclusive sharing mode, both queue family fields and the old swapchain are the zeros a fresh block already holds, so none of them is written; initializeConstantFields sets the structure type alone, because that is the one field constant for every request of this kind. swapchainRows is what the Swapchain tab reads, naming each value through the class that owns it rather than keeping a second copy, and reporting the surface and the old swapchain as set or not because their addresses say nothing to a reader.
"
Class {
	#name : 'VkSwapchainCreateInfoKHR',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_CLIPPED',
		'OFFSET_COMPOSITEALPHA',
		'OFFSET_FLAGS',
		'OFFSET_IMAGEARRAYLAYERS',
		'OFFSET_IMAGECOLORSPACE',
		'OFFSET_IMAGEEXTENT',
		'OFFSET_IMAGEFORMAT',
		'OFFSET_IMAGESHARINGMODE',
		'OFFSET_IMAGEUSAGE',
		'OFFSET_MINIMAGECOUNT',
		'OFFSET_OLDSWAPCHAIN',
		'OFFSET_PNEXT',
		'OFFSET_PQUEUEFAMILYINDICES',
		'OFFSET_PRESENTMODE',
		'OFFSET_PRETRANSFORM',
		'OFFSET_QUEUEFAMILYINDEXCOUNT',
		'OFFSET_STYPE',
		'OFFSET_SURFACE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'constants' }
VkSwapchainCreateInfoKHR class >> exampleSurfaceHandle [
	"A surface handle that points nowhere. An example must run on a machine with no display,
	 so there is no surface to ask for a real one; the request only carries the handle on to
	 the driver, which an example never reaches."

	^ VkSurfaceKHR_H fromHandle: ExternalAddress null
]

{ #category : 'field definition' }
VkSwapchainCreateInfoKHR class >> fieldsDesc [
	"The surface and the swapchain this one replaces are handles, so each is declared as one
	 and is pointer wide. The extent is a VkExtent2D carried by value. clipped is a VkBool32,
	 declared as the uint32 it is. The queue family indices are a run of numbers rather than
	 a structure, so they are pointed at; no swapchain here shares its images, so the
	 pointer stays null."

	^ #( int32 sType; void* pNext; uint32 flags; VkSurfaceKHR_H* surface;
	     uint32 minImageCount; int32 imageFormat; int32 imageColorSpace;
	     VkExtent2D imageExtent; uint32 imageArrayLayers; uint32 imageUsage;
	     int32 imageSharingMode; uint32 queueFamilyIndexCount;
	     void* pQueueFamilyIndices; uint32 preTransform; uint32 compositeAlpha;
	     int32 presentMode; uint32 clipped; VkSwapchainKHR_H* oldSwapchain )
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> clipped [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_CLIPPED
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> clipped: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_CLIPPED put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> compositeAlpha [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_COMPOSITEALPHA
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> compositeAlpha: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_COMPOSITEALPHA put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageArrayLayers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_IMAGEARRAYLAYERS
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageArrayLayers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_IMAGEARRAYLAYERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageColorSpace [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_IMAGECOLORSPACE
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageColorSpace: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_IMAGECOLORSPACE put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageExtent [
	"This method was automatically generated"
	^ VkExtent2D fromHandle: (handle referenceStructAt: OFFSET_IMAGEEXTENT length: VkExtent2D byteSize)
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageExtent: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_IMAGEEXTENT put: anObject getHandle length: VkExtent2D byteSize
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageFormat [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_IMAGEFORMAT
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageFormat: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_IMAGEFORMAT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageSharingMode [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_IMAGESHARINGMODE
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageSharingMode: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_IMAGESHARINGMODE put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageUsage [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_IMAGEUSAGE
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> imageUsage: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_IMAGEUSAGE put: anObject
]

{ #category : 'initialization' }
VkSwapchainCreateInfoKHR >> initializeConstantFields [
	"The structure type is the only field fixed by the type. Every swapchain here is created
	 with one layer, the opaque composite alpha and the first in first out present mode, but
	 each of those is a caller's choice rather than a property of the structure, and a request
	 naming no surface must not claim an image."

	self sType: VkStructureType swapchainCreateInfoKHR
]

{ #category : 'inspector' }
VkSwapchainCreateInfoKHR >> inspectorSwapchain: aBuilder [
	"What the driver is asked for, rather than where the fields sit: the Layout and Fields
	 tabs answer that. The rows come from swapchainRows, which only reads, so opening the tab
	 changes nothing."

	<inspectorPresentationOrder: 30 title: 'Swapchain'>
	| rows |
	rows := self swapchainRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Asks for' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Surface given'. (rows at: #surfaceSet) }.
				  { 'Images'. (rows at: #minImageCount) }.
				  { 'Format'. (rows at: #formatName) }.
				  { 'Colour space'. (rows at: #colorSpaceName) }.
				  { 'Extent'. (rows at: #extent) }.
				  { 'Array layers'. (rows at: #imageArrayLayers) }.
				  { 'Image usage'. (rows at: #usageNames) }.
				  { 'Shared between queue families'.
				  (rows at: #sharedBetweenQueueFamilies) }.
				  { 'Transform'. (rows at: #preTransformNames) }.
				  { 'Composite alpha'. (rows at: #compositeAlphaNames) }.
				  { 'Present mode'. (rows at: #presentModeName) }.
				  { 'Discards obscured pixels'. (rows at: #discardsObscuredPixels) }.
				  { 'Replaces a swapchain'. (rows at: #replacesASwapchain) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> minImageCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MINIMAGECOUNT
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> minImageCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MINIMAGECOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> oldSwapchain [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_OLDSWAPCHAIN) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> oldSwapchain: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_OLDSWAPCHAIN put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> pQueueFamilyIndices [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PQUEUEFAMILYINDICES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> pQueueFamilyIndices: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PQUEUEFAMILYINDICES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> preTransform [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_PRETRANSFORM
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> preTransform: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_PRETRANSFORM put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> presentMode [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_PRESENTMODE
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> presentMode: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_PRESENTMODE put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> queueFamilyIndexCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEXCOUNT
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> queueFamilyIndexCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEXCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> surface [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_SURFACE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSwapchainCreateInfoKHR >> surface: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_SURFACE put: anObject getHandle.
]

{ #category : 'reporting' }
VkSwapchainCreateInfoKHR >> swapchainRows [
	"What the driver is asked for: how many images, in which format and colour space, at which
	 extent, for which usage, with which transform, composite alpha and present mode. Each
	 value is named through the class that owns it — the present mode through VkSwapchain,
	 which is also what the created swapchain reports — so the report cannot name something
	 the request stopped carrying. The surface and the old swapchain are reported as set or
	 not, because their addresses say nothing to a reader. Read only, so a view built from
	 this leaves the store alone."

	^ Dictionary new
		  at: #surfaceSet put: self surface isNull not;
		  at: #minImageCount put: self minImageCount;
		  at: #formatName
		  put: ((VkFormat nameForValue: self imageFormat)
				   ifNil: [ self imageFormat printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #colorSpaceName
		  put: ((VkColorSpace nameForValue: self imageColorSpace)
				   ifNil: [ self imageColorSpace printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #extent put: self imageExtent width @ self imageExtent height;
		  at: #imageArrayLayers put: self imageArrayLayers;
		  at: #usageNames put: (VkImageUsage nameForFlags: self imageUsage);
		  at: #sharedBetweenQueueFamilies
		  put: self imageSharingMode ~= VkRenderConfig sharingModeExclusive;
		  at: #preTransformNames
		  put: (VkSurfaceTransform nameForFlags: self preTransform);
		  at: #compositeAlphaNames
		  put: (VkCompositeAlpha nameForFlags: self compositeAlpha);
		  at: #presentModeName
		  put: (VkSwapchain presentModeNameFor: self presentMode);
		  at: #discardsObscuredPixels
		  put: self clipped = VkSwapchain clipObscuredPixels;
		  at: #replacesASwapchain put: self oldSwapchain isNull not;
		  yourself
]
