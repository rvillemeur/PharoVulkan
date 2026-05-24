"
GPU-GPU synchronization primitive. Create with #createDevice:, destroy with #destroy. Wraps VkSemaphore.
"
Class {
	#name : 'VkSemaphoreWrapper',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device'
	],
	#category : 'Pharovulkan-graphics',
	#package : 'Pharovulkan-graphics'
}

{ #category : 'instance creation' }
VkSemaphoreWrapper class >> createDevice: aVkDevice [
    | obj |
    obj := self new.
    obj initializeDevice: aVkDevice.
    ^ obj
]

{ #category : 'lifecycle' }
VkSemaphoreWrapper >> destroy [

	handle ifNotNil: [
			Vk
				destroySemaphore: device handle
				semaphore: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkSemaphoreWrapper >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkSemaphoreWrapper >> initializeDevice: aVkDevice [
	"VkSemaphoreCreateInfo (24 bytes):
     0:sType  8:pNext  16:flags"

	| info semBuf result |
	device := aVkDevice.
	info := ExternalAddress allocate: 24.
	handle := [
		          info
			          unsignedLongAt: 1
			          put: VkStructureType semaphoreCreateInfo.
		          info pointerAt: 9 put: ExternalAddress null.
		          info unsignedLongAt: 17 put: 0.
		          semBuf := ExternalAddress allocate: 8.
		          [
			          result := Vk
				                    createSemaphore: aVkDevice handle
				                    createInfo: info
				                    allocator: ExternalAddress null
				                    pSemaphore: semBuf.
			          Vk checkResult: result.
			          VkSemaphore_H fromHandle: (semBuf pointerAt: 1) ]
			          ensure: [ semBuf free ] ] ensure: [ info free ]
]
