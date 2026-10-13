"
The half precision and eight bit integer arithmetic feature flags, chained onto a VkPhysicalDeviceFeatures2 query or onto a VkDeviceCreateInfo feature chain. `shaderFloat16` is what the f16 compute path needs: a module may declare the Float16 capability only on a device that reports it. Arithmetic on half floats and storage of half floats are separate features, so `VkContext >> buildHalfPrecisionFeatures` chains this structure together with VkPhysicalDevice16BitStorageFeatures and enables both.
"
Class {
	#name : 'VkPhysicalDeviceShaderFloat16Int8Features',
	#superclass : 'VkFeatureStructure',
	#classVars : [
		'OFFSET_PNEXT',
		'OFFSET_SHADERFLOAT16',
		'OFFSET_SHADERINT8',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPhysicalDeviceShaderFloat16Int8Features class >> exampleShaderArithmeticWidthsOfThisMachine [
	"One click: whether the device a plain compute context lands on can compute with half
	 floats and with eight bit integers, copied out of the chain before that memory was
	 freed. shaderFloat16 is the flag the f16 compute path needs; holding halves in a buffer
	 is a separate feature, over in VkPhysicalDevice16BitStorageFeatures."

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
VkPhysicalDeviceShaderFloat16Int8Features class >> fieldsDesc [
	"VkPhysicalDeviceShaderFloat16Int8Features as the C header declares it. Both flags are
	 VkBool32; this project asks for shaderFloat16 and leaves shaderInt8 off, which is why the
	 second one is declared rather than left to whatever the block held."

	^ #(
		int32 sType;
		void* pNext;
		uint32 shaderFloat16;
		uint32 shaderInt8
	)
]

{ #category : 'constants' }
VkPhysicalDeviceShaderFloat16Int8Features class >> structureType [
	"The one VkStructureType constant that names this structure, so a builder and an
	 example both ask the same place for it."

	^ VkStructureType physicalDeviceShaderFloat16Int8Features
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> shaderFloat16 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERFLOAT16
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> shaderFloat16: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERFLOAT16 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> shaderInt8 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERINT8
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceShaderFloat16Int8Features >> shaderInt8: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERINT8 put: anObject
]
