"
The VK_KHR_cooperative_matrix feature flags, chained onto a VkPhysicalDeviceFeatures2 query or onto a VkDeviceCreateInfo feature chain. `cooperativeMatrix` is the subgroup-wide matrix multiply the tiled matmul path uses when a device offers it; spirv-val refuses a module that declares the CooperativeMatrixKHR capability unless VulkanMemoryModel is declared too, so `VkContext >> buildOptionalFeatureChain` chains this structure and VkPhysicalDeviceVulkanMemoryModelFeatures together, and only where the device reports both. `VkPhysicalDevice >> supportsCooperativeMatrix` asks with it.
"
Class {
	#name : 'VkPhysicalDeviceCooperativeMatrixFeaturesKHR',
	#superclass : 'VkFeatureStructure',
	#classVars : [
		'OFFSET_COOPERATIVEMATRIX',
		'OFFSET_COOPERATIVEMATRIXROBUSTBUFFERACCESS',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR class >> fieldsDesc [
	"VkPhysicalDeviceCooperativeMatrixFeaturesKHR as the C header declares it. Robust buffer
	 access is left off by this project: a cooperative matrix kernel here reads only inside the
	 buffers it was given, and asking for the guarantee costs performance on devices that
	 bounds check in hardware."

	^ #(
		int32 sType;
		void* pNext;
		uint32 cooperativeMatrix;
		uint32 cooperativeMatrixRobustBufferAccess
	)
]

{ #category : 'constants' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR class >> structureType [
	"The one VkStructureType constant that names this structure, so a builder and an
	 example both ask the same place for it."

	^ VkStructureType physicalDeviceCooperativeMatrixFeaturesKHR
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> cooperativeMatrix [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_COOPERATIVEMATRIX
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> cooperativeMatrix: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_COOPERATIVEMATRIX put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> cooperativeMatrixRobustBufferAccess [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_COOPERATIVEMATRIXROBUSTBUFFERACCESS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> cooperativeMatrixRobustBufferAccess: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_COOPERATIVEMATRIXROBUSTBUFFERACCESS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceCooperativeMatrixFeaturesKHR >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
