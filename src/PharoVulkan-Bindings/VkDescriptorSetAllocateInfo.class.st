"
VkDescriptorSetAllocateInfo, the allocate info vkAllocateDescriptorSets reads. Declared field by field, so uFFI computes every offset including the four byte hole it puts between descriptorSetCount and the eight byte aligned pSetLayouts; the struct is forty bytes. descriptorPool is a handle and therefore pointer wide, not a count. pSetLayouts points at an array of descriptorSetCount set layout handles rather than at one handle, which is why VkDescriptorPool builds that array separately and frees it after the driver has read it. initialize names the structure type and clears the chain pointer, and FFIStructure class >> fromHandle: sends it, so an instance from externalInstance is as ready as one from new; VkDescriptorPool >> allocateSet: writes only the pool, the count and the array. Key methods: descriptorPool:, descriptorSetCount:, pSetLayouts:, layoutRows.
"
Class {
	#name : 'VkDescriptorSetAllocateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DESCRIPTORPOOL',
		'OFFSET_DESCRIPTORSETCOUNT',
		'OFFSET_PNEXT',
		'OFFSET_PSETLAYOUTS',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkDescriptorSetAllocateInfo class >> fieldsDesc [
	"VkDescriptorSetAllocateInfo, read by vkAllocateDescriptorSets. descriptorPool is a handle,
	 so it is pointer wide; pNext, descriptorPool and pSetLayouts are all eight byte aligned,
	 which makes uFFI put a four byte hole between descriptorSetCount and pSetLayouts by
	 itself. The struct is forty bytes. pSetLayouts points at an array of descriptorSetCount
	 layout handles, not at one handle."
	^ #(
		int32 sType;
		void* pNext;
		VkDescriptorPool_H* descriptorPool;
		uint32 descriptorSetCount;
		void* pSetLayouts
	)
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorPool [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_DESCRIPTORPOOL) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorPool: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_DESCRIPTORPOOL put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorSetCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DESCRIPTORSETCOUNT
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorSetCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DESCRIPTORSETCOUNT put: anObject
]

{ #category : 'initialization' }
VkDescriptorSetAllocateInfo >> initializeConstantFields [
	"The structure type that tells the driver what this block of bytes is, and a cleared chain
	 pointer. The pool, the count and the layout array are the caller's to write."

	self
		sType: VkStructureType descriptorSetAllocateInfo;
		pNext: ExternalAddress null
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pSetLayouts [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSETLAYOUTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pSetLayouts: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSETLAYOUTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
