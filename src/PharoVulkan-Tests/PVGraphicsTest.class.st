"
SUnit test suite for the graphics path. Verifies shader SPIR-V construction (buildVertexShader, buildFragmentShader) and vertex data layout. Integration rendering is exercised via PVHelloTriangleScene.
"
Class {
	#name : 'PVGraphicsTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Graphics',
	#package : 'PharoVulkan-Tests',
	#tag : 'Graphics'
}

{ #category : 'private' }
PVGraphicsTest >> assertValidSpirv: bytes description: aDescription [
	"A magic-number check only proves the first four bytes. Ask spirv-val for the verdict
	 on the whole module, and skip rather than fail when the tool is not installed."
	| validator |
	self assert: bytes class equals: ByteArray.
	self deny: bytes isEmpty.
	PVSpirvValidator isAvailable ifFalse: [ self skip ].
	validator := PVSpirvValidator on: bytes.
	self
		assert: validator isValid
		description: aDescription , ' produced invalid SPIR-V: ' , validator validationOutput
]

{ #category : 'private' }
PVGraphicsTest >> offscreenTargetExtent: aPoint do: aBlock [
	"A colour attachment needs a device that can draw, which the compute context does not ask
	 for, so every target test builds the offscreen context by name. The block receives the
	 target, a queue and a command pool; everything is released afterwards even if it raises."

	| context queue pool target |
	context := VkContext offscreenGraphicsContext.
	[
	queue := context computeQueue.
	pool := context device createCommandPool: context computeQueueFamily.
	target := nil.
	[
	target := PVOffscreenTarget on: context device extent: aPoint.
	aBlock
		value: target
		value: queue
		value: pool ] ensure: [
		target ifNotNil: [ target destroy ].
		pool destroy ] ] ensure: [ context destroy ]
]

{ #category : 'tests' }
PVGraphicsTest >> testBothColorPassVariantsBuildOnTheDevice [
	"The window and offscreen render passes now share one body, so this states that both final
	 layouts are accepted by the driver. Without it, a mistake in the extraction would only show
	 when a window opens."

	| context window offscreen |
	context := VkContext offscreenGraphicsContext.
	[
	window := VkRenderPass
		          createColorPassDevice: context device
		          format: PVOffscreenTarget colorFormat.
	offscreen := VkRenderPass
		             createOffscreenColorPassDevice: context device
		             format: PVOffscreenTarget colorFormat.
	self deny: window handle getHandle isNull.
	self deny: offscreen handle getHandle isNull.
	window destroy.
	offscreen destroy ] ensure: [ context destroy ]
]

{ #category : 'tests - driver lifecycle' }
PVGraphicsTest >> testDriverInstallDuringKeepsUiManagerAndDoesNotPrompt [

	| original manager |
	original := OSWindowDriver driverClass.
	manager := UIManager default.
	PVVulkanDriver installDuring: [
		self assert: UIManager default identicalTo: manager ].
	self assert: UIManager default identicalTo: manager.
	self assert: OSWindowDriver driverClass equals: original
]

{ #category : 'tests - driver lifecycle' }
PVGraphicsTest >> testDriverInstallDuringRestoresDriver [

	| original inside |
	original := OSWindowDriver driverClass.
	inside := nil.
	PVVulkanDriver installDuring: [ inside := OSWindowDriver driverClass ].
	self assert: inside equals: PVVulkanDriver.
	self assert: OSWindowDriver driverClass equals: original
]

{ #category : 'tests - driver lifecycle' }
PVGraphicsTest >> testDriverInstallDuringRestoresDriverOnException [
	"The driver must be restored even when the block raises — this is the leak that
	 crashed the image twice: an aborted render loop left PVVulkanDriver installed.
	 entered must be set, otherwise a DNU on installDuring: would satisfy should:raise:."

	| original entered |
	original := OSWindowDriver driverClass.
	entered := false.
	self
		should: [
			PVVulkanDriver installDuring: [
				entered := true.
				Error signal: 'boom' ] ]
		raise: Error.
	self assert: entered.
	self assert: OSWindowDriver driverClass equals: original
]

{ #category : 'tests' }
PVGraphicsTest >> testFragmentShaderBuilds [
	self
		assertValidSpirv: PVHelloTriangleScene new buildFragmentShader
		description: 'PVHelloTriangleScene buildFragmentShader'
]

{ #category : 'tests' }
PVGraphicsTest >> testGlslSceneFragmentShaderBuilds [
	self
		assertValidSpirv: PVGlslTriangleScene new buildFragmentShader
		description: 'PVGlslTriangleScene buildFragmentShader'
]

{ #category : 'tests' }
PVGraphicsTest >> testGlslSceneVertexShaderBuilds [
	self
		assertValidSpirv: PVGlslTriangleScene new buildVertexShader
		description: 'PVGlslTriangleScene buildVertexShader'
]

{ #category : 'tests - lifecycle report' }
PVGraphicsTest >> testInspectorLifecycleViewReportsEverySlotWithoutMutating [

	| scene view |
	scene := PVHelloTriangleScene new.
	scene instVarNamed: 'ctx' put: PVRecordingContextStub new.
	view := scene inspectorLifecycle: SpPresenter new.
	self assert: view items size equals: PVHelloTriangleScene allInstVarNames size.
	self
		assert: (scene instVarNamed: 'ctx') notNil
		description: 'building the view must not touch the inspected scene'.
	self assert: (scene instVarNamed: 'ctx') waitIdleCount equals: 0
]

{ #category : 'tests - lifecycle report' }
PVGraphicsTest >> testLifecycleReportTracksReleasedSlots [

	| scene before after |
	scene := PVHelloTriangleScene new.
	before := scene lifecycleReport.
	self assert: before size equals: PVHelloTriangleScene allInstVarNames size.
	self
		assert: (before allSatisfy: [ :each |
				 each value = PVHelloTriangleScene releasedLabel ])
		description: 'a fresh scene owns nothing yet'.
	scene instVarNamed: 'ctx' put: PVRecordingContextStub new.
	after := scene lifecycleReport.
	self
		assert: (after detect: [ :each | each key = #ctx ]) value
		equals: PVHelloTriangleScene liveLabel
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTargetDefaultsToTheClearTheWindowPathUses [
	"A target told nothing must behave like the window path, which is the only thing that keeps
	 the extracted clear colour honest: the delegating three-keyword method is what the scene
	 still calls."

	self offscreenTargetExtent: 2 @ 2 do: [ :target :queue :pool |
		target renderWith: [ :c |  ] on: queue pool: pool.
		self
			assert: target clearColor
			equals: VkRenderConfig clearColorBlackOpaque.
		self assert: (target pixelAtX: 0 y: 0) equals: #( 0 0 0 255 ) ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTargetDestroyIsIdempotent [
	"The helper destroys the target as well, so a target that cannot be destroyed twice would
	 fail every other target test too; this one states the rule on its own."

	self offscreenTargetExtent: 4 @ 4 do: [ :target :queue :pool |
		target renderWith: [ :c |  ] on: queue pool: pool.
		target destroy.
		target destroy.
		self assert: target pixels size equals: 4 * 4 * PVOffscreenTarget bytesPerPixel ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTargetOfOnePixelReadsBack [
	"One pixel catches a row pitch assumed from the width and a copy region built from the
	 wrong extent: both read plausible bytes at 8 by 8 and nothing at all here."

	self offscreenTargetExtent: 1 @ 1 do: [ :target :queue :pool |
		target clearColor: #( 1.0 0.0 0.0 1.0 ).
		target renderWith: [ :c |  ] on: queue pool: pool.
		self assert: target pixels size equals: 4.
		self assert: (target pixelAtX: 0 y: 0) equals: #( 255 0 0 255 ) ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTargetPixelOutsideTheExtentIsRefused [
	"Reading one past the last column must raise, not answer the first pixel of the next row,
	 which is what the index arithmetic alone would do."

	self offscreenTargetExtent: 2 @ 2 do: [ :target :queue :pool |
		target renderWith: [ :c |  ] on: queue pool: pool.
		self should: [ target pixelAtX: 2 y: 0 ] raise: Error.
		self should: [ target pixelAtX: 0 y: 2 ] raise: Error.
		self should: [ target pixelAtX: -1 y: 0 ] raise: Error.
		self assert: (target pixelAtX: 1 y: 1) size equals: 4 ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTargetPixelRowsAgreeWithTheReadbackAndChangeNothing [
	"What the Pixels tab shows must be what the readback holds: every sampled coordinate lies
	 inside the extent, its swatch carries the channels the bytes carry, and looking changes
	 neither the bytes nor the clear colour. The swatch goes through a Form, so a channel is
	 allowed one step of rounding."

	self offscreenTargetExtent: 4 @ 4 do: [ :target :queue :pool |
		| before clear |
		clear := #( 0.25 0.5 0.75 1.0 ).
		target clearColor: clear.
		target renderWith: [ :c |  ] on: queue pool: pool.
		before := target pixels copy.
		self deny: target pixelProbeCoordinates isEmpty.
		target pixelProbeCoordinates do: [ :point |
			| pixel colour |
			self assert: (point x between: 0 and: target extent x - 1).
			self assert: (point y between: 0 and: target extent y - 1).
			pixel := target pixelAtX: point x y: point y.
			colour := (target swatchFor: pixel) colorAt: 0 @ 0.
			{
				(colour red -> (pixel at: 1)).
				(colour green -> (pixel at: 2)).
				(colour blue -> (pixel at: 3)) } do: [ :pair |
				self assert: ((pair key * 255) rounded - pair value) abs <= 1 ] ].
		self assert: target pixels equals: before.
		self assert: target clearColor equals: clear ]
]

{ #category : 'tests - driver lifecycle' }
PVGraphicsTest >> testPrepareReleasesSceneWhenInitialisationFails [

	| raised |
	PVFailingTriangleSceneStub resetDestroyCount.
	raised := false.
	[ PVFailingTriangleSceneStub prepare: nil backendWindow: nil ]
		on: Error
		do: [ :e | raised := true ].
	self assert: raised.
	self assert: PVFailingTriangleSceneStub destroyCount equals: 1
]

{ #category : 'tests' }
PVGraphicsTest >> testRenderPassClearsToTheColourItWasGiven [
	"The clear colour the render pass is given must reach the pixels, which is what makes a
	 readback proof that the GPU wrote them. Unorm rounding is driver-defined, so each channel
	 may sit one step either side of (value * 255) rounded."

	| clear expected |
	clear := #( 0.25 0.5 0.75 1.0 ).
	expected := clear collect: [ :each | (each * 255) rounded ].
	self offscreenTargetExtent: 8 @ 8 do: [ :target :queue :pool |
		target clearColor: clear.
		target renderWith: [ :c |  ] on: queue pool: pool.
		{
			(0 @ 0).
			(7 @ 0).
			(0 @ 7).
			(7 @ 7).
			(3 @ 4) } do: [ :point |
			| pixel |
			pixel := target pixelAtX: point x y: point y.
			1 to: 4 do: [ :i |
			self assert: ((pixel at: i) - (expected at: i)) abs <= 1 ] ] ]
]

{ #category : 'tests - driver lifecycle' }
PVGraphicsTest >> testSceneDestroyIsIdempotent [
	"destroy runs from an ensure: block, so it may be reached twice, or on a scene
	 that never got prepared. Neither may raise."

	| scene |
	scene := PVHelloTriangleScene new.
	scene destroy.
	scene destroy.
	self assert: (scene instVarNamed: 'surface') isNil.
	self assert: (scene instVarNamed: 'swapchain') isNil
]

{ #category : 'tests - driver lifecycle' }
PVGraphicsTest >> testSceneDestroyWaitsForGpu [
	"destroy must wait for the GPU itself. Relying on the caller to send
	 waitIdle first means an aborted render loop destroys fences, semaphores
	 and a pipeline that the GPU is still reading."

	| scene stub |
	scene := PVHelloTriangleScene new.
	stub := PVRecordingContextStub new.
	scene instVarNamed: 'ctx' put: stub.
	scene destroy.
	self assert: stub waitIdleCount equals: 1
]

{ #category : 'tests' }
PVGraphicsTest >> testVertexDataSize [

	| data |
	data := PVHelloTriangleScene new buildVertexData.
	self assert: data size equals: 60
]

{ #category : 'tests' }
PVGraphicsTest >> testVertexShaderBuilds [
	self
		assertValidSpirv: PVHelloTriangleScene new buildVertexShader
		description: 'PVHelloTriangleScene buildVertexShader'
]
