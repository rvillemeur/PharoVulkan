"
One element of the binding array a descriptor set layout is created from: which binding number the shader reads, what kind of descriptor sits there, how many of them, and which shader stages may see it. It carries no chain header, because it is an array element rather than a structure the driver is handed on its own, so it stamps no constant field either. `storageBufferAt:stages:` builds the one shape this project uses. Instances are built in object memory and copied into a contiguous external run with `VkStructure class >> externalArrayOf:` and `copyBytesInto:`, because the driver reads the array through a pointer and the garbage collector may move a store that lives inside the image.
"
Class {
	#name : 'VkDescriptorSetLayoutBinding',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BINDING',
		'OFFSET_DESCRIPTORCOUNT',
		'OFFSET_DESCRIPTORTYPE',
		'OFFSET_PIMMUTABLESAMPLERS',
		'OFFSET_STAGEFLAGS'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'constants' }
VkDescriptorSetLayoutBinding class >> descriptorsPerBinding [
	"Every binding this project declares names one buffer, not an array of them. An array
	 binding would need a count the caller chooses and a shader that indexes it."

	^ 1
]

{ #category : 'field definition' }
VkDescriptorSetLayoutBinding class >> fieldsDesc [
	^ #( uint32 binding; uint32 descriptorType; uint32 descriptorCount;
		uint32 stageFlags; void* pImmutableSamplers )
]

{ #category : 'instance creation' }
VkDescriptorSetLayoutBinding class >> storageBufferAt: aBindingIndex stages: stageFlags [
	"The one binding shape this project uses: a single storage buffer at a binding number,
	 visible to the given stages. The store lives in object memory; it is copied into an
	 external array when the layout it belongs to is created."

	^ self new
		  binding: aBindingIndex;
		  descriptorType: VkDescriptorType storageBuffer;
		  descriptorCount: self descriptorsPerBinding;
		  stageFlags: stageFlags;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> binding [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BINDING
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> binding: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BINDING put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> descriptorCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DESCRIPTORCOUNT
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> descriptorCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DESCRIPTORCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> descriptorType [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DESCRIPTORTYPE
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> descriptorType: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DESCRIPTORTYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> pImmutableSamplers [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PIMMUTABLESAMPLERS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> pImmutableSamplers: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PIMMUTABLESAMPLERS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> stageFlags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STAGEFLAGS
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutBinding >> stageFlags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STAGEFLAGS put: anObject
]
