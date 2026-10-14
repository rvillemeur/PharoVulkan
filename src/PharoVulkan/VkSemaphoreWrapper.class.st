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
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'instance creation' }
VkSemaphoreWrapper class >> createDevice: aVkDevice [
    | obj |
    obj := self new.
    obj initializeDevice: aVkDevice.
    ^ obj
]

{ #category : 'examples' }
VkSemaphoreWrapper class >> exampleSemaphoreOnThisMachine [
	"One click: one of the two semaphores a frame loop uses to order acquire against present,
	 created on this machine and destroyed with its context. Where no device is available it
	 answers an uncreated semaphore, which is what the inspector should show on such a
	 machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ self new ].
	^ [
	  | semaphore |
	  semaphore := self createDevice: context device.
	  semaphore destroy.
	  semaphore ] ensure: [ context destroy ]
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
VkSemaphoreWrapper >> handleForCreateInfo: aCreateInfo [
	"The driver writes the handle into a block the caller owns, so the block is freed here and
	 only the handle leaves."

	| out result |
	out := ExternalAddress allocate: VkContext pointerSize.
	^ [
	  result := Vk
		            createSemaphore: device handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            pSemaphore: out.
	  Vk checkResult: result.
	  VkSemaphore_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'initialization' }
VkSemaphoreWrapper >> initializeDevice: aVkDevice [
	"The request carries nothing but its structure type: a semaphore's flags are reserved by
	 Vulkan and must be zero, which a fresh block already is."

	| info |
	device := aVkDevice.
	info := VkSemaphoreCreateInfo externalInstance.
	handle := [ self handleForCreateInfo: info ] ensure: [
		          info getHandle free ]
]

{ #category : 'inspector' }
VkSemaphoreWrapper >> inspectorSemaphore: aBuilder [
	"The whole of a semaphore's creation: a request that carries nothing but its structure
	 type, so the reserved word is read back off a fresh request rather than restated, and
	 whether the handle is still live. The rows are built fresh, so opening the tab cannot
	 change the semaphore."

	<inspectorPresentationOrder: 30 title: 'Semaphore'>
	| rows |
	rows := self semaphoreRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Reserved flags'. (rows at: #reservedFlags) }.
				  { 'Handle live'. (rows at: #live) } };
		  yourself
]

{ #category : 'accessing' }
VkSemaphoreWrapper >> semaphoreRows [
	"A semaphore is created from a request that carries nothing but its structure type, so the
	 one thing there is to report besides liveness is the reserved word, read back off a fresh
	 request rather than restated here. The rows are built fresh on every call, so reading them
	 cannot change the semaphore."

	| info reserved |
	info := VkSemaphoreCreateInfo externalInstance.
	reserved := [ info flags ] ensure: [ info getHandle free ].
	^ Dictionary newFrom: {
			  (#reservedFlags -> reserved).
			  (#live -> (handle isNotNil and: [ handle isNull not ])) }
]
