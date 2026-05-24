Extension { #name : 'VkQueue' }

{ #category : '*pharovulkan-graphics' }
VkQueue >> submitGraphics: aCommandBuffer waitSemaphore: aWaitSemaphore signalSemaphore: aSignalSemaphore fence: aFence [
    | waitInfo signalInfo cbInfo submitInfo |
    waitInfo := ExternalAddress allocate: 48.
    [ waitInfo unsignedLongAt: 1 put: 1000314005.
      waitInfo pointerAt: 9 put: ExternalAddress null.
      waitInfo pointerAt: 17 put: aWaitSemaphore handle getHandle.
      waitInfo unsignedLongLongAt: 25 put: 0.
      waitInfo unsignedLongLongAt: 33 put: 1024.
      waitInfo unsignedLongAt: 41 put: 0.
      signalInfo := ExternalAddress allocate: 48.
      [ signalInfo unsignedLongAt: 1 put: 1000314005.
        signalInfo pointerAt: 9 put: ExternalAddress null.
        signalInfo pointerAt: 17 put: aSignalSemaphore handle getHandle.
        signalInfo unsignedLongLongAt: 25 put: 0.
        signalInfo unsignedLongLongAt: 33 put: 1024.
        signalInfo unsignedLongAt: 41 put: 0.
        cbInfo := ExternalAddress allocate: 32.
        [ cbInfo unsignedLongAt: 1 put: 1000314006.
          cbInfo pointerAt: 9 put: ExternalAddress null.
          cbInfo pointerAt: 17 put: aCommandBuffer handle getHandle.
          cbInfo unsignedLongAt: 25 put: 0.
          submitInfo := ExternalAddress allocate: 64.
          [ submitInfo unsignedLongAt: 1 put: 1000314004.
            submitInfo pointerAt: 9 put: ExternalAddress null.
            submitInfo unsignedLongAt: 17 put: 0.
            submitInfo unsignedLongAt: 21 put: 1.
            submitInfo pointerAt: 25 put: waitInfo.
            submitInfo unsignedLongAt: 33 put: 1.
            submitInfo pointerAt: 41 put: cbInfo.
            submitInfo unsignedLongAt: 49 put: 1.
            submitInfo pointerAt: 57 put: signalInfo.
            Vk checkResult: (Vk queueSubmit2KHR: handle submitCount: 1 pSubmits: submitInfo fence: aFence handle getHandle)
          ] ensure: [ submitInfo free ]
        ] ensure: [ cbInfo free ]
      ] ensure: [ signalInfo free ]
    ] ensure: [ waitInfo free ]
]
