"
Wrapper around a VkQueue_H with its queue family index. Submits compute dispatches (submitCompute:) and graphics frames (submitGraphics:waitSemaphore:signalSemaphore:fence:). Also performs waitIdle and present.
"
Class {
	#name : 'VkQueue',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'familyIndex'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan-Core'
}

{ #category : 'factory' }
VkQueue class >> on: aHandle familyIndex: idx [
    ^ self new initializeWith: aHandle familyIndex: idx
]

{ #category : 'accessing' }
VkQueue >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkQueue >> initializeWith: aHandle familyIndex: idx [
    handle := aHandle. familyIndex := idx
]

{ #category : 'operations' }
VkQueue >> submit: aCmdBuffer andWait: doWait [
	| cmdInfo submitInfo result |
	cmdInfo := ExternalAddress allocate: 32.
	[ cmdInfo unsignedLongAt: 1 put: 1000314006.
	  cmdInfo pointerAt: 9 put: ExternalAddress null.
	  cmdInfo pointerAt: 17 put: aCmdBuffer handle getHandle.
	  cmdInfo unsignedLongAt: 25 put: 0.
	  submitInfo := ExternalAddress allocate: 64.
	  [ submitInfo unsignedLongAt: 1 put: 1000314004.
	    submitInfo pointerAt: 9 put: ExternalAddress null.
	    submitInfo unsignedLongAt: 17 put: 0.
	    submitInfo unsignedLongAt: 21 put: 0.
	    submitInfo pointerAt: 25 put: ExternalAddress null.
	    submitInfo unsignedLongAt: 33 put: 1.
	    submitInfo pointerAt: 41 put: cmdInfo.
	    submitInfo unsignedLongAt: 49 put: 0.
	    submitInfo pointerAt: 57 put: ExternalAddress null.
	    result := Vk queueSubmit2: handle submitCount: 1 submits: submitInfo fence: ExternalAddress null.
	    Vk checkResult: result.
	    doWait ifTrue: [ self waitIdle ]
	  ] ensure: [ submitInfo free ]
	] ensure: [ cmdInfo free ]
]

{ #category : 'submitting' }
VkQueue >> waitIdle [
    Vk checkResult: (Vk queueWaitIdle: handle)
]
