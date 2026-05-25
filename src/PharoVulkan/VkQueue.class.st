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
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
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
    [ cmdInfo unsignedLongAt: 1 put: VkStructureType commandBufferSubmitInfo.
      cmdInfo pointerAt: 9 put: ExternalAddress null.
      cmdInfo pointerAt: 17 put: aCmdBuffer handle getHandle.
      cmdInfo unsignedLongAt: 25 put: 0.
      submitInfo := ExternalAddress allocate: 64.
      [ submitInfo unsignedLongAt: 1 put: VkStructureType submitInfo2.
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
VkQueue >> submitGraphics: aCommandBuffer waitSemaphore: aWaitSemaphore signalSemaphore: aSignalSemaphore fence: aFence [
    "VkSemaphoreSubmitInfo (48 bytes):
     0:sType  8:pNext  16:semaphore  24:value  32:stageMask  40:deviceIndex
     VkCommandBufferSubmitInfo (32 bytes):
     0:sType  8:pNext  16:commandBuffer  24:deviceMask
     VkSubmitInfo2 (64 bytes):
     0:sType  8:pNext  16:flags  20:waitSemaphoreInfoCount  24:pWaitSemaphoreInfos(ptr)  32:commandBufferInfoCount  40:pCommandBufferInfos(ptr)  48:signalSemaphoreInfoCount  56:pSignalSemaphoreInfos(ptr)"
    | waitInfo signalInfo cbInfo submitInfo |
    waitInfo := ExternalAddress allocate: 48.
    [ waitInfo unsignedLongAt: 1 put: VkStructureType semaphoreSubmitInfo.
      waitInfo pointerAt: 9 put: ExternalAddress null.
      waitInfo pointerAt: 17 put: aWaitSemaphore handle getHandle.
      waitInfo unsignedLongLongAt: 25 put: 0.
      waitInfo unsignedLongLongAt: 33 put: VkPipelineStage2 colorAttachmentOutputBit.
      waitInfo unsignedLongAt: 41 put: 0.
      signalInfo := ExternalAddress allocate: 48.
      [ signalInfo unsignedLongAt: 1 put: VkStructureType semaphoreSubmitInfo.
        signalInfo pointerAt: 9 put: ExternalAddress null.
        signalInfo pointerAt: 17 put: aSignalSemaphore handle getHandle.
        signalInfo unsignedLongLongAt: 25 put: 0.
        signalInfo unsignedLongLongAt: 33 put: VkPipelineStage2 colorAttachmentOutputBit.
        signalInfo unsignedLongAt: 41 put: 0.
        cbInfo := ExternalAddress allocate: 32.
        [ cbInfo unsignedLongAt: 1 put: VkStructureType commandBufferSubmitInfo.
          cbInfo pointerAt: 9 put: ExternalAddress null.
          cbInfo pointerAt: 17 put: aCommandBuffer handle getHandle.
          cbInfo unsignedLongAt: 25 put: 0.
          submitInfo := ExternalAddress allocate: 64.
          [ submitInfo unsignedLongAt: 1 put: VkStructureType submitInfo2.
            submitInfo pointerAt: 9 put: ExternalAddress null.
            submitInfo unsignedLongAt: 17 put: 0.
            submitInfo unsignedLongAt: 21 put: 1.
            submitInfo pointerAt: 25 put: waitInfo.
            submitInfo unsignedLongAt: 33 put: 1.
            submitInfo pointerAt: 41 put: cbInfo.
            submitInfo unsignedLongAt: 49 put: 1.
            submitInfo pointerAt: 57 put: signalInfo.
            Vk checkResult: (Vk queueSubmit2: handle submitCount: 1 submits: submitInfo fence: aFence handle getHandle)
          ] ensure: [ submitInfo free ]
        ] ensure: [ cbInfo free ]
      ] ensure: [ signalInfo free ]
    ] ensure: [ waitInfo free ]
]

{ #category : 'submitting' }
VkQueue >> waitIdle [
    Vk checkResult: (Vk queueWaitIdle: handle)
]
