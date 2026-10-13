"
The sixteen bit storage feature flags, one per place a half float may live: a storage buffer, a uniform buffer, a push constant, a shader input or output. Chained onto a VkPhysicalDeviceFeatures2 query or onto a VkDeviceCreateInfo feature chain. `storageBuffer16BitAccess` is the one the f16 compute path needs, because its half data arrives in a storage buffer; arithmetic on those halves is a separate feature, so `VkContext >> buildHalfPrecisionFeatures` chains this structure together with VkPhysicalDeviceShaderFloat16Int8Features.
"
Class {
	#name : 'VkPhysicalDevice16BitStorageFeatures',
	#superclass : 'VkFeatureStructure',
	#classVars : [
		'OFFSET_PNEXT',
		'OFFSET_STORAGEBUFFER16BITACCESS',
		'OFFSET_STORAGEINPUTOUTPUT16',
		'OFFSET_STORAGEPUSHCONSTANT16',
		'OFFSET_STYPE',
		'OFFSET_UNIFORMANDSTORAGEBUFFER16BITACCESS'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPhysicalDevice16BitStorageFeatures class >> exampleSixteenBitStorageOfThisMachine [
	"One click: the places the device a plain compute context lands on lets a half float
	 live, copied out of the chain before that memory was freed. storageBuffer16BitAccess is
	 the one the f16 compute path needs; a device may well report that one and refuse half
	 floats in uniforms, push constants and interface variables."

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
VkPhysicalDevice16BitStorageFeatures class >> fieldsDesc [
	"VkPhysicalDevice16BitStorageFeatures as the C header declares it: four VkBool32 flags for
	 the four places a sixteen bit type may appear. This project asks for the storage buffer
	 one, which is what a half precision kernel reads and writes its buffers with."

	^ #(
		int32 sType;
		void* pNext;
		uint32 storageBuffer16BitAccess;
		uint32 uniformAndStorageBuffer16BitAccess;
		uint32 storagePushConstant16;
		uint32 storageInputOutput16
	)
]

{ #category : 'constants' }
VkPhysicalDevice16BitStorageFeatures class >> structureType [
	"The one VkStructureType constant that names this structure, so a builder and an
	 example both ask the same place for it."

	^ VkStructureType physicalDevice16BitStorageFeatures
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> storageBuffer16BitAccess [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STORAGEBUFFER16BITACCESS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> storageBuffer16BitAccess: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STORAGEBUFFER16BITACCESS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> storageInputOutput16 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STORAGEINPUTOUTPUT16
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> storageInputOutput16: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STORAGEINPUTOUTPUT16 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> storagePushConstant16 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STORAGEPUSHCONSTANT16
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> storagePushConstant16: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STORAGEPUSHCONSTANT16 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> uniformAndStorageBuffer16BitAccess [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_UNIFORMANDSTORAGEBUFFER16BITACCESS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDevice16BitStorageFeatures >> uniformAndStorageBuffer16BitAccess: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_UNIFORMANDSTORAGEBUFFER16BITACCESS put: anObject
]
