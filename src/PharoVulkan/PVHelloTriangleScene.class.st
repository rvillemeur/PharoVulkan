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

{ #category : 'constants' }
PVHelloTriangleScene class >> exampleExtent [
	^ 800 @ 600
]

{ #category : 'constants' }
PVHelloTriangleScene class >> exampleFrameCount [
	^ 300
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
			                width: ext x
			                height: ext y ].
	imageAvailable := VkSemaphoreWrapper createDevice: ctx device.
	renderFinished := VkSemaphoreWrapper createDevice: ctx device.
	inFlightFence := VkFenceWrapper createSignaledDevice: ctx device
]

{ #category : 'rendering' }
PVHelloTriangleScene >> renderFrame [
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
		waitSemaphore: renderFinished handle
]

{ #category : 'see class side' }
PVHelloTriangleScene >> seeClassSide [
]

{ #category : 'accessing' }
PVHelloTriangleScene >> swapchain [ ^ swapchain
]
