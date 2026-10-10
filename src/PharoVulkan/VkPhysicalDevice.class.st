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
		'extensionNames',
		'properties',
		'subgroupProperties'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'constants' }
VkPhysicalDevice class >> cooperativeMatrixExtensionName [
	"The extension a cooperative matrix kernel needs. Built from extensionNamePrefix so the
	 name cannot drift from the form a driver reports."

	^ self extensionNamePrefix , 'KHR_cooperative_matrix'
]

{ #category : 'examples' }
VkPhysicalDevice class >> exampleExtensionsOfThisMachine [
    "One click: the extension list of whatever device this image finds. The names are cached
     in the instance, so the object still answers them after the context is destroyed, which
     is why the example can hand back a device whose handle has gone."
    <sampleInstance>
    | context |
    context := VkContext computeContext.
    ^ [ context physicalDevice
            extensionNames;
            yourself ] ensure: [ context destroy ]
]

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

{ #category : 'accessing' }
VkPhysicalDevice >> computeCapabilityRows [
	"What the Compute view shows. Every row asks the accessor a kernel would ask, so the table
	 cannot report a capability the compiler would not get."

	^ {
		  ('Subgroup size' -> self subgroupSize printString).
		  ('Subgroup arithmetic' -> self supportsSubgroupArithmetic printString).
		  ('Shared memory bytes' -> self maxComputeSharedMemorySize printString).
		  ('Work group invocations'
		   -> self maxComputeWorkGroupInvocations printString).
		  ('Work group size' -> self maxComputeWorkGroupSize printString) }
]

{ #category : 'querying' }
VkPhysicalDevice >> extensionNames [
	"Fetched on demand: the compute path needs the list only to gate optional features, and
	 the graphics path never asks."

	^ extensionNames ifNil: [ self fetchExtensionNames ]
]

{ #category : 'initialization' }
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

{ #category : 'private' }
VkPhysicalDevice >> fetchSubgroupProperties [
	"The chain lives outside the image only for the duration of the query, so the answered block
	 is copied into object memory before that memory is freed."

	^ VkPhysicalDeviceProperties2
		  of: handle
		  chainedWith: VkPhysicalDeviceSubgroupProperties
		  do: [ :head :block | block copyIntoObjectMemory ]
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

{ #category : 'reporting' }
VkPhysicalDevice >> halfPrecisionReport [
	"One row per extension VkContext gates half precision on, each answered by the predicate
	 the gate itself uses, and a last row for the gate's own verdict."

	| names |
	names := VkContext halfPrecisionExtensionNames.
	^ (names collect: [ :each | each -> (self supportsExtension: each) ])
	  , {
		    ('Half precision available'
		     -> (names allSatisfy: [ :each | self supportsExtension: each ])) }
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

{ #category : 'inspector' }
VkPhysicalDevice >> inspectorCompute: aBuilder [
	"The limits and subgroup facts a compute kernel has to fit, each answered by the accessor
	 the compiler uses. Nothing here writes to the device or its properties."

	<inspectorPresentationOrder: 30 title: 'Compute'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Capability' evaluated: [ :each |
					   each key ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each value ]);
		  items: self computeCapabilityRows;
		  yourself
]

{ #category : 'inspector' }
VkPhysicalDevice >> inspectorExtensions: aBuilder [
	<inspectorPresentationOrder: 10 title: 'Extensions'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Extension' evaluated: [ :each | each ]);
		  items: self extensionNames asSortedCollection asArray;
		  yourself
]

{ #category : 'inspector' }
VkPhysicalDevice >> inspectorHalfPrecision: aBuilder [
	<inspectorPresentationOrder: 20 title: 'Half precision'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Requirement' evaluated: [ :each |
				   each key ]);
		  addColumn: (SpStringTableColumn title: 'Supported' evaluated: [ :each |
				   each value printString ]);
		  items: self halfPrecisionReport;
		  yourself
]

{ #category : 'accessing' }
VkPhysicalDevice >> limits [
	"The VkPhysicalDeviceLimits block of this device's properties, reached through its own
	 accessors rather than by indexing into a byte blob."

	^ self properties limits
]

{ #category : 'accessing' }
VkPhysicalDevice >> maxComputeSharedMemorySize [
	"Bytes of shared memory one work group may declare. A tiled kernel cannot exceed it."

	^ self limits maxComputeSharedMemorySize
]

{ #category : 'accessing' }
VkPhysicalDevice >> maxComputeWorkGroupInvocations [
	"Invocations one work group may hold, so the product of a local size must not exceed it."

	^ self limits maxComputeWorkGroupInvocations
]

{ #category : 'accessing' }
VkPhysicalDevice >> maxComputeWorkGroupSize [
	"The per dimension ceiling on a local size, x, y and z, as plain integers."

	^ (1 to: 3) collect: [ :i | self limits maxComputeWorkGroupSize at: i ]
]

{ #category : 'accessing' }
VkPhysicalDevice >> properties [
	"Queried once and kept. The driver answers the same struct for the life of the device, and
	 the struct's store is a ByteArray inside object memory, so a second query would only write
	 the same bytes again."

	^ properties ifNil: [ properties := Vk getPhysicalDeviceProperties: handle ]
]

{ #category : 'initialization' }
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

{ #category : 'accessing' }
VkPhysicalDevice >> subgroupProperties [
	"Queried once and kept, like the rest of a device's fixed properties."

	^ subgroupProperties ifNil: [
		  subgroupProperties := self fetchSubgroupProperties ]
]

{ #category : 'accessing' }
VkPhysicalDevice >> subgroupSize [
	"Invocations in one subgroup. A subgroup reduction can only be written against this width."

	^ self subgroupProperties subgroupSize
]

{ #category : 'querying' }
VkPhysicalDevice >> supportsCooperativeMatrix [
	"Asks the extension list the driver reported. A cooperative matrix kernel needs more than
	 the extension — the shapes and types it offers have to be queried too — but without the
	 extension there is nothing to query."

	^ self supportsExtension: self class cooperativeMatrixExtensionName
]

{ #category : 'querying' }
VkPhysicalDevice >> supportsExtension: aName [
	"A gate, so an unknown or empty name answers false instead of raising."

	^ self extensionNames includes: aName
]

{ #category : 'testing' }
VkPhysicalDevice >> supportsSubgroupArithmetic [
	"Whether the device offers the subgroup add and multiply operations a reduction needs."

	^ self supportsSubgroupFeature: VkSubgroupFeature arithmeticBit
]

{ #category : 'testing' }
VkPhysicalDevice >> supportsSubgroupFeature: aBit [
	"Asked of the properties block itself, so the device and the block cannot disagree."

	^ self subgroupProperties supportsFeature: aBit
]
