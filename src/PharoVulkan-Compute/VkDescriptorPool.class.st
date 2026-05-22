Class {
	#name : 'VkDescriptorPool',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan-Compute'
}

{ #category : 'instance creation' }
VkDescriptorPool class >> on: aDevice maxSets: n [
	| p |
	p := self new.
	p device: aDevice.
	p create: n.
	^ p
]

{ #category : 'lifecycle' }
VkDescriptorPool >> create: maxSets [
	"VkDescriptorPoolSize 8 bytes + VkDescriptorPoolCreateInfo 40 bytes, sType=33"
	| sizeBuf info poolBuf result |
	sizeBuf := ExternalAddress allocate: 8.
	[
		sizeBuf unsignedLongAt: 1 put: 7.
		sizeBuf unsignedLongAt: 5 put: maxSets.
		info := ExternalAddress allocate: 40.
		[
			info unsignedLongAt: 1 put: 33.
			info pointerAt: 9 put: ExternalAddress null.
			info unsignedLongAt: 17 put: 0.
			info unsignedLongAt: 21 put: maxSets.
			info unsignedLongAt: 25 put: 1.
			info pointerAt: 33 put: sizeBuf.
			poolBuf := ExternalAddress allocate: 8.
			[
				result := Vk createDescriptorPool: device handle createInfo: info
					allocator: ExternalAddress null descriptorPoolOut: poolBuf.
				Vk checkResult: result.
				handle := VkDescriptorPool_H fromHandle: (poolBuf pointerAt: 1)
			] ensure: [ poolBuf free ]
		] ensure: [ info free ]
	] ensure: [ sizeBuf free ]
]

{ #category : 'lifecycle' }
VkDescriptorPool >> destroy [
	handle isNil ifTrue: [ ^ self ].
	Vk destroyDescriptorPool: device handle descriptorPool: handle allocator: ExternalAddress null.
	handle := nil
]

{ #category : 'accessing' }
VkDescriptorPool >> device: aDevice [
	device := aDevice
]

{ #category : 'accessing' }
VkDescriptorPool >> handle [
	^ handle
]
