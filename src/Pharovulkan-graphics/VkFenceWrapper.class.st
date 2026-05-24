"
CPU-GPU synchronization primitive. Supports signaled (#createSignaledDevice:) and unsignaled (#createDevice:) creation, waiting (#waitTimeout:), resetting (#reset), and destroy.
"
Class {
	#name : 'VkFenceWrapper',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device'
	],
	#category : 'Pharovulkan-graphics',
	#package : 'Pharovulkan-graphics'
}

{ #category : 'instance creation' }
VkFenceWrapper class >> createDevice: aVkDevice [
    ^ self createDevice: aVkDevice flags: 0
]

{ #category : 'instance creation' }
VkFenceWrapper class >> createDevice: aVkDevice flags: aFlags [
    | obj |
    obj := self new.
    obj initializeDevice: aVkDevice flags: aFlags.
    ^ obj
]

{ #category : 'instance creation' }
VkFenceWrapper class >> createSignaledDevice: aVkDevice [
    ^ self createDevice: aVkDevice flags: 1
]

{ #category : 'lifecycle' }
VkFenceWrapper >> destroy [
	handle ifNotNil: [
		Vk destroyFence: device handle fence: handle allocator: ExternalAddress null.
		handle invalidate.
		handle := nil ]

]

{ #category : 'accessing' }
VkFenceWrapper >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkFenceWrapper >> initializeDevice: aVkDevice flags: flagsValue [
	"VkFenceCreateInfo (24 bytes):
     0:sType  8:pNext  16:flags"

	| info fenceBuf result |
	device := aVkDevice.
	info := ExternalAddress allocate: 24.
	handle := [
		          info
			          unsignedLongAt: 1
			          put: VkStructureType fenceCreateInfo.
		          info pointerAt: 9 put: ExternalAddress null.
		          info unsignedLongAt: 17 put: flagsValue.
		          fenceBuf := ExternalAddress allocate: 8.
		          [
			          result := Vk
				                    createFence: aVkDevice handle
				                    createInfo: info
				                    allocator: ExternalAddress null
				                    pFence: fenceBuf.
			          Vk checkResult: result.
			          VkFence_H fromHandle: (fenceBuf pointerAt: 1) ] ensure: [
			          fenceBuf free ] ] ensure: [ info free ]
]

{ #category : 'operations' }
VkFenceWrapper >> reset [
    | buf result |
    buf := ExternalAddress allocate: 8.
    [ buf pointerAt: 1 put: handle getHandle.
      result := Vk resetFences: device handle fenceCount: 1 pFences: buf.
      Vk checkResult: result
    ] ensure: [ buf free ]
]

{ #category : 'operations' }
VkFenceWrapper >> waitTimeout: nanoseconds [
    | buf result |
    buf := ExternalAddress allocate: 8.
    [ buf pointerAt: 1 put: handle getHandle.
      result := Vk waitForFences: device handle fenceCount: 1 pFences: buf waitAll: 1 timeout: nanoseconds.
      Vk checkResult: result
    ] ensure: [ buf free ]
]
