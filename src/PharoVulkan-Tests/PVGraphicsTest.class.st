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
