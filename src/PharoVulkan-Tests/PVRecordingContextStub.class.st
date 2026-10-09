Class {
	#name : 'PVRecordingContextStub',
	#superclass : 'Object',
	#instVars : [
		'waitIdleCount'
	],
	#category : 'PharoVulkan-Tests-Graphics',
	#package : 'PharoVulkan-Tests',
	#tag : 'Graphics'
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
