"
Examples of the offscreen graphics path run end to end on this machine: the cleared render target, and the triangle rendered into one.

Each builds a context, renders, reads the pixels back and destroys everything it created before answering, so what it hands back is the result rather than live driver objects. They need a Vulkan driver but no window. The scene classes keep renderTriangle themselves, because doc/glsl-api-tutorial.md documents it as the method a user writes on their own scene.

The four examples named open... do open a window and drive the GPU: openRenderTriangle and openGlslRenderTriangle, one per scene class, and openWindowSurface and openWindowSwapchain, which hand back one object of the chain the window run built. All four go through PVHelloTriangleScene class >> renderTriangleWith:, so no example holds a second copy of the lifecycle, and all four answer their object after the teardown. Run those four alone, against a committed checkout.
"
Class {
	#name : 'PVSceneExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Graphics',
	#package : 'PharoVulkan-Examples',
	#tag : 'Graphics'
}

{ #category : 'examples' }
PVSceneExamples class >> clearedTargetOnThisMachine [
	"One click: a 32 by 32 target cleared on whatever device this machine offers, with its
	 Vulkan objects released before it is handed back. The readback bytes stay in the instance,
	 so the Pixels tab still shows the colour the GPU wrote."

	<sampleInstance>
	| context queue pool target |
	context := VkContext offscreenGraphicsContext.
	^ [
	  queue := context computeQueue.
	  pool := context device createCommandPool: context computeQueueFamily.
	  [
	  target := PVOffscreenTarget on: context device extent: PVOffscreenTarget exampleExtent.
	  target clearColor: PVOffscreenTarget exampleClearColor.
	  target renderWith: [ :c |  ] on: queue pool: pool.
	  target destroy.
	  target ] ensure: [ pool destroy ] ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVSceneExamples class >> openGlslRenderTriangle [
	"One click: the same triangle with both shaders compiled from Pharo source by
	 PVKernelCompiler instead of the hand-written SPIR-V. Inherits the lifecycle from
	 PVHelloTriangleScene. It opens a window and drives the GPU, so run it alone."

	<sampleInstance>
	^ PVGlslTriangleScene renderTriangle
]

{ #category : 'examples' }
PVSceneExamples class >> openRenderTriangle [
	"One click: the hand-written SPIR-V triangle in a window of its own. The scene class keeps
	 renderTriangle because doc/glsl-api-tutorial.md documents it as the method a user writes
	 on their own scene, so this example sends it rather than holding a second copy of the
	 lifecycle. It opens a window and drives the GPU, so run it alone."

	<sampleInstance>
	^ PVHelloTriangleScene renderTriangle
]

{ #category : 'examples' }
PVSceneExamples class >> openWindowSurface [
	"One click: the presentation surface of a real window, handed back once the window run has
	 released it. destroy nils the handle, so the Surface tab then shows the destroyed state and
	 the format this project renders in and asks the driver nothing — which is the state a reader
	 of this object is in after any window run. The rows that query the driver need a live
	 surface, and PVGraphicsTest reads them inside the run. It opens a window and drives the GPU,
	 so run it alone."

	<sampleInstance>
	^ PVHelloTriangleScene renderTriangleWith: [ :scene | scene surface ]
]

{ #category : 'examples' }
PVSceneExamples class >> openWindowSwapchain [
	"One click: the swapchain of a real window, handed back once the window run has released it.
	 destroy keeps the format, the extent and the image count the driver gave and drops the
	 handle and the image views, so the Swapchain tab shows what this machine presented in and
	 the destroyed state. It opens a window and drives the GPU, so run it alone."

	<sampleInstance>
	^ PVHelloTriangleScene renderTriangleWith: [ :scene | scene swapchain ]
]

{ #category : 'examples' }
PVSceneExamples class >> renderedTriangleOnThisMachine [
	"One click: the hello triangle drawn once on whatever device this machine offers, with
	 every Vulkan object released before the scene is handed back. The pixels the GPU wrote
	 stay in the instance, so the Expected versus measured tab works on the result."

	<sampleInstance>
	| context scene |
	context := VkContext offscreenGraphicsContext.
	^ [
	  scene := PVOffscreenTriangleScene on: context extent: PVOffscreenTriangleScene exampleExtent.
	  scene renderOnce.
	  scene destroy.
	  scene ] ensure: [ context destroy ]
]
