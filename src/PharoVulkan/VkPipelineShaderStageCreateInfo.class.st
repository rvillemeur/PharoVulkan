"
VkPipelineShaderStageCreateInfo: one shader stage of a pipeline — which stage it is, the module the code comes from, the entry point in that module and an optional specialization. Declared field by field, so uFFI computes all seven offsets; the structure is forty-eight bytes, with the padding after the flags and stage pair that puts the module handle on a pointer boundary.

This project carries it nested by value inside VkComputePipelineCreateInfo at byte twenty-four, so it declares no initializeConstantFields even though its sType is fixed by its type: the generated getter for a nested field answers the stage through fromHandle:, which runs initialize on every read of the field, and an initializer would therefore write into the enclosing request each time it is read. VkComputePipeline class >> createInfoForModule:entryPoint:layout: writes the type along with the rest, and VkComputePipeline class >> freeEntryPointOf: gives back the C string pName points at. See VkStructure >> initialize.
"
Class {
	#name : 'VkPipelineShaderStageCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_MODULE',
		'OFFSET_PNAME',
		'OFFSET_PNEXT',
		'OFFSET_PSPECIALIZATIONINFO',
		'OFFSET_STAGE',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPipelineShaderStageCreateInfo class >> fieldsDesc [
	"One shader stage of a pipeline. flags and stage are a uint32 pair, so uFFI puts them at
	 sixteen and twenty and pads to twenty-four, where module — a handle, and therefore pointer
	 wide — can sit. pName points at a NUL terminated C string naming the entry point in that
	 module; pSpecializationInfo is optional and this project leaves it null, so it is declared
	 void* rather than naming a structure nothing builds."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 stage;
		VkShaderModule_H* module;
		void* pName;
		void* pSpecializationInfo
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> module [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_MODULE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> module: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_MODULE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pName [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNAME) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pName: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNAME put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pSpecializationInfo [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSPECIALIZATIONINFO) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pSpecializationInfo: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSPECIALIZATIONINFO put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> stage [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STAGE
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> stage: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STAGE put: anObject
]
