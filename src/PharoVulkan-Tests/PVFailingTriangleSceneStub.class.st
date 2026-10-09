Class {
	#name : 'PVFailingTriangleSceneStub',
	#superclass : 'PVHelloTriangleScene',
	#classInstVars : [
		'destroyCount'
	],
	#category : 'PharoVulkan-Tests-Graphics',
	#package : 'PharoVulkan-Tests',
	#tag : 'Graphics'
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

{ #category : 'initialization' }
PVFailingTriangleSceneStub >> destroy [
	self class noteDestroy.
	super destroy
]

{ #category : 'initialization' }
PVFailingTriangleSceneStub >> initializeCtx: aVkContext backendWindow: aBackendWindow [
	Error signal: 'initialisation failed'
]
