"
Named constants for VkMemoryPropertyFlagBits combinations used when allocating device
memory. Key methods: deviceLocalBit, hostVisibleBit, hostCoherentBit, hostCachedBit (the
single bits), hostVisibleAndCoherent (hostVisibleBit | hostCoherentBit = 6, what every
mapped buffer in this project asks for), namedBits (the table VkFlagConstants decodes a
driver's flags word with).
"
Class {
	#name : 'VkMemoryProperty',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkMemoryProperty class >> deviceLocalBit [
	"VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT"
	^ 1
]

{ #category : 'constants' }
VkMemoryProperty class >> hostCachedBit [
	"VK_MEMORY_PROPERTY_HOST_CACHED_BIT"
	^ 8
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
	 see stale bytes on hardware where that memory type is not also coherent.
	 Device-local is deliberately not asked for: every buffer in this project is mapped from
	 the host, and demanding it as well would refuse a device that offers coherent host
	 memory outside its device-local heap."
	^ self hostVisibleBit bitOr: self hostCoherentBit
]

{ #category : 'constants' }
VkMemoryProperty class >> hostVisibleBit [
	"VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT"
	^ 2
]

{ #category : 'decoding' }
VkMemoryProperty class >> namedBits [
	^ {
		self deviceLocalBit -> 'DeviceLocal'.
		self hostVisibleBit -> 'HostVisible'.
		self hostCoherentBit -> 'HostCoherent'.
		self hostCachedBit -> 'HostCached' }
]
