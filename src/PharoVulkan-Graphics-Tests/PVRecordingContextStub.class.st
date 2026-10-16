"
Stands in for VkContext where a test needs a context but no driver: computeQueue and device
answer the stub itself, so a scene can send them on without a real device, and waitIdle only
counts, so a test can state that teardown waited for the device exactly once. Key method:
waitIdleCount.
"
Class {
	#name : 'PVRecordingContextStub',
	#superclass : 'Object',
	#instVars : [
		'waitIdleCount'
	],
	#category : 'PharoVulkan-Graphics-Tests-Fixtures',
	#package : 'PharoVulkan-Graphics-Tests',
	#tag : 'Fixtures'
}

{ #category : 'accessing' }
PVRecordingContextStub >> computeQueue [
	^ self
]

{ #category : 'accessing' }
PVRecordingContextStub >> device [
	^ self
]

{ #category : 'counting' }
PVRecordingContextStub >> waitIdle [
	waitIdleCount := self waitIdleCount + 1
]

{ #category : 'accessing' }
PVRecordingContextStub >> waitIdleCount [
	^ waitIdleCount ifNil: [ 0 ]
]
