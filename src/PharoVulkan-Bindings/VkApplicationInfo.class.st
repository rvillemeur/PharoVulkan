"
Vulkan struct providing application metadata to vkCreateInstance.
initialize sets sType to VkStructureType applicationInfo automatically.
Key methods: pApplicationName:, applicationVersion:, apiVersion:.
"
Class {
	#name : 'VkApplicationInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_APIVERSION',
		'OFFSET_APPLICATIONVERSION',
		'OFFSET_ENGINEVERSION',
		'OFFSET_PAPPLICATIONNAME',
		'OFFSET_PENGINENAME',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkApplicationInfo class >> fieldsDesc [
    ^ #(
        int32  sType;
        void*  pNext;
        char*  pApplicationName;
        uint32 applicationVersion;
        char*  pEngineName;
        uint32 engineVersion;
        uint32 apiVersion
    )
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> apiVersion [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_APIVERSION
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> apiVersion: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_APIVERSION put: anObject
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> applicationVersion [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_APPLICATIONVERSION
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> applicationVersion: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_APPLICATIONVERSION put: anObject
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> engineVersion [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ENGINEVERSION
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> engineVersion: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ENGINEVERSION put: anObject
]

{ #category : 'initialization' }
VkApplicationInfo >> initializeConstantFields [
	"The structure type and a cleared chain pointer. The names and versions are the caller's."

	self
		sType: VkStructureType applicationInfo;
		pNext: ExternalAddress null
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> pApplicationName [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PAPPLICATIONNAME) type: ExternalType char asPointerType
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> pApplicationName: anObject [
	"This method was automatically generated"

	handle pointerAt: OFFSET_PAPPLICATIONNAME put: anObject getHandle
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> pEngineName [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PENGINENAME) type: ExternalType char asPointerType
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> pEngineName: anObject [
	"This method was automatically generated"

	handle pointerAt: OFFSET_PENGINENAME put: anObject getHandle
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> pNext: anObject [
	"This method was automatically generated"

	handle pointerAt: OFFSET_PNEXT put: anObject getHandle
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkApplicationInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
