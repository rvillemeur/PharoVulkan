"
The Vulkan memory model feature flags, chained onto a VkPhysicalDeviceFeatures2 query or onto a VkDeviceCreateInfo feature chain. `vulkanMemoryModel` matters to this project because spirv-val refuses a module that declares the Shader and CooperativeMatrixKHR capabilities without also declaring VulkanMemoryModel, and that capability may only be declared when the device has this feature enabled. `VkPhysicalDevice >> supportsVulkanMemoryModel` asks with it; `VkContext` enables it alongside cooperative matrix.
"
Class {
	#name : 'VkPhysicalDeviceVulkanMemoryModelFeatures',
	#superclass : 'VkFeatureStructure',
	#classVars : [
		'OFFSET_PNEXT',
		'OFFSET_STYPE',
		'OFFSET_VULKANMEMORYMODEL',
		'OFFSET_VULKANMEMORYMODELAVAILABILITYVISIBILITYCHAINS',
		'OFFSET_VULKANMEMORYMODELDEVICESCOPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPhysicalDeviceVulkanMemoryModelFeatures class >> exampleVulkanMemoryModelOfThisMachine [
	"One click: the memory model flags of the device a plain compute context lands on, copied
	 out of the chain before that memory was freed. A device that reports the model usually
	 reports the device scope and the availability-visibility chains with it."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  VkPhysicalDeviceFeatures2
		  of: context physicalDevice handle
		  chainedWith: self
		  do: [ :head :features | features copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]

{ #category : 'field definition' }
VkPhysicalDeviceVulkanMemoryModelFeatures class >> fieldsDesc [
	"The three VkBool32 members are declared as the uint32 they are."

	^ #(
		uint32 sType;
		void *pNext;
		uint32 vulkanMemoryModel;
		uint32 vulkanMemoryModelDeviceScope;
		uint32 vulkanMemoryModelAvailabilityVisibilityChains
	)
]

{ #category : 'constants' }
VkPhysicalDeviceVulkanMemoryModelFeatures class >> structureType [
	^ VkStructureType physicalDeviceVulkanMemoryModelFeatures
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> sType [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> sType: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> vulkanMemoryModel [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VULKANMEMORYMODEL
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> vulkanMemoryModel: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VULKANMEMORYMODEL put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> vulkanMemoryModelAvailabilityVisibilityChains [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VULKANMEMORYMODELAVAILABILITYVISIBILITYCHAINS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> vulkanMemoryModelAvailabilityVisibilityChains: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VULKANMEMORYMODELAVAILABILITYVISIBILITYCHAINS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> vulkanMemoryModelDeviceScope [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VULKANMEMORYMODELDEVICESCOPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceVulkanMemoryModelFeatures >> vulkanMemoryModelDeviceScope: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VULKANMEMORYMODELDEVICESCOPE put: anObject
]
