"
Vulkan struct passed to vkCreateInstance. Links to VkApplicationInfo
and declares required layers and extensions. initialize zeros all counts automatically.
Key methods: pApplicationInfo:, enabledExtensionCount:, ppEnabledExtensionNames:.
"
Class {
	#name : 'VkInstanceCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ENABLEDEXTENSIONCOUNT',
		'OFFSET_ENABLEDLAYERCOUNT',
		'OFFSET_FLAGS',
		'OFFSET_PAPPLICATIONINFO',
		'OFFSET_PNEXT',
		'OFFSET_PPENABLEDEXTENSIONNAMES',
		'OFFSET_PPENABLEDLAYERNAMES',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'fields' }
VkInstanceCreateInfo class >> fieldsDesc [
    ^ #(
        int32  sType;
        void*  pNext;
        uint32 flags;
        VkApplicationInfo* pApplicationInfo;
        uint32 enabledLayerCount;
        void*  ppEnabledLayerNames;
        uint32 enabledExtensionCount;
        void*  ppEnabledExtensionNames
    )
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> enabledExtensionCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ENABLEDEXTENSIONCOUNT
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> enabledExtensionCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ENABLEDEXTENSIONCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> enabledLayerCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ENABLEDLAYERCOUNT
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> enabledLayerCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ENABLEDLAYERCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkInstanceCreateInfo >> initialize [
    super initialize.
    self sType: VkStructureType instanceCreateInfo.
    self pNext: ExternalAddress null.
    self flags: 0.
    self enabledLayerCount: 0.
    self ppEnabledLayerNames: ExternalAddress null.
    self enabledExtensionCount: 0.
    self ppEnabledExtensionNames: ExternalAddress null
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> pApplicationInfo [
	"This method was automatically generated"
	^VkApplicationInfo fromHandle: (handle pointerAt: OFFSET_PAPPLICATIONINFO)
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> pApplicationInfo: anObject [
	"This method was automatically generated"

	handle pointerAt: OFFSET_PAPPLICATIONINFO put: anObject getHandle
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> pNext: anObject [
	"This method was automatically generated"

	handle pointerAt: OFFSET_PNEXT put: anObject getHandle
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> ppEnabledExtensionNames [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PPENABLEDEXTENSIONNAMES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> ppEnabledExtensionNames: anObject [
	"This method was automatically generated"

	handle
		pointerAt: OFFSET_PPENABLEDEXTENSIONNAMES
		put: anObject getHandle
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> ppEnabledLayerNames [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PPENABLEDLAYERNAMES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> ppEnabledLayerNames: anObject [
	"This method was automatically generated"

	handle pointerAt: OFFSET_PPENABLEDLAYERNAMES put: anObject getHandle
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkInstanceCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
