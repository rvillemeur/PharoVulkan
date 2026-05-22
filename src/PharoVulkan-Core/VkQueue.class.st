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

{ #category : 'submitting' }
VkQueue >> submit: aCmdBuffer andWait: doWait [
    "VkCommandBufferSubmitInfo: sType=1000314006, pNext=null, commandBuffer, deviceMask=0"
    "VkSubmitInfo2: sType=1000314004, pNext=null, flags=0, wait=0,null, cmd=1,ptr, signal=0,null"
    | cmdInfo submitInfo result |
    cmdInfo := ExternalAddress allocate: 32.
    [ cmdInfo unsignedLongAt: 1 put: 1000314006.
      cmdInfo pointerAt: 9 put: ExternalAddress null.
      cmdInfo pointerAt: 17 put: aCmdBuffer handle getHandle.
      cmdInfo unsignedLongAt: 25 put: 0.
      submitInfo := ExternalAddress allocate: 64.
      [ submitInfo unsignedLongAt: 1 put: 1000314004.
        submitInfo pointerAt: 9 put: ExternalAddress null.
        submitInfo unsignedLongAt: 17 put: 0.  "flags"
        submitInfo unsignedLongAt: 21 put: 0.  "waitSemaphoreInfoCount"
        submitInfo pointerAt: 25 put: ExternalAddress null. "pWaitSemaphoreInfos"
        submitInfo unsignedLongAt: 33 put: 1.  "commandBufferInfoCount"
        submitInfo pointerAt: 37 put: cmdInfo.  "pCommandBufferInfos"
        submitInfo unsignedLongAt: 45 put: 0.  "signalSemaphoreInfoCount"
        submitInfo pointerAt: 49 put: ExternalAddress null. "pSignalSemaphoreInfos"
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
