"
The request `vkCreateDescriptorSetLayout` reads: a chain header, creation flags, and a count and pointer naming the `VkDescriptorSetLayoutBinding` array that describes the set. `initializeConstantFields` stamps the structure type, which is the only field fixed by the type, so a fresh block reads as the empty layout — no flag, no binding, and a null array pointer, which is what Vulkan expects for a layout with no binding. `VkDescriptorSetLayout >> create` is its one writer.
"
Class {
	#name : 'VkDescriptorSetLayoutCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BINDINGCOUNT',
		'OFFSET_FLAGS',
		'OFFSET_PBINDINGS',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkDescriptorSetLayoutCreateInfo class >> fieldsDesc [
	^ #( int32 sType; void* pNext; uint32 flags; uint32 bindingCount;
		void* pBindings )
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> bindingCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BINDINGCOUNT
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> bindingCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BINDINGCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkDescriptorSetLayoutCreateInfo >> initializeConstantFields [
	"The structure type is all this request knows before a caller describes the set. The flags,
	 the binding count and the array pointer stay as the zeroed block left them, which is the
	 layout with no binding."

	self sType: VkStructureType descriptorSetLayoutCreateInfo
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> pBindings [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PBINDINGS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> pBindings: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PBINDINGS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetLayoutCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
