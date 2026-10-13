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
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'constants' }
VkDescriptorSet class >> copiesPerUpdate [
	"No descriptor is copied from another set, so vkUpdateDescriptorSets is told to read no
	 copies and is given a null pointer for them."
	^ 0
]

{ #category : 'constants' }
VkDescriptorSet class >> descriptorsPerWrite [
	"One descriptor is updated per write: a binding in this project holds one storage buffer,
	 not an array of them. The write's descriptorCount and the number of buffer infos it
	 points at are both this, so they cannot disagree."
	^ 1
]

{ #category : 'constants' }
VkDescriptorSet class >> firstBinding [
	"Binding zero, the first binding of a set. Named because zero is a real binding here and
	 not an absent value: a write that leaves dstBinding at zero updates this one."
	^ 0
]

{ #category : 'constants' }
VkDescriptorSet class >> writesPerUpdate [
	"One VkWriteDescriptorSet is sent per call, so vkUpdateDescriptorSets is told to read one."
	^ 1
]

{ #category : 'private' }
VkDescriptorSet >> bufferInfoOutsideObjectMemoryFor: aBuffer [
	"The buffer info this write points at, declared field by field so uFFI computes its three
	 offsets. The whole buffer from its start is named here rather than in initialize, because
	 a getter for a field pointing at this type would otherwise write the range back on every
	 read. The store is outside object memory because the write holds a pointer to it: a store
	 inside the image could be moved by the garbage collector between that pointer being
	 written and the driver reading it. The caller frees it."

	^ VkDescriptorBufferInfo externalInstance
		  buffer: aBuffer handle;
		  range: VkDescriptorBufferInfo wholeSize;
		  yourself
]

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

{ #category : 'private' }
VkDescriptorSet >> updateBinding: aBindingIndex fromBufferInfo: aBufferInfo [
	"The write, filled through the accessors uFFI generated, so no offset is counted here.
	 externalInstance runs initialize, so the structure type and the null chain pointer are
	 already in place and only the set, the binding, the count, the type and the pointer are
	 written. The descriptor type is the one the pool holds, asked rather than restated, so a
	 write cannot name a type the set was never allocated for. Its store is freed as soon as
	 the driver has read it; the buffer info it points at belongs to the caller."

	| write |
	write := VkWriteDescriptorSet externalInstance
		         dstSet: handle;
		         dstBinding: aBindingIndex;
		         descriptorCount: self class descriptorsPerWrite;
		         descriptorType: VkDescriptorPool descriptorType;
		         pBufferInfo: aBufferInfo;
		         yourself.
	^ [
	  Vk
		  updateDescriptorSets: device handle
		  descriptorWriteCount: self class writesPerUpdate
		  pDescriptorWrites: write getHandle
		  descriptorCopyCount: self class copiesPerUpdate
		  pDescriptorCopies: ExternalAddress null ] ensure: [ write getHandle free ]
]

{ #category : 'updating' }
VkDescriptorSet >> updateStorageBuffer: aBuffer atBinding: aBindingIndex [
	"Point the descriptor at the given binding of this set at the whole of the given buffer.
	 The buffer info outlives the write that points at it and is freed here, after the driver
	 has read both."

	| info |
	info := self bufferInfoOutsideObjectMemoryFor: aBuffer.
	^ [ self updateBinding: aBindingIndex fromBufferInfo: info ]
		  ensure: [ info getHandle free ]
]
