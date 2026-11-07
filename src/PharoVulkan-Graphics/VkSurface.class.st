"
Vulkan presentation surface. Creates a VkSurfaceKHR via SDL_Vulkan_CreateSurface and answers what the driver reports for it. Key methods: fromWindow:instance:physicalDevice:, supportsPresentation:, capabilities, formats, preferredFormat. Both structures the driver fills are declared — VkSurfaceCapabilitiesKHR and VkSurfaceFormatKHR — so the answers are read through generated accessors and come back as copies in object memory; the blocks the driver wrote are freed here. formatPreferredFrom: is the choice of format and colour space the swapchain is created with, kept on the class side so it can be tested without a display.

presentationRows is what the Surface tab reads. Its first rows hold for any surface; the rows that query the driver are built only while the handle is live, because destroy nils it and a query through a nil handle is a segmentation fault rather than an error.
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
	"Delegates so the value has one home: the format this project renders in is render
	 configuration, read by the surface choice above and by the format report below."

	^ VkRenderConfig formatRenderedIn
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

{ #category : 'inspector' }
VkSurface >> inspectorSurface: aBuilder [
	"What this surface is and what the driver reports for it. The rows come from
	 presentationRows, which only reads: opening a surface creates no Vulkan object and frees
	 every block it allocates to ask."

	<inspectorPresentationOrder: 10 title: 'Surface'>
	^ PVFactRow
		  tableOf: self presentationRows
		  nameColumn: 'Surface'
		  valueColumn: 'Value'
		  in: aBuilder
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

{ #category : 'reporting' }
VkSurface >> presentationRows [
	"What a reader can ask of this surface. The state comes first, because every row under it
	 needs a live handle: the driver is asked nothing through a nil one, so a destroyed surface
	 shows the state and the preference and stops there. The pairs the driver offers are fetched
	 once and the preferred one is picked from them by this class's own rule, and the limits come
	 from the capabilities' own rows, so neither the choice nor the image count is restated here."

	| rows offered chosen capabilities |
	rows := OrderedCollection new
		        add: (PVFactRow name: 'surface' value: self stateLabel);
		        add: (PVFactRow
				         name: 'format this project renders in'
				         value: (VkFormat nameForValue: self class formatRenderedIn));
		        yourself.
	handle ifNil: [ ^ rows asArray ].
	offered := self formats.
	chosen := self class formatPreferredFrom: offered.
	rows add: (PVFactRow name: 'formats offered' value: offered size).
	chosen ifNotNil: [
		| pair |
		pair := chosen formatRows.
		rows
			add: (PVFactRow name: 'preferred format' value: (pair at: #formatName));
			add: (PVFactRow
					 name: 'preferred colour space'
					 value: (pair at: #colorSpaceName)) ].
	capabilities := self capabilities surfaceRows.
	rows
		add: (PVFactRow
				 name: 'current extent'
				 value: (capabilities at: #currentExtent));
		add: (PVFactRow
				 name: 'images the swapchain asks for'
				 value: (capabilities at: #swapchainImageCount)).
	^ rows asArray
]

{ #category : 'as yet unclassified' }
VkSurface >> stateLabel [
	"Whether the driver can still be asked about this surface. Every row of the report below
	 the state needs a live handle, and destroy leaves nil behind, so this is what decides
	 which of them can be built."

	^ handle
		  ifNil: [ PVFactRow destroyedLabel ]
		  ifNotNil: [ PVFactRow liveLabel ]
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
