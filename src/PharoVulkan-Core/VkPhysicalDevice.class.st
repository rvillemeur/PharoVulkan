Class {
	#name : 'VkPhysicalDevice',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'properties',
		'queueFamilyProps',
		'memoryProperties'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan-Core'
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

{ #category : 'initialization' }
VkPhysicalDevice >> fetchQueueFamilyProperties [
    | countBuf count propsBuf propSize |
    "VkQueueFamilyProperties size = 24 bytes"
    propSize := 24.
    countBuf := ExternalAddress allocate: 4.
    [ Vk getQueueFamilyProperties: handle count: countBuf props: ExternalAddress null.
      count := countBuf unsignedLongAt: 1.
      propsBuf := ExternalAddress allocate: count * propSize.
      [ Vk getQueueFamilyProperties: handle count: countBuf props: propsBuf.
        queueFamilyProps := (1 to: count) collect: [ :i |
            | base flags |
            base := (i - 1) * propSize.
            flags := propsBuf unsignedLongAt: base + 1.
            flags ] "return queueFlags for each family"
      ] ensure: [ propsBuf free ]
    ] ensure: [ countBuf free ]
]

{ #category : 'querying' }
VkPhysicalDevice >> findComputeQueueFamily [
    "VK_QUEUE_COMPUTE_BIT = 2"
    queueFamilyProps doWithIndex: [ :flags :i |
        (flags bitAnd: 2) ~= 0 ifTrue: [ ^ i - 1 ] ].
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
