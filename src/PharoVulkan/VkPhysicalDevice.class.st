"
Wrapper around a VkPhysicalDevice_H. Queries queue family properties, locates compute or graphics+compute queue families, and selects memory type indices for allocations. Key methods: findComputeQueueFamily, findGraphicsQueueFamily, findMemoryType:properties:.
"
Class {
	#name : 'VkPhysicalDevice',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'queueFamilyProps',
		'memoryProperties',
		'extensionNames'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'decoding' }
VkPhysicalDevice class >> extensionNameIn: aBuffer at: anOffset [
    "The name field is a fixed 256 bytes holding a NUL-terminated string, so stop at the
     terminator rather than at the field width or the name carries its padding."
    | stream byte |
    stream := WriteStream on: String new.
    1 to: self extensionNameMaxLength do: [ :i |
        byte := aBuffer byteAt: anOffset + i.
        byte = 0 ifTrue: [ ^ stream contents ].
        stream nextPut: (Character value: byte) ].
    ^ stream contents
]

{ #category : 'constants' }
VkPhysicalDevice class >> extensionNameMaxLength [
    ^ 256
]

{ #category : 'constants' }
VkPhysicalDevice class >> extensionNamePrefix [
    "Every Vulkan extension name starts with this, so a name without it never came from a driver."
    ^ 'VK_'
]

{ #category : 'constants' }
VkPhysicalDevice class >> extensionPropertiesSize [
    "VkExtensionProperties: char extensionName[256] followed by uint32 specVersion."
    ^ 260
]

{ #category : 'factory' }
VkPhysicalDevice class >> on: aHandle [
    ^ self new initializeWith: aHandle
]

{ #category : 'as yet unclassified' }
VkPhysicalDevice >> extensionNames [
	"Fetched on demand: the compute path needs the list only to gate optional features, and
	 the graphics path never asks."

	^ extensionNames ifNil: [ self fetchExtensionNames ]
]

{ #category : 'as yet unclassified' }
VkPhysicalDevice >> fetchExtensionNames [
	"vkEnumerateDeviceExtensionProperties is a two-call query: once for the count, once for
	 the array."

	| countBuf |
	countBuf := ExternalAddress allocate: 4.
	extensionNames := [
	                  Vk checkResult: (Vk
			                   primEnumerateDeviceExtensionProperties: handle
			                   layerName: ExternalAddress null
			                   count: countBuf
			                   props: ExternalAddress null).
	                  self readExtensionNames: (countBuf unsignedLongAt: 1) count: countBuf ]
		                  ensure: [ countBuf free ].
	^ extensionNames
]

{ #category : 'initialization' }
VkPhysicalDevice >> fetchMemoryProperties [
    memoryProperties := ExternalAddress allocate: 520.
    Vk getPhysicalDeviceMemoryProperties: handle memoryProperties: memoryProperties
]

{ #category : 'accessing' }
VkPhysicalDevice >> fetchQueueFamilyProperties [

	| countBuf count propsBuf propSize |
	propSize := 24.
	countBuf := ExternalAddress allocate: 4.
	queueFamilyProps := [
		                    Vk
			                    primGetQueueFamilyProperties: handle
			                    count: countBuf
			                    props: ExternalAddress null.
		                    count := countBuf unsignedLongAt: 1.
		                    propsBuf := ExternalAddress allocate:
			                                count * propSize.
		                    [
			                    Vk
				                    primGetQueueFamilyProperties: handle
				                    count: countBuf
				                    props: propsBuf.
			                    (1 to: count) collect: [ :i |
					                    | base |
					                    base := i - 1 * propSize.
					                    propsBuf unsignedLongAt: base + 1 ] ]
			                    ensure: [ propsBuf free ] ] ensure: [
		                    countBuf free ]
]

{ #category : 'querying' }
VkPhysicalDevice >> findComputeQueueFamily [
    "VK_QUEUE_COMPUTE_BIT = 2"
    queueFamilyProps doWithIndex: [ :flags :i |
        (flags bitAnd: 2) ~= 0 ifTrue: [ ^ i - 1 ] ].
    ^ nil
]

{ #category : 'querying' }
VkPhysicalDevice >> findGraphicsQueueFamily [
    "VK_QUEUE_GRAPHICS_BIT=1, VK_QUEUE_COMPUTE_BIT=2. Prefer a family with both."
    queueFamilyProps doWithIndex: [ :flags :i |
        ((flags bitAnd: 3) = 3) ifTrue: [ ^ i - 1 ] ].
    "Fall back: graphics only"
    queueFamilyProps doWithIndex: [ :flags :i |
        ((flags bitAnd: 1) ~= 0) ifTrue: [ ^ i - 1 ] ].
    ^ nil
]

{ #category : 'querying' }
VkPhysicalDevice >> findMemoryType: typeFilter properties: requiredFlags [
    "memoryTypes array starts at offset 4 in VkPhysicalDeviceMemoryProperties,"
    "each VkMemoryType = 8 bytes: propertyFlags(4) + heapIndex(4)"
    | typeCount |
    typeCount := memoryProperties unsignedLongAt: 1.
    0 to: typeCount - 1 do: [ :i |
        ((typeFilter bitAnd: (1 bitShift: i)) ~= 0) ifTrue: [
            | propFlags |
            propFlags := memoryProperties unsignedLongAt: 5 + (i * 8).
            (propFlags bitAnd: requiredFlags) = requiredFlags
                ifTrue: [ ^ i ] ] ].
    VkError signal: 'No suitable memory type found'
]

{ #category : 'accessing' }
VkPhysicalDevice >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkPhysicalDevice >> initializeWith: aHandle [
    handle := aHandle.
    self fetchQueueFamilyProperties.
    self fetchMemoryProperties
]

{ #category : 'as yet unclassified' }
VkPhysicalDevice >> readExtensionNames: aCount count: countBuf [
	"The driver reports no extensions at all on a bare software device, which is a list of
	 none rather than an error."

	| propsBuf stride |
	aCount = 0 ifTrue: [ ^ #() ].
	stride := self class extensionPropertiesSize.
	propsBuf := ExternalAddress allocate: aCount * stride.
	^ [
	  Vk checkResult: (Vk
			   primEnumerateDeviceExtensionProperties: handle
			   layerName: ExternalAddress null
			   count: countBuf
			   props: propsBuf).
	  (1 to: aCount) collect: [ :i |
		  self class extensionNameIn: propsBuf at: i - 1 * stride ] ]
		  ensure: [ propsBuf free ]
]

{ #category : 'as yet unclassified' }
VkPhysicalDevice >> supportsExtension: aName [
	"A gate, so an unknown or empty name answers false instead of raising."

	^ self extensionNames includes: aName
]
