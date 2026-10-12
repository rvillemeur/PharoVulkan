"
One VkDescriptorPoolSize: how many descriptors of one type a descriptor pool holds. Declared field by field, so both offsets come from the specification uFFI compiled rather than from bytes counted by hand in the method that writes it. Every descriptor in this project's pools is a storage buffer, so one of these is written per pool; VkDescriptorPool class >> descriptorType decides the type and VkDescriptorPool class >> poolSizeCount how many of these the create info points at. Key methods: type:, descriptorCount:, layoutRows.
"
Class {
	#name : 'VkDescriptorPoolSize',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DESCRIPTORCOUNT',
		'OFFSET_TYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDescriptorPoolSize class >> exampleThreeStorageBufferDescriptors [
	"One click: the pool size a three-buffer compute kernel asks for. Built in object memory,
	 so nothing has to be freed, and rebuilt on every call. The counts come from
	 VkDescriptorPool rather than from literals here, so the example follows the pool."
	<sampleInstance>
	^ self new
		  type: VkDescriptorPool descriptorType;
		  descriptorCount: VkDescriptorPool exampleDescriptorCount;
		  yourself
]

{ #category : 'field definition' }
VkDescriptorPoolSize class >> fieldsDesc [
	"VkDescriptorPoolSize: how many descriptors of one type the pool holds. Both members are
	 uint32, so uFFI needs no pad to reach the C layout."
	^ #(
		uint32 type;
		uint32 descriptorCount
	)
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolSize >> descriptorCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DESCRIPTORCOUNT
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolSize >> descriptorCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DESCRIPTORCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolSize >> type [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TYPE
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolSize >> type: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TYPE put: anObject
]
