"
I am the abstract superclass of the benchmarks and comparisons of this project that dispatch
on the device through a VkContext, which I hold in `context`.

`run` is the template: it asks the subclass for its buffers, hands them to it, and destroys
them in an ensure: block whatever happens, so a second run does not accumulate device memory.
A subclass states how its buffers are built (`newBuffers`) and what it does with them
(`runWithBuffers:`). A run whose buffers are not allocated around a single dispatch does not
belong here: PVCooperativeMatrixComparison is deliberately not one of my subclasses.
"
Class {
	#name : 'PVDeviceRun',
	#superclass : 'Object',
	#instVars : [
		'context'
	],
	#category : 'PharoVulkan-Compute-Benchmarks',
	#package : 'PharoVulkan-Compute',
	#tag : 'Benchmarks'
}

{ #category : 'accessing' }
PVDeviceRun >> groupCount [
	"How many workgroups the dispatch asks for, which depends on the size of the problem."

	^ self subclassResponsibility
]

{ #category : 'private' }
PVDeviceRun >> newBuffers [
	"The device buffers the run needs, in the order runWithBuffers: expects them."

	^ self subclassResponsibility
]

{ #category : 'reporting' }
PVDeviceRun >> reportRows [
	"The run as rows of the two-column fact table, for the inspector view of the subclass."

	^ self subclassResponsibility
]

{ #category : 'running' }
PVDeviceRun >> run [
	"Answer whatever the subclass answers for its configuration. The buffers are built and
	 destroyed around the dispatch, so repeated runs do not accumulate device memory."

	| buffers |
	buffers := self newBuffers.
	^ [ self runWithBuffers: buffers ] ensure: [
		  buffers do: [ :each | each destroy ] ]
]

{ #category : 'private' }
PVDeviceRun >> runWithBuffers: aCollection [
	"Dispatch on the device with those buffers and answer the result of the run. The caller
	 destroys them."

	^ self subclassResponsibility
]
