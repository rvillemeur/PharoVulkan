"
Vulkan presentation surface. Creates a VkSurfaceKHR via SDL_Vulkan_CreateSurface and answers what the driver reports for it. Key methods: fromWindow:instance:physicalDevice:, supportsPresentation:, capabilities, formats, preferredFormat. Both structures the driver fills are declared — VkSurfaceCapabilitiesKHR and VkSurfaceFormatKHR — so the answers are read through generated accessors and come back as copies in object memory; the blocks the driver wrote are freed here. formatPreferredFrom: is the choice of format and colour space the swapchain is created with, kept on the class side so it can be tested without a display.
"
Class {
	#name : 'VkSurface',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'instance',
		'physicalDevice'
	],
	#category : 'PharoVulkan-Graphics-Presentation',
	#package : 'PharoVulkan-Graphics',
	#tag : 'Presentation'
}

{ #category : 'querying' }
VkSurface class >> formatPreferredFrom: surfaceFormats [
	"The format this project renders in when the surface offers it, wherever it sits in the
	 run, and otherwise the first format offered: a surface always offers at least one, and
	 presenting in another format is better than refusing to present. Answers nil for an
	 empty run, which has nothing to choose."

	^ surfaceFormats
		  detect: [ :each | each format = self formatRenderedIn ]
		  ifNone: [ surfaceFormats ifEmpty: [ nil ] ifNotEmpty: [ :all | all first ] ]
]

{ #category : 'constants' }
VkSurface class >> formatRenderedIn [
	"The format the render pass, the shaders and the readback of this project are all written
	 for. It is taken whenever a surface offers it so that a presented frame and an offscreen
	 frame are the same bytes in the same order."

	^ VkFormat b8g8r8a8Unorm
]

{ #category : 'instance creation' }
VkSurface class >> fromWindow: aVulkanBackendWindow instance: aVkInstance physicalDevice: aVkPhysicalDevice [
    | s |
    s := self new.
    s initializeWithWindow: aVulkanBackendWindow instance: aVkInstance physicalDevice: aVkPhysicalDevice.
    ^ s
]

{ #category : 'querying' }
VkSurface >> capabilities [
	"What the driver reports for this surface: the image counts it allows, the extents it
	 accepts, the transforms and composite alpha modes it supports and the ways its images may
	 be used. The block the driver writes lives outside the image and is freed here, so the
	 answer is a copy in object memory the caller can keep."

	| capabilities result |
	capabilities := VkSurfaceCapabilitiesKHR externalInstance.
	^ [
	  result := Vk
		            getPhysicalDeviceSurfaceCapabilitiesKHR: physicalDevice handle
		            surface: handle
		            pSurfaceCapabilities: capabilities getHandle.
	  Vk checkResult: result.
	  capabilities copyIntoObjectMemory ] ensure: [ capabilities getHandle free ]
]

{ #category : 'lifecycle' }
VkSurface >> destroy [

	handle ifNotNil: [
			Vk
				destroySurfaceKHR: instance
				surface: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'querying' }
VkSurface >> formatCountInto: aCountBuffer [
	"How many format and colour space pairs this surface accepts, asked for with a null run,
	 which is how Vulkan reports the room a run needs. The count stays in the buffer because
	 the call that fills the run needs it there as well."

	| result |
	result := Vk
		          getPhysicalDeviceSurfaceFormatsKHR: physicalDevice handle
		          surface: handle
		          pSurfaceFormatCount: aCountBuffer
		          pSurfaceFormats: ExternalAddress null.
	Vk checkResult: result.
	^ aCountBuffer unsignedLongAt: 1
]

{ #category : 'querying' }
VkSurface >> formats [
	"The count buffer is written twice by the driver and read twice here, once to size the run
	 and once by the call that fills it, so it is allocated around both calls and freed
	 whichever way they go."

	| countBuffer |
	countBuffer := ExternalAddress allocate: Vk countByteCount.
	^ [ self formatsCountedBy: countBuffer ] ensure: [ countBuffer free ]
]

{ #category : 'querying' }
VkSurface >> formatsCountedBy: aCountBuffer [
	"Every format and colour space pair this surface accepts. The run the driver fills lives
	 outside the image, because the garbage collector may move a store between the pointer
	 being handed over and the driver writing through it, and it is freed here: the answer is
	 copies in object memory. The first element's handle is the address of the whole run."

	| run |
	run := VkSurfaceFormatKHR externalArrayOf:
		       (self formatCountInto: aCountBuffer).
	run isEmpty ifTrue: [ ^ #(  ) ].
	^ [
	  | result |
	  result := Vk
		            getPhysicalDeviceSurfaceFormatsKHR: physicalDevice handle
		            surface: handle
		            pSurfaceFormatCount: aCountBuffer
		            pSurfaceFormats: run first getHandle.
	  Vk checkResult: result.
	  run collect: [ :each | each copyIntoObjectMemory ] ] ensure: [
		  run first getHandle free ]
]

{ #category : 'accessing' }
VkSurface >> handle [
    ^ handle
]

{ #category : 'initialize-release' }
VkSurface >> initializeWithWindow: aWindow instance: aVkInstance physicalDevice: aVkPhysDev [
    instance := aVkInstance.
    physicalDevice := aVkPhysDev.
    handle := aWindow createVulkanSurface: aVkInstance
]

{ #category : 'accessing' }
VkSurface >> physicalDevice [
    ^ physicalDevice
]

{ #category : 'querying' }
VkSurface >> preferredFormat [
	"The pair the swapchain is created with: the format this project renders in when this
	 surface offers it, the first one offered otherwise."

	^ self class formatPreferredFrom: self formats
]

{ #category : 'querying' }
VkSurface >> supportsPresentation: queueFamilyIndex [
    | pSupported result |
    pSupported := ExternalAddress allocate: 4.
    [
        result := Vk getPhysicalDeviceSurfaceSupportKHR: physicalDevice handle
            queueFamilyIndex: queueFamilyIndex
            surface: handle
            pSupported: pSupported.
        Vk checkResult: result.
        ^ (pSupported unsignedLongAt: 1) = 1
    ] ensure: [ pSupported free ]
]
