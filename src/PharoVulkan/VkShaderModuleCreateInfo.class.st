"
The request `vkCreateShaderModule` reads: a chain header, creation flags, and the byte count and address of the SPIR-V words to load. `initializeConstantFields` stamps the structure type, which is the only field fixed by the type. `codeWordByteCount` names the four bytes a word takes, because `pCode` points at 32-bit words and Vulkan requires `codeSize` to be a multiple of that. `VkShaderModule >> handleForCode:` is its one writer; the code itself must live outside object memory, since the driver reads it through the pointer and the garbage collector may move a store inside the image.
"
Class {
	#name : 'VkShaderModuleCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_CODESIZE',
		'OFFSET_FLAGS',
		'OFFSET_PCODE',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'constants' }
VkShaderModuleCreateInfo class >> codeWordByteCount [
	"pCode points at 32-bit words, so Vulkan requires codeSize to be a multiple of four. The
	 number is the same as the SPIR-V word size the compiler works in, but the rule is the
	 structure's own: it holds for any code handed through this field."

	^ 4
]

{ #category : 'field definition' }
VkShaderModuleCreateInfo class >> fieldsDesc [
	^ #( int32 sType; void* pNext; uint32 flags; uint64 codeSize; void* pCode )
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> codeSize [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_CODESIZE
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> codeSize: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_CODESIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkShaderModuleCreateInfo >> initializeConstantFields [
	"The structure type is all this request knows before a caller hands it code. The flags,
	 the byte count and the pointer stay as the zeroed block left them, which is no code at
	 all."

	self sType: VkStructureType shaderModuleCreateInfo
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> pCode [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PCODE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> pCode: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PCODE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkShaderModuleCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
