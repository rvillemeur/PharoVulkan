"
CPU-GPU synchronization primitive. Supports signaled (#createSignaledDevice:) and unsignaled (#createDevice:) creation, waiting (#waitTimeout:), resetting (#reset), and destroy.
"
Class {
	#name : 'VkFenceWrapper',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'flags'
	],
	#category : 'PharoVulkan-Core-Commands',
	#package : 'PharoVulkan-Core',
	#tag : 'Commands'
}

{ #category : 'instance creation' }
VkFenceWrapper class >> createDevice: aVkDevice [
	^ self createDevice: aVkDevice flags: self unsignaledFlags
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
	^ self createDevice: aVkDevice flags: VkFenceCreateFlag signaledBit
]

{ #category : 'constants' }
VkFenceWrapper class >> unsignaledFlags [
	"A fence asked for with no flags starts unsignalled, which is what everything but a frame
	 loop's first wait wants."

	^ 0
]

{ #category : 'lifecycle' }
VkFenceWrapper >> destroy [

	handle ifNotNil: [
			Vk
				destroyFence: device handle
				fence: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkFenceWrapper >> fenceRows [
	"What the fence was created with: the flags, their names from the constants class that owns
	 the bits, whether it started signalled — asked of the bit rather than of a kept boolean —
	 and whether the handle is still live. The rows are built fresh on every call, so reading
	 them cannot change the fence."

	^ Dictionary newFrom: {
			  (#flags -> flags).
			  (#flagNames -> (VkFenceCreateFlag nameForFlags: flags)).
			  (#signalledAtCreation
			   -> ((flags bitAnd: VkFenceCreateFlag signaledBit)
					    = VkFenceCreateFlag signaledBit)).
			  (#live -> (handle isNotNil and: [ handle isNull not ])) }
]

{ #category : 'accessing' }
VkFenceWrapper >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkFenceWrapper >> handleForCreateInfo: aCreateInfo [
	"The driver writes the handle into a block the caller owns, so the block is freed here and
	 only the handle leaves."

	| out result |
	out := ExternalAddress allocate: VkContext pointerSize.
	^ [
	  result := Vk
		            createFence: device handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            pFence: out.
	  Vk checkResult: result.
	  VkFence_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'initialization' }
VkFenceWrapper >> initialize [
	"A fence that was never created carries no flags, so the Fence tab opens on one with the
	 flags reading as none rather than as nil."

	super initialize.
	flags := self class unsignaledFlags
]

{ #category : 'initialization' }
VkFenceWrapper >> initializeDevice: aVkDevice flags: flagsValue [
	"The flags are kept because the driver never answers them back: a fence cannot be asked
	 whether it was created signalled."

	| info |
	device := aVkDevice.
	flags := flagsValue.
	info := VkFenceCreateInfo externalInstance.
	handle := [
	          info flags: flagsValue.
	          self handleForCreateInfo: info ] ensure: [ info getHandle free ]
]

{ #category : 'inspector' }
VkFenceWrapper >> inspectorFence: aBuilder [
	"What the fence was created with: the flags, the names of the bits in them decoded by the
	 constants class that owns them, whether it started signalled, and whether the handle is
	 still live. The rows are built fresh, so opening the tab cannot change the fence."

	<inspectorPresentationOrder: 30 title: 'Fence'>
	| rows |
	rows := self fenceRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Flags'. (rows at: #flagNames) }.
				  { 'Signalled at creation'. (rows at: #signalledAtCreation) }.
				  { 'Handle live'. (rows at: #live) } };
		  yourself
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
