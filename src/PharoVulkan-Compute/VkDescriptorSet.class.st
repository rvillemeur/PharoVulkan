Class {
	#name : 'VkDescriptorSet',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'pool',
		'layout',
		'device'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan-Compute'
}

{ #category : 'accessing' }
VkDescriptorSet >> device: aDevice [
	device := aDevice
]

{ #category : 'accessing' }
VkDescriptorSet >> handle [
	^ handle
]

{ #category : 'accessing' }
VkDescriptorSet >> handle: aHandle [
	handle := aHandle
]

{ #category : 'accessing' }
VkDescriptorSet >> layout: aLayout [
	layout := aLayout
]

{ #category : 'accessing' }
VkDescriptorSet >> pool: aPool [
	pool := aPool
]

{ #category : 'updating' }
VkDescriptorSet >> updateStorageBuffer: aBuffer atBinding: bindingIndex [
	"VkDescriptorBufferInfo 24 bytes + VkWriteDescriptorSet 64 bytes, sType=35"
	"VK_DESCRIPTOR_TYPE_STORAGE_BUFFER=7, VK_WHOLE_SIZE=0xFFFFFFFFFFFFFFFF"
	| bufInfo write |
	bufInfo := ExternalAddress allocate: 24.
	[
		bufInfo pointerAt: 1 put: aBuffer handle getHandle.
		bufInfo uint64At: 9 put: 0.
		bufInfo uint64At: 17 put: 16rFFFFFFFFFFFFFFFF.
		write := ExternalAddress allocate: 64.
		[
			write unsignedLongAt: 1 put: 35.
			write pointerAt: 9 put: ExternalAddress null.
			write pointerAt: 17 put: handle getHandle.
			write unsignedLongAt: 25 put: bindingIndex.
			write unsignedLongAt: 29 put: 0.
			write unsignedLongAt: 33 put: 1.
			write unsignedLongAt: 37 put: 7.
			write pointerAt: 41 put: ExternalAddress null.
			write pointerAt: 49 put: bufInfo.
			write pointerAt: 57 put: ExternalAddress null.
			Vk updateDescriptorSets: device handle descriptorWriteCount: 1
				pDescriptorWrites: write descriptorCopyCount: 0 pDescriptorCopies: ExternalAddress null
		] ensure: [ write free ]
	] ensure: [ bufInfo free ]
]
