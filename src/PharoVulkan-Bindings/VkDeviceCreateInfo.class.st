"
A VkDeviceCreateInfo, declared field by field: seventy two bytes over offsets 0, 8, 16, 20, 24, 32, 40, 48, 56 and 64, each uint32 count sitting in the four bytes before a pointer and padded to it. One of these is handed to vkCreateDevice, and both device paths in this project build one: VkContext >> buildDeviceCreateInfo: asks the physical device what it offers and chains the optional feature structs accordingly, while VkContext >> buildGraphicsDeviceCreateInfo: asks for the swapchain extension and synchronization2 and nothing besides.

Only sType is constant for the type. pNext carries the feature chain, which differs per device, so initializeConstantFields must not write it: uFFI's getter for a field that points at a structure runs initialize over the pointee, which would clear a live chain. The array pointers are declared void* for the same reason, and because the arrays behind them are arrays of C strings and of queue create infos, not single structures, so they are walked by VkContext class >> pointerSize.

Everything a builder allocates is released by VkContext >> freeDeviceCreateInfo:, which reads the chain and the name array back through the accessors. Key methods: fieldsDesc (class side), initializeConstantFields. The Layout and Fields tabs come from VkStructure.
"
Class {
	#name : 'VkDeviceCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ENABLEDEXTENSIONCOUNT',
		'OFFSET_ENABLEDLAYERCOUNT',
		'OFFSET_FLAGS',
		'OFFSET_PENABLEDFEATURES',
		'OFFSET_PNEXT',
		'OFFSET_PPENABLEDEXTENSIONNAMES',
		'OFFSET_PPENABLEDLAYERNAMES',
		'OFFSET_PQUEUECREATEINFOS',
		'OFFSET_QUEUECREATEINFOCOUNT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkDeviceCreateInfo class >> fieldsDesc [
	"VkDeviceCreateInfo as the C header declares it. The three array pointers and
	 pQueueCreateInfos are declared void* rather than as pointers to their element types,
	 because uFFI's getter for a field pointing at a structure answers the pointee through
	 fromHandle:, which runs initialize over memory the driver is reading; nothing here needs a
	 typed getter, and the readers walk these arrays by stride anyway."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 queueCreateInfoCount;
		void* pQueueCreateInfos;
		uint32 enabledLayerCount;
		void* ppEnabledLayerNames;
		uint32 enabledExtensionCount;
		void* ppEnabledExtensionNames;
		void* pEnabledFeatures
	)
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> enabledExtensionCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ENABLEDEXTENSIONCOUNT
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> enabledExtensionCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ENABLEDEXTENSIONCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> enabledLayerCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ENABLEDLAYERCOUNT
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> enabledLayerCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ENABLEDLAYERCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkDeviceCreateInfo >> initializeConstantFields [
	"Only the structure type. pNext carries the feature chain the context built for the device
	 it selected, which is data and not constant for the type, so writing it here would clear a
	 chain on every read of a field that points at one of these."

	self sType: VkStructureType deviceCreateInfo
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> pEnabledFeatures [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PENABLEDFEATURES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> pEnabledFeatures: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PENABLEDFEATURES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> pQueueCreateInfos [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PQUEUECREATEINFOS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> pQueueCreateInfos: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PQUEUECREATEINFOS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> ppEnabledExtensionNames [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PPENABLEDEXTENSIONNAMES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> ppEnabledExtensionNames: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PPENABLEDEXTENSIONNAMES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> ppEnabledLayerNames [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PPENABLEDLAYERNAMES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> ppEnabledLayerNames: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PPENABLEDLAYERNAMES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> queueCreateInfoCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUECREATEINFOCOUNT
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> queueCreateInfoCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUECREATEINFOCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkDeviceCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
