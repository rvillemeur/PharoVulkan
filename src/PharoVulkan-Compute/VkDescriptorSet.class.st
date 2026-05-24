"
Vulkan descriptor set. Binds storage buffers to shader binding slots via vkUpdateDescriptorSets. Key method: bindBuffers: to configure buffer descriptors before dispatch.
"
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
    "VkDescriptorBufferInfo 24 bytes + VkWriteDescriptorSet 64 bytes sType=writeDescriptorSet"
    | bufInfo write |
    bufInfo := ExternalAddress allocate: 24.
    [
        bufInfo pointerAt: 1 put: aBuffer handle getHandle.
        bufInfo unsignedLongLongAt: 9 put: 0.
        bufInfo unsignedLongLongAt: 17 put: 16rFFFFFFFFFFFFFFFF.
        write := ExternalAddress allocate: 64.
        [
            write unsignedLongAt: 1 put: VkStructureType writeDescriptorSet.
            write pointerAt: 9 put: ExternalAddress null.
            write pointerAt: 17 put: handle getHandle.
            write unsignedLongAt: 25 put: bindingIndex.
            write unsignedLongAt: 29 put: 0.
            write unsignedLongAt: 33 put: 1.
            write unsignedLongAt: 37 put: VkDescriptorType storageBuffer.
            write pointerAt: 41 put: ExternalAddress null.
            write pointerAt: 49 put: bufInfo.
            write pointerAt: 57 put: ExternalAddress null.
            Vk updateDescriptorSets: device handle descriptorWriteCount: 1
                pDescriptorWrites: write descriptorCopyCount: 0 pDescriptorCopies: ExternalAddress null
        ] ensure: [ write free ]
    ] ensure: [ bufInfo free ]
]
