"
A scene whose initialisation always raises, used to show that PVHelloTriangleScene class >>
prepare:backendWindow: destroys a half-initialised scene instead of stranding the Vulkan objects
it had already created. Counts the destroy calls on the class side, because the instance the
raise curtails is never handed to the test. Key methods: resetDestroyCount, destroyCount.
"
Class {
	#name : 'PVFailingTriangleSceneStub',
	#superclass : 'PVHelloTriangleScene',
	#classInstVars : [
		'destroyCount'
	],
	#category : 'PharoVulkan-Graphics-Tests-Fixtures',
	#package : 'PharoVulkan-Graphics-Tests',
	#tag : 'Fixtures'
}

{ #category : 'accessing' }
PVFailingTriangleSceneStub class >> destroyCount [
	^ destroyCount ifNil: [ 0 ]
]

{ #category : 'counting' }
PVFailingTriangleSceneStub class >> noteDestroy [
	destroyCount := self destroyCount + 1
]

{ #category : 'counting' }
PVFailingTriangleSceneStub class >> resetDestroyCount [
	destroyCount := 0
]

{ #category : 'releasing' }
PVFailingTriangleSceneStub >> destroy [
	self class noteDestroy.
	super destroy
]

{ #category : 'initialization' }
PVFailingTriangleSceneStub >> initializeCtx: aVkContext backendWindow: aBackendWindow [
	Error signal: 'initialisation failed'
]
