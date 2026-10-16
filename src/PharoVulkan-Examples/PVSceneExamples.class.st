"
Examples of the offscreen graphics path run end to end on this machine: the cleared render target, and the triangle rendered into one.

Each builds a context, renders, reads the pixels back and destroys everything it created before answering, so what it hands back is the result rather than live driver objects. They need a Vulkan driver but no window. The scene classes keep renderTriangle themselves, because doc/glsl-api-tutorial.md documents it as the method a user writes on their own scene.
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
