"
Wrapper around a VkPhysicalDevice_H. Queries queue family properties, locates compute or graphics+compute queue families, and selects memory type indices for allocations. Key methods: findComputeQueueFamily, findGraphicsQueueFamily, findMemoryType:properties:.
"
Class {
	#name : 'VkPhysicalDevice',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'queueFamilyProps',
		'memoryProperties'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'factory' }
VkPhysicalDevice class >> on: aHandle [
    ^ self new initializeWith: aHandle
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
