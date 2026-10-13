"
VkDescriptorPoolCreateInfo, the create info vkCreateDescriptorPool reads. Declared field by field, so uFFI computes every offset including the four byte hole it puts between poolSizeCount and the eight byte aligned pPoolSizes; the struct is forty bytes. maxSets and poolSizeCount are the two counts that used to be one number: maxSets bounds the sets allocated out of the pool, poolSizeCount says how many VkDescriptorPoolSize entries pPoolSizes points at. initialize names the structure type and clears the chain pointer, and FFIStructure class >> fromHandle: sends it, so an instance from externalInstance is as ready as one from new. VkDescriptorPool >> create:descriptorCount: writes only the counts and the pointer. Key methods: maxSets:, poolSizeCount:, pPoolSizes:, layoutRows.
"
Class {
	#name : 'VkDescriptorPoolCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_MAXSETS',
		'OFFSET_PNEXT',
		'OFFSET_POOLSIZECOUNT',
		'OFFSET_PPOOLSIZES',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDescriptorPoolCreateInfo class >> exampleForOneSetOfThreeDescriptors [
	"One click: the create info VkDescriptorPool writes for a three-buffer compute kernel, with
	 the two counts that used to be one number side by side in the Layout tab. pPoolSizes stays
	 null: an example answers an object that outlives the call, and a pointer to a store this
	 example does not own would be read after that store has gone. The live pointer is covered
	 by VkBindingsTest and by VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers."
	<sampleInstance>
	^ self new
		  maxSets: VkDescriptorPool exampleMaxSets;
		  poolSizeCount: VkDescriptorPool poolSizeCount;
		  yourself
]

{ #category : 'field definition' }
VkDescriptorPoolCreateInfo class >> fieldsDesc [
	"VkDescriptorPoolCreateInfo. pNext and pPoolSizes are eight byte aligned, so uFFI puts a
	 four byte hole between poolSizeCount and pPoolSizes by itself; the struct is forty bytes.
	 maxSets and poolSizeCount are the two counts that used to be one number."
	^ #(
		int32  sType;
		void*  pNext;
		uint32 flags;
		uint32 maxSets;
		uint32 poolSizeCount;
		VkDescriptorPoolSize* pPoolSizes
	)
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkDescriptorPoolCreateInfo >> initializeConstantFields [
	"A create info carries its own sType and no chained structure, so an instance is valid
	 before any count is set. The counts and the flags are left as the zeroed store has them,
	 which is a pool the driver refuses rather than one that looks usable."

	self
		sType: VkStructureType descriptorPoolCreateInfo;
		pNext: ExternalAddress null
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> maxSets [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXSETS
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> maxSets: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXSETS put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> pPoolSizes [
	"This method was automatically generated"
	^VkDescriptorPoolSize fromHandle: (handle pointerAt: OFFSET_PPOOLSIZES)
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> pPoolSizes: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PPOOLSIZES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> poolSizeCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_POOLSIZECOUNT
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> poolSizeCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_POOLSIZECOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkDescriptorPoolCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
