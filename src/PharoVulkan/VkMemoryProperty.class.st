"
Named constants for VkMemoryPropertyFlagBits combinations used when allocating device
memory. Key methods: deviceLocalBit, hostVisibleBit, hostCoherentBit (the single bits),
hostVisibleAndCoherent (hostVisibleBit | hostCoherentBit = 6), nameForFlags: (decodes a
property-flag word back to names for the inspector).
"
Class {
	#name : 'VkMemoryProperty',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkMemoryProperty class >> deviceLocalBit [
	"VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT"
	^ 1
]

{ #category : 'constants' }
VkMemoryProperty class >> hostCoherentBit [
	"VK_MEMORY_PROPERTY_HOST_COHERENT_BIT"
	^ 4
]

{ #category : 'constants' }
VkMemoryProperty class >> hostVisibleAndCoherent [
	"Mapped memory must be readable without an explicit flush, which needs both bits:
	 host-visible alone (the previous value, 3 = DEVICE_LOCAL | HOST_VISIBLE) let a readback
	 see stale bytes on hardware where that memory type is not also coherent."
	^ self hostVisibleBit bitOr: self hostCoherentBit
]

{ #category : 'constants' }
VkMemoryProperty class >> hostVisibleBit [
	"VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT"
	^ 2
]

{ #category : 'decoding' }
VkMemoryProperty class >> nameForFlags: flags [
	"Joins the names of the bits this project names; a bit no constant here carries is shown
	 as its raw hex rather than silently dropped, so the view can never hide a property it
	 does not yet know the name of."
	| known remainder names |
	known := {
		self deviceLocalBit -> 'DeviceLocal'.
		self hostVisibleBit -> 'HostVisible'.
		self hostCoherentBit -> 'HostCoherent' }.
	names := OrderedCollection new.
	remainder := flags.
	known do: [ :assoc |
		(flags bitAnd: assoc key) = assoc key ifTrue: [
			names add: assoc value.
			remainder := remainder bitAnd: assoc key bitInvert ] ].
	remainder ~= 0 ifTrue: [ names add: (remainder printPaddedWith: $0 to: 1 base: 16) , 'h' ].
	^ String streamContents: [ :s |
		names do: [ :n | s nextPutAll: n ] separatedBy: [ s nextPutAll: '|' ] ]
]
