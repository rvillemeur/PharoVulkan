"
VkWriteDescriptorSet, the write vkUpdateDescriptorSets reads: it points a binding of one descriptor set at a resource. Declared field by field, so uFFI computes every offset; the struct is sixty four bytes, and the four uint32 members fill the sixteen bytes between the pointer wide dstSet and the three eight byte aligned pointer members exactly, so there is no hole. A write names exactly one of pImageInfo, pBufferInfo and pTexelBufferView and leaves the other two null; this project writes storage buffers, so pBufferInfo is the one that is set. initializeConstantFields names the structure type and clears the chain pointer, so VkDescriptorSet >> updateBinding:fromBufferInfo: writes only the set, the binding, the count, the type and the pointer. Key methods: dstSet:, dstBinding:, descriptorCount:, descriptorType:, pBufferInfo:, layoutRows, fieldReport.
"
Class {
	#name : 'VkWriteDescriptorSet',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DESCRIPTORCOUNT',
		'OFFSET_DESCRIPTORTYPE',
		'OFFSET_DSTARRAYELEMENT',
		'OFFSET_DSTBINDING',
		'OFFSET_DSTSET',
		'OFFSET_PBUFFERINFO',
		'OFFSET_PIMAGEINFO',
		'OFFSET_PNEXT',
		'OFFSET_PTEXELBUFFERVIEW',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkWriteDescriptorSet class >> exampleStorageBufferAtFirstBinding [
	"One click: the write a compute kernel sends for the storage buffer at its first binding,
	 with the structure type, the binding, the count and the descriptor type side by side in
	 the Request tab. The counts and the type come from VkDescriptorSet and VkDescriptorPool
	 rather than from literals here, so the example follows the code that writes the real one.
	 dstSet and pBufferInfo stay null, because an example must not hold a pointer to a store it
	 does not own; the live pointers are covered by VkBindingsTest and by
	 VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers."
	<sampleInstance>
	^ self new
		  dstBinding: VkDescriptorSet firstBinding;
		  descriptorCount: VkDescriptorSet descriptorsPerWrite;
		  descriptorType: VkDescriptorPool descriptorType;
		  yourself
]

{ #category : 'field definition' }
VkWriteDescriptorSet class >> fieldsDesc [
	"VkWriteDescriptorSet, read by vkUpdateDescriptorSets. dstSet is a handle and therefore
	 pointer wide. The three counts and the descriptor type are uint32 and fill the sixteen
	 bytes between dstSet and the three eight byte aligned pointer members exactly, so uFFI
	 needs no pad and the struct is sixty four bytes. A descriptor write names one of
	 pImageInfo, pBufferInfo or pTexelBufferView and leaves the other two null; this project
	 writes storage buffers, so pBufferInfo is the one that is set."
	^ #(
		int32 sType;
		void* pNext;
		VkDescriptorSet_H* dstSet;
		uint32 dstBinding;
		uint32 dstArrayElement;
		uint32 descriptorCount;
		int32 descriptorType;
		void* pImageInfo;
		VkDescriptorBufferInfo* pBufferInfo;
		void* pTexelBufferView
	)
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> descriptorCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DESCRIPTORCOUNT
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> descriptorCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DESCRIPTORCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> descriptorType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_DESCRIPTORTYPE
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> descriptorType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_DESCRIPTORTYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> dstArrayElement [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DSTARRAYELEMENT
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> dstArrayElement: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DSTARRAYELEMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> dstBinding [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DSTBINDING
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> dstBinding: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DSTBINDING put: anObject
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> dstSet [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_DSTSET) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> dstSet: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_DSTSET put: anObject getHandle.
]

{ #category : 'initialization' }
VkWriteDescriptorSet >> initializeConstantFields [
	"The two members the driver reads before any of ours: the structure type that says what
	 this block of bytes is, and a cleared chain pointer. The three pointers to descriptor
	 detail stay null, because a write names exactly one of them and the zeroed store leaves
	 the other two as the driver expects."

	self
		sType: VkStructureType writeDescriptorSet;
		pNext: ExternalAddress null
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pBufferInfo [
	"This method was automatically generated"
	^VkDescriptorBufferInfo fromHandle: (handle pointerAt: OFFSET_PBUFFERINFO)
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pBufferInfo: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PBUFFERINFO put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pImageInfo [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PIMAGEINFO) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pImageInfo: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PIMAGEINFO put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pTexelBufferView [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PTEXELBUFFERVIEW) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> pTexelBufferView: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PTEXELBUFFERVIEW put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkWriteDescriptorSet >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
