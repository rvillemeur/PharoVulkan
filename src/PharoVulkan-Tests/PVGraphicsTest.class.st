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

{ #category : 'coverage' }
PVGraphicsTest class >> addNew: someClasses to: aSet frontier: aQueue [
	"Add each class the set does not hold yet, and queue only those, so the walk visits every
	 class once however many methods name it."

	someClasses do: [ :each |
		(aSet includes: each) ifFalse: [
			aSet add: each.
			aQueue add: each ] ]
]

{ #category : 'coverage' }
PVGraphicsTest class >> deviceGatewaySelectors [
	"Every test that touches a real device gets there by building a VkContext, and these are the
	 four factories that build one. A test that sends none of them cannot have reached the
	 hardware, so this is the honest definition of a device-touching test method."

	^ #( #offscreenGraphicsContext #graphicsContextForExtensions:
	     #computeContextRequiring: #cooperativeMatrixContext )
]

{ #category : 'coverage' }
PVGraphicsTest class >> deviceReachableClasses [
	"The project classes a device test can reach: start at the classes the device test methods
	 name, then follow the classes those name, until nothing new arrives. The walk never leaves
	 the project package, so the answer stays a statement about this code rather than about the
	 image."

	| reached frontier |
	reached := Set new.
	frontier := OrderedCollection new.
	self deviceTestMethods do: [ :method |
		self
			addNew: (self projectClassesReferencedBy: method)
			to: reached
			frontier: frontier ].
	[ frontier isEmpty ] whileFalse: [
		self
			addNew: (self projectClassesNamedBy: frontier removeFirst)
			to: reached
			frontier: frontier ].
	^ reached
]

{ #category : 'coverage' }
PVGraphicsTest class >> deviceTestMethods [
	"Every method of the test package that builds a device context, test and helper alike. The
	 helpers count: a test reaches the device through windowSceneDo: and its siblings."

	^ ((PackageOrganizer default packageNamed: self testPackageName)
		   definedClasses gather: [ :each | each methods , each class methods ])
		  select: [ :method |
			  self deviceGatewaySelectors anySatisfy: [ :selector |
				  method messages includes: selector ] ]
]

{ #category : 'constants' }
PVGraphicsTest class >> fenceWaitNanoseconds [
	"Two seconds, long enough for any batch this suite submits and short enough that a batch
	 the driver never runs fails the test instead of hanging the image."

	^ 2000000000
]

{ #category : 'coverage' }
PVGraphicsTest class >> graphicsClassNamesWithoutDeviceCoverage [
	"Graphics classes that no device test can reach, each paired with the reason. The list is
	 empty today, and an entry is a decision a reader can argue with rather than an omission
	 nobody notices. A name here that a device test does reach is a stale exemption, which the
	 coverage test also refuses."

	^ {  }
]

{ #category : 'coverage' }
PVGraphicsTest class >> graphicsClasses [
	"The classes tagged Graphics. A class answers its own tag with packageTag name, because
	 RPackageOrganizer is gone in Pharo 13 and Package does not answer its tags."

	^ self projectClasses select: [ :each |
		  each packageTag name = self graphicsTagName ]
]

{ #category : 'coverage' }
PVGraphicsTest class >> graphicsTagName [

	^ 'Graphics'
]

{ #category : 'coverage' }
PVGraphicsTest class >> projectClasses [

	^ (PackageOrganizer default packageNamed: self projectPackageName)
		  definedClasses asSet
]

{ #category : 'coverage' }
PVGraphicsTest class >> projectClassesNamedBy: aClass [
	"The project classes aClass leads to: the ones its methods name, plus its superclass, which
	 nothing has to name for the subclass to depend on it."

	| named |
	named := OrderedCollection new.
	(self projectClasses includes: aClass superclass) ifTrue: [
		named add: aClass superclass ].
	(aClass methods , aClass class methods) do: [ :method |
		named addAll: (self projectClassesReferencedBy: method) ].
	^ named
]

{ #category : 'coverage' }
PVGraphicsTest class >> projectClassesReferencedBy: aCompiledMethod [
	"The project classes named in aCompiledMethod, read from its syntax tree rather than from
	 its literals, because a class named only inside a nested block does not appear among the
	 literals of the enclosing method."

	| classes |
	classes := aCompiledMethod ast allChildren
		           select: [ :node |
		           node isVariable and: [ node isGlobalVariable ] ]
		           thenCollect: [ :node |
		           Smalltalk at: node name ifAbsent: [ nil ] ].
	^ classes
		  select: [ :each |
			  each notNil and: [
				  each isBehavior and: [
					  self projectClasses includes: each instanceSide ] ] ]
		  thenCollect: [ :each | each instanceSide ]
]

{ #category : 'coverage' }
PVGraphicsTest class >> projectPackageName [

	^ #PharoVulkan
]

{ #category : 'coverage' }
PVGraphicsTest class >> testPackageName [

	^ #'PharoVulkan-Tests'
]

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

{ #category : 'running' }
PVGraphicsTest >> renderedOffscreenTriangleDo: aBlock [
	"Draws the hello triangle once into an offscreen target of the example extent and passes
	 the scene to the block. The extent is square, which most of the pixel tests want: their
	 measured coordinates were taken on it."

	self
		renderedOffscreenTriangleOfExtent: PVOffscreenTriangleScene exampleExtent
		do: aBlock
]

{ #category : 'running' }
PVGraphicsTest >> renderedOffscreenTriangleOfExtent: aPoint do: aBlock [
	"Draws the hello triangle once into an offscreen target of the given extent and passes the
	 scene to the block, which can then probe pixels. Drawing needs a device that can do
	 graphics, which the plain compute context does not ask for. The scene and the context are
	 released afterwards even if the block raises."

	| context scene |
	context := VkContext offscreenGraphicsContext.
	[
	scene := nil.
	[
	scene := PVOffscreenTriangleScene on: context extent: aPoint.
	scene renderOnce.
	aBlock value: scene ] ensure: [ scene ifNotNil: [ scene destroy ] ] ]
		ensure: [ context destroy ]
]

{ #category : 'running' }
PVGraphicsTest >> renderedOffscreenTrianglePairDo: aBlock [
	"Renders the same triangle twice at the same extent, once with the hand-built SPIR-V and
	 once with the shaders the DSL compiles, and passes both scenes to the block. One context
	 and one extent serve both, so the two renders can differ only in their shaders."

	| context handBuilt fromDsl extent |
	context := VkContext offscreenGraphicsContext.
	extent := PVOffscreenTriangleScene exampleExtent.
	[
	handBuilt := nil.
	fromDsl := nil.
	[
	handBuilt := PVOffscreenTriangleScene on: context extent: extent.
	handBuilt renderOnce.
	fromDsl := PVGlslOffscreenTriangleScene on: context extent: extent.
	fromDsl renderOnce.
	aBlock value: handBuilt value: fromDsl ] ensure: [
		fromDsl ifNotNil: [ fromDsl destroy ].
		handBuilt ifNotNil: [ handBuilt destroy ] ] ] ensure: [ context destroy ]
]

{ #category : 'running' }
PVGraphicsTest >> submitSignalling: aCommandBuffer semaphore: aSemaphore on: aQueue [
	"Submits one command buffer that signals a semaphore and waits for nothing, which no
	 product path needs: the window path's wait semaphore is signalled by acquiring a
	 swapchain image. The test needs a signalled semaphore to wait on, so it builds the batch
	 from the same builders the product paths use and hands it to the same recorder."

	| bufferInfo signalInfo batch |
	bufferInfo := VkQueue commandBufferSubmitInfoFor:
		              aCommandBuffer handle getHandle.
	[
	signalInfo := VkQueue semaphoreSubmitInfoFor: aSemaphore handle getHandle.
	[
	batch := VkQueue
		         submitInfoFor: bufferInfo getHandle
		         waitSemaphoreInfo: nil
		         signalSemaphoreInfo: signalInfo.
	[ aQueue submitBatch: batch fence: ExternalAddress null ] ensure: [
		batch getHandle free ] ] ensure: [ signalInfo getHandle free ] ]
		ensure: [ bufferInfo getHandle free ]
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

{ #category : 'tests - render pass' }
PVGraphicsTest >> testBothPassVariantsAreBuiltFromTheSameBuildersOnThisMachine [
	"The window variant and the offscreen variant differ in one field, the layout the
	 attachment leaves the pass in, and are otherwise built from the same four builders. The
	 window variant is never reached headlessly, because a swapchain needs a surface, yet the
	 driver accepts it on any device that can draw: presentSrcKHR is a layout, not a surface.
	 Creating both here is the shape that would break if a builder kept state between calls
	 or freed a structure before the driver had read it, and it is the only place the window
	 variant is exercised at all on this machine."

	| context passes |
	context := VkContext offscreenGraphicsContext.
	[
		passes := {
			          (VkRenderPass
				           createColorPassDevice: context device
				           format: PVOffscreenTarget colorFormat).
			          (VkRenderPass
				           createOffscreenColorPassDevice: context device
				           format: PVOffscreenTarget colorFormat).
			          (VkRenderPass
				           createOffscreenColorPassDevice: context device
				           format: PVOffscreenTarget colorFormat) }.
		[
			passes do: [ :each | self deny: each handle getHandle isNull ].
			self
				assert: (passes collect: [ :each | each handle getHandle asInteger ])
						asSet size
				equals: passes size ] ensure: [ passes do: [ :each | each destroy ] ] ]
		ensure: [ context destroy ]
]

{ #category : 'tests' }
PVGraphicsTest >> testDisplayAvailabilityAndItsReasonAgreeOnThisMachine [
	"Whatever this machine offers, exactly one of the two answers holds: a display and no
	 reason, or no display and a reason. The window tests rely on that, because they skip on
	 the predicate and report the reason."

	PVHelloTriangleScene displayAvailable
		ifTrue: [ self assert: PVHelloTriangleScene displayUnavailableReason isNil ]
		ifFalse: [
		self deny: PVHelloTriangleScene displayUnavailableReason isNil ]
]

{ #category : 'tests' }
PVGraphicsTest >> testDisplayAvailabilityFollowsTheDisplayEnvironment [
	"The window tests are skipped where no display exists, so the predicate that decides it is
	 worth stating as a rule rather than trusting on one machine. It is asked of a dictionary
	 so the degenerate cases can be put to it: no variable at all, and a variable that is set
	 but empty, which is what a stripped environment leaves behind."

	self deny: (PVHelloTriangleScene displayAvailableIn: Dictionary new).
	self assert: (PVHelloTriangleScene displayAvailableIn:
			 (Dictionary with: 'DISPLAY' -> ':0')).
	self assert: (PVHelloTriangleScene displayAvailableIn:
			 (Dictionary with: 'WAYLAND_DISPLAY' -> 'wayland-0')).
	self deny: (PVHelloTriangleScene displayAvailableIn:
			 (Dictionary with: 'DISPLAY' -> ''))
]

{ #category : 'tests' }
PVGraphicsTest >> testDisplayUnavailableReasonNamesWhatIsMissing [
	"A skipped test that says nothing is a test that silently stops covering the window path,
	 so the reason names the two variables that were looked at. Where a display does exist
	 there is nothing to report, and the reason is nil."

	| reason |
	reason := PVHelloTriangleScene displayUnavailableReasonIn: Dictionary new.
	self assert: (reason includesSubstring: 'DISPLAY').
	self assert: (reason includesSubstring: 'WAYLAND_DISPLAY').
	self
		assert: (PVHelloTriangleScene displayUnavailableReasonIn:
				 (Dictionary with: 'DISPLAY' -> ':0'))
		equals: nil
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

{ #category : 'tests - coverage' }
PVGraphicsTest >> testEveryGraphicsClassIsExercisedOnADeviceOrSaysWhyNot [
	"The gap this plan closed was silent: a graphics class could be added, and nothing but a
	 human running the triangle would notice that no test ever put it on a device. Every class
	 tagged Graphics must therefore be reachable from a test that builds a device context, or be
	 named with its reason in graphicsClassNamesWithoutDeviceCoverage.

	 Reachability is static: it says a device test leads to the class through project code, not
	 that every one of its methods ran. That is the fact this test can state honestly, and it is
	 enough to make a new graphics class with no device path fail here."

	| reachable exempt uncovered |
	reachable := self class deviceReachableClasses.
	exempt := (self class graphicsClassNamesWithoutDeviceCoverage collect: [
			           :each | each key ]) asSet.
	uncovered := (self class graphicsClasses
		              reject: [ :each | reachable includes: each ])
		             collect: [ :each | each name ].
	self
		assertCollection: (uncovered reject: [ :each | exempt includes: each ])
		hasSameElements: #(  ).
	self
		assertCollection: (exempt reject: [ :each | uncovered includes: each ])
		hasSameElements: #(  )
]

{ #category : 'tests' }
PVGraphicsTest >> testFragmentShaderBuilds [
	self
		assertValidSpirv: PVHelloTriangleScene new buildFragmentShader
		description: 'PVHelloTriangleScene buildFragmentShader'
]

{ #category : 'tests' }
PVGraphicsTest >> testGlslSceneColoursTheTriangleWithItsOwnWhiteMix [
	"Inside the triangle the two renders do not agree, and must not: the DSL fragment shader
	 mixes white into the interpolated colour, so every channel sits half way between the
	 hand-built value and full brightness. Measured on 11 October 2026 at the centroid of a 32
	 by 32 render: 76, 92, 88 by hand against 165, 173, 171 from the DSL. Asserting the
	 relation rather than equality is what makes this a test of the DSL's arithmetic instead of
	 a test that two shaders happen to be identical."

	self renderedOffscreenTrianglePairDo: [ :handBuilt :fromDsl |
		handBuilt coveredPixelCoordinates do: [ :coordinate |
			| expected measured |
			expected := handBuilt pixelAt: coordinate.
			measured := fromDsl pixelAt: coordinate.
			1 to: 3 do: [ :channel |
				self assert: (PVGlslOffscreenTriangleScene
						 channel: (measured at: channel)
						 matchesMixOf: (expected at: channel)) ] ] ]
]

{ #category : 'tests' }
PVGraphicsTest >> testGlslSceneCoversTheSamePixelsAsTheHandBuiltShaders [
	"The DSL's vertex shader computes the clip position the same way the hand-built one does,
	 so the two renders must cover exactly the same pixels. This is the geometric half of the
	 comparison, and it is what turns the DSL claim from emitting SPIR-V the validator accepts
	 into rasterising the same triangle."

	self renderedOffscreenTrianglePairDo: [ :handBuilt :fromDsl |
		self
			assert: fromDsl coveredPixelCoordinates
			equals: handBuilt coveredPixelCoordinates ]
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

{ #category : 'tests' }
PVGraphicsTest >> testGlslWhiteMixFactorIsTheOneItsShaderSourceUses [
	"The pixel comparison needs the factor the DSL fragment shader mixes white with, and a
	 constant restating it would make the comparison lie the moment the shader source changed.
	 This test ties the constant to the literal in the method the shader is compiled from."

	self assert: ((PVKernelExamples >> #glslTriFragment:) literals includes:
			 PVGlslTriangleShaders whiteMixFactor)
]

{ #category : 'tests' }
PVGraphicsTest >> testGraphicsSubmitBatchCarriesSemaphoresAndAFenceOnThisMachine [
	"The driver leg of the submit unit: two real batches on a graphics queue, the first
	 signalling a semaphore and the second waiting on it, signalling a second semaphore and
	 taking a fence. The window path's batch is the one with semaphores on both sides, and no
	 test could reach it before, because acquiring a swapchain image is what signals its wait
	 semaphore; a batch that signals first lets the same structures be submitted headlessly.
	 The driver reads all three structures as it validates the batch, so a count beside the
	 wrong pointer, a stage mask at the wrong offset or a semaphore handle in the wrong word
	 fails here. Waiting on the fence is the proof the second batch ran at all."

	| context pool waitSemaphore signalSemaphore fence |
	context := VkContext offscreenGraphicsContext.
	[
	pool := context device createCommandPool: context computeQueueFamily.
	[
	waitSemaphore := VkSemaphoreWrapper createDevice: context device.
	signalSemaphore := VkSemaphoreWrapper createDevice: context device.
	fence := VkFenceWrapper createDevice: context device.
	[
	| first second |
	first := pool allocateBuffer.
	second := pool allocateBuffer.
	first begin.
	first end.
	second begin.
	second end.
	self
		submitSignalling: first
		semaphore: waitSemaphore
		on: context computeQueue.
	context computeQueue
		submitGraphics: second
		waitSemaphore: waitSemaphore
		signalSemaphore: signalSemaphore
		fence: fence.
	fence waitTimeout: self class fenceWaitNanoseconds.
	context computeQueue waitIdle.
	self assert: (fence fenceRows at: #live) ] ensure: [
		fence destroy.
		signalSemaphore destroy.
		waitSemaphore destroy ] ] ensure: [ pool destroy ] ] ensure: [
		context destroy ]
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

{ #category : 'tests' }
PVGraphicsTest >> testInterruptedFrameStrandsNothing [
	"The 9 October crash: a raise in the middle of the render loop skipped the teardown, left a
	 live VkInstance and an SDL window registered with a swapped-out driver, and the next run
	 segfaulted. Only the stub covers that today. Here the raise happens against a real window:
	 afterwards the OSWindow driver must be the one that was installed before, and every owned
	 slot of the scene must be released."

	| driverBefore scene raised |
	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	driverBefore := OSWindowDriver driverClass.
	raised := false.
	scene := nil.
	[
	self windowSceneDo: [ :each :backendWindow |
		scene := each.
		each renderFrame.
		Error signal: 'interrupted mid-loop' ] ]
		on: Error
		do: [ :error | raised := error messageText = 'interrupted mid-loop' ].
	self assert: raised.
	self assert: OSWindowDriver driverClass equals: driverBefore.
	scene lifecycleReport do: [ :slot |
		(PVHelloTriangleScene unownedSlotNames includes: slot key) ifFalse: [
			self
				assert: slot value
				equals: PVHelloTriangleScene releasedLabel ] ]
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
PVGraphicsTest >> testOffscreenTargetClearColourReachesEveryChannelSeparately [
	"The driver leg of the declared begin info and its clear values: four channels given four
	 different values must come back in that order. A clear value written at the wrong stride,
	 or a channel written to its neighbour's word, reads back plausibly when the colour is black
	 or a single channel and wrongly here. The swatch is not involved, so only the driver's own
	 rounding of a float to a byte is allowed."

	self offscreenTargetExtent: 2 @ 2 do: [ :target :queue :pool |
		| pixel |
		target clearColor: #( 0.0 0.25 0.5 1.0 ).
		target renderWith: [ :c |  ] on: queue pool: pool.
		pixel := target pixelAtX: 1 y: 1.
		#( 0 64 128 255 ) withIndexDo: [ :expected :channel |
			self assert: ((pixel at: channel) - expected) abs <= 1 ] ]
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
PVGraphicsTest >> testOffscreenTargetOfANonSquareExtentReadsBackEveryPixel [
	"The driver leg of the declared copy region: a three by two target reads back six pixels and
	 every one of them carries the clear colour. A width and a height swapped in the region —
	 the one layout mistake a square target cannot show — leaves the last column unwritten or
	 fails the copy outright."

	self offscreenTargetExtent: 3 @ 2 do: [ :target :queue :pool |
		target clearColor: #( 0.0 1.0 0.0 1.0 ).
		target renderWith: [ :c |  ] on: queue pool: pool.
		self
			assert: target pixels size
			equals: 3 * 2 * PVOffscreenTarget bytesPerPixel.
		0 to: 1 do: [ :y |
			0 to: 2 do: [ :x |
				self
					assert: (target pixelAtX: x y: y)
					equals: #( 0 255 0 255 ) ] ] ]
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

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleCentroidMixesAllThreeVertexColours [
	"The barycentric coordinates of the centroid are a third each, so the interpolated colour
	 there carries all three vertex colours and none of them dominates. Measured on 11 October
	 2026: pixel 16@18 of a 32 by 32 render reads 76, 92, 88. A centroid showing one pure
	 colour means the fragment shader dropped the interpolated input."

	self renderedOffscreenTriangleDo: [ :scene |
		self assert: (PVOffscreenTriangleScene isEvenlyMixed: scene centroidPixel) ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleCoversTheCentroid [
	"The centroid of the three vertices is inside the triangle by definition, so the pixel
	 there must not be the clear colour. This is the assertion that fails when nothing is
	 drawn at all, which is the failure a human eye catches first and no other test caught."

	self renderedOffscreenTriangleDo: [ :scene |
		self deny: (PVOffscreenTriangleScene isCleared: scene centroidPixel) ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleIsBlueNearItsBlueVertex [
	"Vertex 3 carries blue and is the apex, at the top of the picture because its y is
	 negative. Measured on 11 October 2026: pixel 16@10 of a 32 by 32 render reads 12, 28,
	 215. Together with the red and green tests this fixes the whole orientation of the
	 picture, which until now only a human looking at the window could confirm."

	self renderedOffscreenTriangleDo: [ :scene |
		self
			assert: (PVOffscreenTriangleScene dominantChannelOfColour:
					 (scene vertexColourAt: 3))
			equals: #blue.
		self assert: (scene dominantChannelNearVertex: 3) equals: #blue ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleIsGreenNearItsGreenVertex [
	"Vertex 2 carries green and sits at the bottom right of the triangle. Measured on 11
	 October 2026: pixel 22@22 of a 32 by 32 render reads 12, 219, 24. Swapping two vertex
	 positions, or flipping the y axis, moves green somewhere else and this test fails."

	self renderedOffscreenTriangleDo: [ :scene |
		self
			assert: (PVOffscreenTriangleScene dominantChannelOfColour:
					 (scene vertexColourAt: 2))
			equals: #green.
		self assert: (scene dominantChannelNearVertex: 2) equals: #green ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleIsOpaqueEverywhere [
	"Every pixel of the render, inside the triangle and outside it, has full alpha: the clear
	 colour sets it and the fragment shader writes it. A pixel with alpha 0 would be invisible
	 once composited, and nothing else here would notice, because the colour channels would
	 still read correctly."

	self renderedOffscreenTriangleDo: [ :scene |
		self assert: scene nonOpaquePixelCoordinates isEmpty ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleIsRedNearItsRedVertex [
	"Vertex 1 carries red. In Vulkan clip space y points down, so a y of 0.5 is the bottom of
	 the picture and this vertex lands in the bottom left corner of the triangle. Measured on
	 11 October 2026: pixel 10@22 of a 32 by 32 render reads 203, 28, 24. Both halves of the
	 claim are asserted, so the test pins the winding and the y direction rather than assuming
	 them: the vertex data is asked which colour vertex 1 carries, and the render is asked
	 which colour arrived near it."

	self renderedOffscreenTriangleDo: [ :scene |
		self
			assert: (PVOffscreenTriangleScene dominantChannelOfColour:
					 (scene vertexColourAt: 1))
			equals: #red.
		self assert: (scene dominantChannelNearVertex: 1) equals: #red ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleLeavesTheCornersCleared [
	"The triangle spans half the clip volume, so no corner of the picture is inside it. A
	 corner that is not the clear colour means the draw covered the whole target, which is how
	 a broken vertex buffer or a missing viewport looks."

	self renderedOffscreenTriangleDo: [ :scene |
		scene cornerPixels do: [ :pixel |
			self assert: (PVOffscreenTriangleScene isCleared: pixel) ] ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTrianglePixelRulesAllPassAndChangeNothing [
	"The comparison view's verdict column is this list of rules, so a rule that fails on a
	 correct render would show a red picture in the inspector where the suite is green. Reading
	 the rules must also leave the pixels alone: a view that re-mapped the buffer would be a
	 view that changes what it inspects."

	self renderedOffscreenTriangleDo: [ :scene |
		| before |
		before := scene target pixels copy.
		self deny: scene pixelRules isEmpty.
		scene pixelRules do: [ :rule |
			self assert: (rule third value: (scene pixelAt: rule first)) ].
		self assert: scene target pixels equals: before ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOffscreenTriangleRulesHoldOnANonSquareTarget [
	"Every pixel rule of the render holds on a target twice as wide as it is high. The viewport
	 and the scissor are the two structures whose width and height a square target cannot tell
	 apart: swap them and the triangle is drawn into half the picture and clipped out of the
	 other half, so the corners stop being cleared or the probe near a vertex stops carrying
	 that vertex's colour. The rules are asked of the scene rather than restated, so this test
	 says the same thing on a non-square target that the square tests say on theirs."

	self
		renderedOffscreenTriangleOfExtent:
		PVOffscreenTriangleScene exampleExtent x
		@ (PVOffscreenTriangleScene exampleExtent y // 2)
		do: [ :scene |
			self deny: scene pixelRules isEmpty.
			scene pixelRules do: [ :rule |
				self
					assert: (rule third value: (scene pixelAt: rule first))
					description: rule second , ' failed at ' , rule first printString ] ]
]

{ #category : 'tests' }
PVGraphicsTest >> testOneRequestServesSeveralFramebuffersOnThisMachine [
	"The window path builds one framebuffer per swapchain image, in a loop over the same
	 builder, and no machine without a window can run that loop: a swapchain needs a surface.
	 This leg runs the loop headlessly over one view and one offscreen pass instead, which is
	 the shape that would break if the builder kept state between calls, or freed the
	 attachment run or the request before the driver had read it. Each framebuffer is destroyed
	 here, because none of them is held by a target."

	| context image pass framebuffers |
	context := VkContext offscreenGraphicsContext.
	[
		image := VkImage
			         on: context device
			         format: PVOffscreenTarget colorFormat
			         extent: VkImage exampleExtent
			         usage: VkImageUsage colorAttachmentBit.
		image createView.
		pass := VkRenderPass
			        createOffscreenColorPassDevice: context device
			        format: PVOffscreenTarget colorFormat.
		[
			framebuffers := (1 to: 3) collect: [ :each |
				                VkFramebuffer
					                on: context device
					                renderPass: pass
					                imageView: image view
					                extent: VkImage exampleExtent ].
			[
				framebuffers do: [ :each |
					self deny: each handle getHandle isNull ].
				self
					assert: (framebuffers collect: [ :each |
							 each handle getHandle asInteger ]) asSet size
					equals: framebuffers size ] ensure: [
				framebuffers do: [ :each | each destroy ] ] ] ensure: [
			pass destroy.
			image destroy ] ] ensure: [ context destroy ]
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
PVGraphicsTest >> testPresentRequestForARealSwapchainCarriesItsHandleAndIndex [
	"What only a real swapchain can exercise: the request a present is built from carries the
	 swapchain's own handle and the index of an image it actually holds. The runs are read
	 back through the pointers the request holds, which is what proves the driver would find
	 the handle this project meant to give it, and the request and its runs go back together."

	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	self windowSceneDo: [ :scene :backendWindow |
		| swapchain imageIndex info rows |
		swapchain := scene swapchain.
		imageIndex := swapchain imageCount - 1.
		info := VkSwapchain
			        presentInfoForSwapchain: swapchain handle
			        imageIndex: imageIndex
			        waitSemaphore: ExternalAddress null.
		rows := [
		        self
			        assert: (info pSwapchains getHandle pointerAt: 1)
			        equals: swapchain handle getHandle.
		        self
			        assert: (info pImageIndices getHandle unsignedLongAt: 1)
			        equals: imageIndex.
		        info presentRows ] ensure: [
			        VkSwapchain freePresentInfo: info ].
		self assert: (rows at: #swapchainGiven).
		self assert: (rows at: #imageIndexGiven).
		self deny: (rows at: #resultsRequested) ]
]

{ #category : 'tests' }
PVGraphicsTest >> testRenderFrameCyclesThroughTheSwapchainImages [
	"Phase 6 claimed stable frames; this asserts it. Rendering more frames than the swapchain
	 has images must acquire every image at least once, which is what says the acquire, submit
	 and present cycle really is a cycle and not one image presented over and over. A fence or
	 semaphore left unsignalled shows up here as a hang or as a repeated index."

	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	self windowSceneDo: [ :scene :backendWindow |
		| acquired |
		acquired := Set new.
		1 to: scene swapchain imageCount * 2 + 1 do: [ :frame |
			acquired add: scene renderFrame ].
		self
			assert: acquired size
			equals: scene swapchain imageCount ]
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

{ #category : 'tests' }
PVGraphicsTest >> testSceneDestroyReleasesEverySlotOnARealDevice [
	"The same claim PVRecordingContextStub covers, against a device and a surface instead. The
	 stub cannot catch a slot that only the window path fills, so this asks the scene after
	 teardown: every owned slot released, and only the context still held, because the scene
	 does not own it."

	| scene report |
	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	scene := self windowSceneDo: [ :each :backendWindow |
		         self
			         assert: (each lifecycleReport allSatisfy: [ :slot |
					          slot value = PVHelloTriangleScene liveLabel ])
			         description: 'a prepared scene holds every slot' ].
	report := scene lifecycleReport.
	self
		assert: report size
		equals: PVHelloTriangleScene allInstVarNames size.
	report do: [ :slot |
		self
			assert: slot value
			equals: ((PVHelloTriangleScene unownedSlotNames includes: slot key)
					 ifTrue: [ PVHelloTriangleScene liveLabel ]
					 ifFalse: [ PVHelloTriangleScene releasedLabel ]) ]
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

{ #category : 'tests - window' }
PVGraphicsTest >> testSurfaceReportsWhatItAllowsAndWhatItOffersOnThisMachine [
	"What only a real surface can exercise: the two structures the driver fills. The report
	 must survive the block it was written into being freed, which is what asking twice and
	 comparing proves. The format the swapchain was created with must be one the surface
	 actually offered, and the extent it was created with must lie inside the extents the
	 surface accepts, or the driver would have refused the swapchain."

	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	self windowSceneDo: [ :scene :backendWindow |
		| capabilities formats chosen |
		capabilities := scene surface capabilities.
		self assert: capabilities surfaceRows equals: scene surface capabilities surfaceRows.
		self assert: capabilities minImageCount >= 1.
		formats := scene surface formats.
		self denyEmpty: formats.
		chosen := scene surface preferredFormat.
		self assert: (formats anySatisfy: [ :each |
					 each format = chosen format and: [
						 each colorSpace = chosen colorSpace ] ]).
		self assert: scene swapchain format equals: chosen format.
		self assert: scene swapchain imageCount
			>= (VkSwapchain imageCountFor: capabilities).
		self
			assert: scene swapchain extent x >= capabilities minImageExtent width;
			assert: scene swapchain extent x <= capabilities maxImageExtent width;
			assert: scene swapchain extent y >= capabilities minImageExtent height;
			assert: scene swapchain extent y <= capabilities maxImageExtent height ]
]

{ #category : 'tests' }
PVGraphicsTest >> testSwapchainHasAnImageViewForEveryImage [
	"What only a surface can exercise: the swapchain the driver actually gave us. Presentation
	 needs at least two images to alternate between, every image needs a view for its
	 framebuffer, and the extent must be the one the window drawable reported, not the size
	 asked for. This says nothing about what appears on screen; the pixels are proven offscreen
	 in the triangle tests."

	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	self windowSceneDo: [ :scene :backendWindow |
		| swapchain |
		swapchain := scene swapchain.
		self assert: swapchain imageCount >= 2.
		self assert: swapchain imageViews size equals: swapchain imageCount.
		self
			assert: swapchain extent
			equals: backendWindow vulkanDrawableExtent ]
]

{ #category : 'tests' }
PVGraphicsTest >> testSwapchainRequestForARealSurfaceCarriesWhatTheSurfaceReported [
	"What only a real surface can exercise: the request built from a driver report. The
	 request must carry the surface's own transform and one of the pairs it offered, ask for
	 an image count the surface allows, and name an extent inside the ones it accepts — the
	 same request the live swapchain was created from, which is why its format is compared
	 with the one the swapchain reports."

	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	self windowSceneDo: [ :scene :backendWindow |
		| capabilities chosen info rows |
		capabilities := scene surface capabilities.
		chosen := scene surface preferredFormat.
		info := VkSwapchain
			        createInfoForSurface: scene surface handle
			        format: chosen
			        capabilities: capabilities
			        extent: scene swapchain extent.
		rows := [
		        self assert: info surface isNull not.
		        self assert: info imageFormat equals: scene swapchain format.
		        self assert: info preTransform equals: capabilities currentTransform.
		        self assert: info minImageCount >= capabilities minImageCount.
		        capabilities maxImageCount = VkSwapchain unlimitedImageCount ifFalse: [
			        self assert: info minImageCount <= capabilities maxImageCount ].
		        self
			        assert: info imageExtent width >= capabilities minImageExtent width;
			        assert: info imageExtent width <= capabilities maxImageExtent width;
			        assert: info imageExtent height >= capabilities minImageExtent height;
			        assert: info imageExtent height
				        <= capabilities maxImageExtent height.
		        info swapchainRows ] ensure: [ info getHandle free ].
		self assert: (rows at: #surfaceSet).
		self assert: (rows at: #extent) equals: scene swapchain extent.
		self
			assert: (rows at: #presentModeName)
			equals: scene swapchain presentModeName ]
]

{ #category : 'tests - window' }
PVGraphicsTest >> testSwapchainViewReportsEveryImageWithoutMutating [
	"The view is the only place that states what the driver handed us for this window, so it has
	 to carry a row for every swapchain image with both of that image's objects, and building it
	 must not disturb the scene it reports on."

	| scene expected |
	PVHelloTriangleScene displayAvailable ifFalse: [
		^ self skip: PVHelloTriangleScene displayUnavailableReason ].
	expected := PVHelloTriangleScene attachmentSeparator join: {
			            PVHelloTriangleScene viewLabel.
			            PVHelloTriangleScene framebufferLabel }.
	scene := self windowSceneDo: [ :aScene :backendWindow |
		         | before view imageRows |
		         before := aScene swapchainReport.
		         view := aScene inspectorSwapchain: SpPresenter new.
		         imageRows := view items select: [ :each |
			                      each key beginsWith:
				                      PVHelloTriangleScene imageRowPrefix ].
		         self assert: imageRows size equals: aScene swapchain imageCount.
		         imageRows do: [ :each | self assert: each value equals: expected ].
		         self
			         assert: aScene swapchainReport = before
			         description: 'building the view must not change what the scene reports' ].
	self
		assert: scene swapchainReport
			  = { 'swapchain' -> PVHelloTriangleScene releasedLabel }
		description: 'a released scene must report the release, not a swapchain it dropped'
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

{ #category : 'running' }
PVGraphicsTest >> windowSceneDo: aBlock [
	"Open a real window, build a context and a scene against it, pass the scene and the
	 backend window to the block, and answer the scene once everything is released. The
	 teardown mirrors PVHelloTriangleScene class >> renderTriangle exactly: scene, context,
	 window, driver, each released by its own ensure:, because a raise that strands a live
	 VkInstance or an SDL window still registered with the driver resurfaces as a segfault on
	 the next run with the validation layers off. The scene is answered after teardown so a
	 test can assert on what destroy left behind."

	| attributes |
	attributes := PVWindowAttributes newVulkan.
	attributes
		title: PVHelloTriangleScene windowTitle;
		extent: PVHelloTriangleScene exampleExtent;
		windowCentered: true.
	^ PVVulkanDriver installDuring: [
		  | window |
		  window := OSWindow createWithAttributes: attributes.
		  [
		  | backendWindow context |
		  backendWindow := window backendWindow.
		  context := VkContext graphicsContextForExtensions:
			             backendWindow requiredInstanceExtensions.
		  [
		  | scene |
		  scene := PVHelloTriangleScene
			           prepare: context
			           backendWindow: backendWindow.
		  [ aBlock value: scene value: backendWindow ] ensure: [ scene destroy ].
		  scene ] ensure: [ context destroy ] ] ensure: [ window destroy ] ]
]
