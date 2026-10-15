"
Renders a coloured triangle using Vulkan graphics. Owns the full graphics resource chain: surface, swapchain, render pass, framebuffers, graphics pipeline, vertex buffer, semaphores, and fence. Key methods: prepare:backendWindow:, renderFrame, destroy.
"
Class {
	#name : 'PVHelloTriangleScene',
	#superclass : 'PVTriangleScene',
	#instVars : [
		'surface',
		'swapchain',
		'framebuffers',
		'imageAvailable',
		'renderFinished',
		'inFlightFence'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'reporting' }
PVHelloTriangleScene class >> attachmentSeparator [

	^ ', '
]

{ #category : 'testing' }
PVHelloTriangleScene class >> displayAvailable [
	^ self displayAvailableIn: Smalltalk os environment
]

{ #category : 'testing' }
PVHelloTriangleScene class >> displayAvailableIn: anEnvironment [
	"A variable that is present but empty is what a stripped environment leaves behind, and
	 SDL2 cannot connect to it, so emptiness counts as absence."

	^ self displayEnvironmentVariableNames anySatisfy: [ :variableName |
		  (anEnvironment at: variableName ifAbsent: [ '' ]) isEmptyOrNil not ]
]

{ #category : 'testing' }
PVHelloTriangleScene class >> displayEnvironmentVariableNames [
	"The variables a display server sets. SDL2 needs one of them to open a window at all, so
	 they decide whether the window path can be exercised here."

	^ #( 'WAYLAND_DISPLAY' 'DISPLAY' )
]

{ #category : 'testing' }
PVHelloTriangleScene class >> displayUnavailableReason [
	^ self displayUnavailableReasonIn: Smalltalk os environment
]

{ #category : 'testing' }
PVHelloTriangleScene class >> displayUnavailableReasonIn: anEnvironment [
	"Answer nil when a window can be opened, and otherwise a sentence naming the variables
	 that were looked at, so a skipped test reports what the skip cost instead of staying
	 silent."

	(self displayAvailableIn: anEnvironment) ifTrue: [ ^ nil ].
	^ 'no display server: none of '
	  ,
	  (', ' join: self displayEnvironmentVariableNames)
	  , ' is set, so the window path cannot be exercised here'
]

{ #category : 'constants' }
PVHelloTriangleScene class >> exampleExtent [
	^ 800 @ 600
]

{ #category : 'constants' }
PVHelloTriangleScene class >> exampleFrameCount [
	^ 300
]

{ #category : 'reporting' }
PVHelloTriangleScene class >> framebufferLabel [

	^ 'framebuffer'
]

{ #category : 'reporting' }
PVHelloTriangleScene class >> imageRowPrefix [
	"Prefix of the per image rows of swapchainReport, so a reader of the report can pick the
	 image rows out of the swapchain's own rows without matching a bare string."

	^ 'image '
]

{ #category : 'reporting' }
PVHelloTriangleScene class >> missingLabelFor: aLabel [
	"How swapchainReport says that one of the per image objects was never built. A view and a
	 framebuffer are built in separate steps, so the report has to be able to deny either one."

	^ 'no ' , aLabel
]

{ #category : 'instance creation' }
PVHelloTriangleScene class >> prepare: aVkContext backendWindow: aBackendWindow [
	"Answer a prepared scene, or nothing at all. A raise part-way through
	 initialisation would otherwise strand the Vulkan objects already created on an
	 instance no caller ever receives, so there would be no way left to destroy them.
	 destroy tolerates nil slots, so it is safe on a half-initialised scene."

	| scene |
	scene := self new.
	[ scene initializeCtx: aVkContext backendWindow: aBackendWindow ]
		ifCurtailed: [ scene destroy ].
	^ scene
]

{ #category : 'examples' }
PVHelloTriangleScene class >> renderTriangle [
	"Open a window, render exampleFrameCount frames, then tear everything down.
	 Every acquired resource is released by an ensure: block, in reverse order of
	 creation: scene, then context, then window, then the OSWindow driver. A raise
	 or a user interrupt mid-loop must not leave a live VkInstance, an SDL window
	 still registered with the driver, or the driver itself swapped out — with the
	 validation layers off, that state resurfaces as a segfault on the next run."

	<sampleInstance>
	| attrs |
	attrs := PVWindowAttributes newVulkan.
	attrs
		title: self windowTitle;
		extent: self exampleExtent;
		windowCentered: true.
	^ PVVulkanDriver installDuring: [
		  | win |
		  win := OSWindow createWithAttributes: attrs.
		  [ | backendWin ctx |
		  backendWin := win backendWindow.
		  ctx := VkContext graphicsContextForExtensions:
			         backendWin requiredInstanceExtensions.
		  [ | scene |
		  scene := self prepare: ctx backendWindow: backendWin.
		  [ 1 to: self exampleFrameCount do: [ :i | scene renderFrame ] ]
			  ensure: [ scene destroy ].
		  scene ] ensure: [ ctx destroy ] ] ensure: [ win destroy ] ]
]

{ #category : 'reporting' }
PVHelloTriangleScene class >> viewLabel [

	^ 'view'
]

{ #category : 'constants' }
PVHelloTriangleScene class >> windowTitle [
	^ 'Hello Triangle'
]

{ #category : 'releasing' }
PVHelloTriangleScene >> destroyPresentation [
	"The presentation objects, in reverse creation order: fence, semaphores, framebuffers,
	 swapchain, surface. A framebuffer is destroyed before the image views it references, which
	 is the safe direction."

	inFlightFence ifNotNil: [
		inFlightFence destroy.
		inFlightFence := nil ].
	renderFinished ifNotNil: [
		renderFinished destroy.
		renderFinished := nil ].
	imageAvailable ifNotNil: [
		imageAvailable destroy.
		imageAvailable := nil ].
	framebuffers ifNotNil: [
		framebuffers do: [ :fb | fb destroy ].
		framebuffers := nil ].
	swapchain ifNotNil: [
		swapchain destroy.
		swapchain := nil ].
	surface ifNotNil: [
		surface destroy.
		surface := nil ]
]

{ #category : 'reporting' }
PVHelloTriangleScene >> imageAttachmentDescriptionAt: anIndex [
	"Whether the one-based swapchain image at anIndex has a view and a framebuffer. The two are
	 built in separate steps, so an image can have the first and not the second, and the report
	 has to be able to say so."

	| parts |
	parts := { 
		          (swapchain imageViews at: anIndex ifAbsent: [ nil ]) -> self class viewLabel.
		          ((framebuffers ifNil: [ #(  ) ]) at: anIndex ifAbsent: [ nil ])
		          -> self class framebufferLabel }.
	^ self class attachmentSeparator
		  join: (parts collect: [ :each |
				   each key
					   ifNil: [ self class missingLabelFor: each value ]
					   ifNotNil: [ each value ] ])
]

{ #category : 'initialization' }
PVHelloTriangleScene >> initializeCtx: aVkContext backendWindow: aBackendWindow [
	"Builds what only a window needs — surface, swapchain, framebuffers over the swapchain
	 views, and the frame synchronisation — and leaves the drawing objects to the superclass."

	| ext |
	ctx := aVkContext.
	surface := VkSurface
		           fromWindow: aBackendWindow
		           instance: ctx instance
		           physicalDevice: ctx physicalDevice.
	ext := aBackendWindow vulkanDrawableExtent.
	swapchain := VkSwapchain on: ctx device surface: surface extent: ext.
	self
		initializeCtx: ctx
		renderPass: (VkRenderPass
				 createColorPassDevice: ctx device
				 format: swapchain format)
		extent: ext.
	framebuffers := swapchain imageViews collect: [ :view |
		                VkFramebuffer
			                on: ctx device
			                renderPass: renderPass
			                imageView: view
			                extent: ext ].
	imageAvailable := VkSemaphoreWrapper createDevice: ctx device.
	renderFinished := VkSemaphoreWrapper createDevice: ctx device.
	inFlightFence := VkFenceWrapper createSignaledDevice: ctx device
]

{ #category : 'inspector' }
PVHelloTriangleScene >> inspectorSwapchain: aBuilder [
	"What the window path actually got from the driver: image count, extent, surface format by
	 name, present mode by name, then one row per swapchain image with its view and framebuffer.
	 Reads swapchainReport, so the view cannot drift from the slots the scene holds, and it
	 mutates nothing it shows."

	<inspectorPresentationOrder: 20 title: 'Swapchain'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Property'
				   evaluated: [ :each | each key ]);
		  addColumn: (SpStringTableColumn
				   title: 'Value'
				   evaluated: [ :each | each value ]);
		  items: self swapchainReport;
		  yourself
]

{ #category : 'rendering' }
PVHelloTriangleScene >> renderFrame [
	"Answer the swapchain index this frame was drawn into, so a caller can see the cycle
	 advance. Additive: renderTriangle ignores the answer."

	| imageIndex ext |
	inFlightFence waitTimeout: 16rFFFFFFFFFFFFFFFF.
	inFlightFence reset.
	imageIndex := swapchain
		              acquireNextImage: imageAvailable handle
		              fence: ExternalAddress null.
	ext := swapchain extent.
	commandPool reset.
	commandBuffer do: [ :c |
			c
				beginRenderPass: renderPass
				framebuffer: (framebuffers at: imageIndex + 1)
				extent: ext.
			c bindGraphicsPipeline: pipeline.
			c setViewport: ext.
			c setScissor: ext.
			c bindVertexBuffer: vertexBuffer.
			c draw: 3 ].
	ctx computeQueue
		submitGraphics: commandBuffer
		waitSemaphore: imageAvailable
		signalSemaphore: renderFinished
		fence: inFlightFence.
	swapchain
		present: imageIndex
		queue: ctx computeQueue
		waitSemaphore: renderFinished handle.
	^ imageIndex
]

{ #category : 'see class side' }
PVHelloTriangleScene >> seeClassSide [
]

{ #category : 'accessing' }
PVHelloTriangleScene >> swapchain [ ^ swapchain
]

{ #category : 'reporting' }
PVHelloTriangleScene >> swapchainFormatName [
	"The surface format by name. Falls back to the number, because the driver may answer a
	 format this binding's enumeration does not cover and a report must not fail on that."

	^ (VkFormat nameForValue: swapchain format) ifNil: [ swapchain format printString ]
]

{ #category : 'reporting' }
PVHelloTriangleScene >> swapchainReport [
	"Name and value pairs for what the driver gave us for this window: the swapchain's own
	 numbers first, then one row per swapchain image saying whether a view and a framebuffer
	 exist for it. Everything is read out of the live slots and out of the swapchain itself, so
	 a torn-down scene reports released rather than claiming a swapchain it no longer holds."

	| rows |
	swapchain ifNil: [ ^ { 'swapchain' -> self class releasedLabel } ].
	rows := OrderedCollection new
		        add: 'images' -> swapchain imageCount printString;
		        add: 'extent' -> swapchain extent printString;
		        add: 'format' -> self swapchainFormatName;
		        add: 'present mode' -> swapchain presentModeName;
		        yourself.
	1 to: swapchain imageCount do: [ :index |
		rows add: self class imageRowPrefix , (index - 1) printString
				-> (self imageAttachmentDescriptionAt: index) ].
	^ rows asArray
]
