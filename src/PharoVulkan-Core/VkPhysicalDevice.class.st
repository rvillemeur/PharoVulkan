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
	#category : 'PharoVulkan-Core-Device',
	#package : 'PharoVulkan-Core',
	#tag : 'Device'
}

{ #category : 'constants' }
VkPhysicalDevice class >> cooperativeMatrixExtensionName [
	"The extension a cooperative matrix kernel needs. Built from extensionNamePrefix so the
	 name cannot drift from the form a driver reports."

	^ self extensionNamePrefix , 'KHR_cooperative_matrix'
]

{ #category : 'constants' }
VkPhysicalDevice class >> cooperativeMatrixPropertiesCommandName [
	"The command that answers which M, N, K and type combinations a device offers. The
	 loader exports no symbol for it, so it is reached through VkExtensionCommand."

	^ 'vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR'
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

{ #category : 'constants' }
VkPhysicalDevice class >> maxMemoryHeaps [
	"VK_MAX_MEMORY_HEAPS: the fixed length of the memoryHeaps array the driver fills in
	 VkPhysicalDeviceMemoryProperties."

	^ 16
]

{ #category : 'constants' }
VkPhysicalDevice class >> maxMemoryTypes [
	"VK_MAX_MEMORY_TYPES: the fixed length of the memoryTypes array the driver fills in
	 VkPhysicalDeviceMemoryProperties. The array is sized by the specification, not by the
	 number of types a given device reports."

	^ 32
]

{ #category : 'constants' }
VkPhysicalDevice class >> memoryHeapByteSize [
	"VkMemoryHeap is a VkDeviceSize then a uint32, and the eight-byte alignment of that first
	 field pads the structure back out to sixteen bytes."

	^ 16
]

{ #category : 'constants' }
VkPhysicalDevice class >> memoryPropertiesByteSize [
	"The byte size of VkPhysicalDeviceMemoryProperties, which this project has no structure
	 class for: memoryTypeCount, the memoryTypes array, memoryHeapCount, then the memoryHeaps
	 array. memoryHeapCount ends on a multiple of eight, so nothing pads the heap array."

	^ 4 + (self maxMemoryTypes * self memoryTypeByteSize) + 4
	  + (self maxMemoryHeaps * self memoryHeapByteSize)
]

{ #category : 'constants' }
VkPhysicalDevice class >> memoryTypeByteSize [
	"VkMemoryType is two uint32: propertyFlags then heapIndex."

	^ 8
]

{ #category : 'factory' }
VkPhysicalDevice class >> on: aHandle [
    ^ self new initializeWith: aHandle
]

{ #category : 'constants' }
VkPhysicalDevice class >> swapchainExtensionName [
	"The device extension a context needs before it can create a swapchain on a surface."

	^ 'VK_KHR_swapchain'
]

{ #category : 'private' }
VkPhysicalDevice >> callCooperativeMatrixProperties: aCommand count: countBuf properties: aPropertiesBuffer [
	"VkResult vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR(VkPhysicalDevice,
	 uint32_t* pPropertyCount, VkCooperativeMatrixPropertiesKHR* pProperties). The signature
	 is written once here because both calls of the two-call query must agree on it."
	^ Vk checkResult: (aCommand
			   callWithArguments: {
					   handle.
					   countBuf.
					   aPropertiesBuffer }
			   parameterTypes: #( #pointer #pointer #pointer )
			   returnType: #int32)
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
VkPhysicalDevice >> cooperativeMatrixConfigurationsOn: anInstanceHandle [
	"The shapes and component types this device offers for VK_KHR_cooperative_matrix. A
	 kernel has to name one of them exactly, so this query decides what can be compiled.
	 The instance comes in as an argument because a physical device holds no instance."
	| command countBuf count |
	self supportsCooperativeMatrix ifFalse: [ ^ #() ].
	command := VkExtensionCommand
		           on: anInstanceHandle
		           named: self class cooperativeMatrixPropertiesCommandName.
	countBuf := ExternalAddress allocate: 4.
	^ [
	  countBuf unsignedLongAt: 1 put: 0.
	  self
		  callCooperativeMatrixProperties: command
		  count: countBuf
		  properties: ExternalAddress null.
	  count := countBuf unsignedLongAt: 1.
	  self readCooperativeMatrixConfigurations: count with: command count: countBuf ]
		  ensure: [ countBuf free ]
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
	"The table the driver writes lives outside object memory only for the duration of the query,
	 so it is copied in before that memory is freed, the way fetchSubgroupProperties does. A
	 physical device then owns no external memory and needs no destroy of its own."

	| buf size |
	size := self class memoryPropertiesByteSize.
	buf := ExternalAddress allocate: size.
	memoryProperties := [
	                    Vk
		                    getPhysicalDeviceMemoryProperties: handle
		                    memoryProperties: buf.
	                    buf structAt: 1 length: size ] ensure: [ buf free ]
]

{ #category : 'initialization' }
VkPhysicalDevice >> fetchQueueFamilyProperties [
	"The stride of the table the driver writes is the byte size of the structure the bindings
	 already declare, so it is asked of VkQueueFamilyProperties rather than written here."

	| countBuf count propsBuf propSize |
	propSize := VkQueueFamilyProperties byteSize.
	countBuf := ExternalAddress allocate: 4.
	queueFamilyProps := [
	                   Vk
		                   primGetQueueFamilyProperties: handle
		                   count: countBuf
		                   props: ExternalAddress null.
	                   count := countBuf unsignedLongAt: 1.
	                   propsBuf := ExternalAddress allocate: count * propSize.
	                   [
	                   Vk
		                   primGetQueueFamilyProperties: handle
		                   count: countBuf
		                   props: propsBuf.
	                   (1 to: count) collect: [ :i |
		                   | base |
		                   base := i - 1 * propSize.
		                   propsBuf unsignedLongAt: base + 1 ] ] ensure: [
		                   propsBuf free ] ] ensure: [ countBuf free ]
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
	0 to: self memoryTypeCount - 1 do: [ :i |
		((typeFilter bitAnd: (1 bitShift: i)) ~= 0) ifTrue: [
			((self memoryPropertyFlagsOfType: i) bitAnd: requiredFlags) = requiredFlags
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
	^ PVFactRow
		  tableOf: (self computeCapabilityRows collect: [ :each |
				   PVFactRow name: each key value: each value ])
		  nameColumn: 'Capability'
		  valueColumn: 'Value'
		  in: aBuilder
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
	^ PVFactRow
		  tableOf: (self halfPrecisionReport collect: [ :each |
				   PVFactRow name: each key value: each value ])
		  nameColumn: 'Requirement'
		  valueColumn: 'Supported'
		  in: aBuilder
]

{ #category : 'inspector' }
VkPhysicalDevice >> inspectorMemoryTypes: aBuilder [
	"The Chosen column calls findMemoryType:properties: itself for hostVisibleAndCoherent,
	 so it cannot drift from what VkBuffer allocate actually gets."
	<inspectorPresentationOrder: 25 title: 'Memory types'>
	^ aBuilder newTable
		addColumn: (SpStringTableColumn title: 'Index' evaluated: [ :each | each first printString ]);
		addColumn: (SpStringTableColumn title: 'Properties' evaluated: [ :each | each second ]);
		addColumn: (SpStringTableColumn title: 'Heap' evaluated: [ :each | each third printString ]);
		addColumn: (SpStringTableColumn
			title: 'Chosen for hostVisibleAndCoherent'
			evaluated: [ :each | each fourth printString ]);
		items: self memoryTypeRows;
		yourself
]

{ #category : 'inspector' }
VkPhysicalDevice >> inspectorQueueFamilies: aBuilder [
	"The Graphics and Compute columns call findGraphicsQueueFamily and
	 findComputeQueueFamily themselves, so they cannot drift from what a context
	 actually selects. No queue-count column: fetchQueueFamilyProperties keeps only
	 the flags word of each family, and widening it is a code change with no bug
	 behind it, so it is left out here rather than ridden along with this view."
	<inspectorPresentationOrder: 15 title: 'Queue families'>
	^ aBuilder newTable
		addColumn: (SpStringTableColumn title: 'Index' evaluated: [ :each | each first printString ]);
		addColumn: (SpStringTableColumn title: 'Flags' evaluated: [ :each | each second ]);
		addColumn: (SpStringTableColumn title: 'Graphics' evaluated: [ :each | each third printString ]);
		addColumn: (SpStringTableColumn title: 'Compute' evaluated: [ :each | each fourth printString ]);
		items: self queueFamilyRows;
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

{ #category : 'querying' }
VkPhysicalDevice >> memoryHeapIndexOfType: anIndex [
	"memoryTypes array starts at offset 4 in VkPhysicalDeviceMemoryProperties, each
	 VkMemoryType = 8 bytes: propertyFlags(4) + heapIndex(4); heapIndex follows the flags.
	 The flags half of that stride is confirmed by the property names decoding sensibly;
	 this half is not confirmed on this machine, which reports one heap, so every type
	 answers 0 whether the offset is right or not."
	^ memoryProperties unsignedLongAt: 9 + (anIndex * 8)
]

{ #category : 'querying' }
VkPhysicalDevice >> memoryPropertyFlagsOfType: anIndex [
	"memoryTypes array starts at offset 4 in VkPhysicalDeviceMemoryProperties,
	 each VkMemoryType = 8 bytes: propertyFlags(4) + heapIndex(4)"
	^ memoryProperties unsignedLongAt: 5 + (anIndex * 8)
]

{ #category : 'querying' }
VkPhysicalDevice >> memoryTypeCount [
	"VkPhysicalDeviceMemoryProperties: memoryTypeCount is the first field, offset 1."
	^ memoryProperties unsignedLongAt: 1
]

{ #category : 'accessing' }
VkPhysicalDevice >> memoryTypeRows [
	"One row per memory type this device reports, each fact read through the same
	 accessors findMemoryType:properties: uses, so the table cannot drift from the
	 allocator. Chosen asks findMemoryType:properties: itself rather than restating its
	 rule, with every index allowed in the filter so only the property requirement decides."
	| typeCount allBits chosenIndex rows |
	typeCount := self memoryTypeCount.
	allBits := (1 bitShift: typeCount) - 1.
	chosenIndex := [ self findMemoryType: allBits properties: VkMemoryProperty hostVisibleAndCoherent ]
		on: VkError do: [ :e | nil ].
	rows := OrderedCollection new.
	0 to: typeCount - 1 do: [ :i |
		rows add: {
			i.
			VkMemoryProperty nameForFlags: (self memoryPropertyFlagsOfType: i).
			self memoryHeapIndexOfType: i.
			i = chosenIndex } ].
	^ rows asArray
]

{ #category : 'accessing' }
VkPhysicalDevice >> properties [
	"Queried once and kept. The driver answers the same struct for the life of the device, and
	 the struct's store is a ByteArray inside object memory, so a second query would only write
	 the same bytes again."

	^ properties ifNil: [ properties := Vk getPhysicalDeviceProperties: handle ]
]

{ #category : 'accessing' }
VkPhysicalDevice >> queueFamilyRows [
	"One row per queue family this device reports, each fact read through the same
	 accessors findGraphicsQueueFamily and findComputeQueueFamily use, so the table
	 cannot drift from what the context actually selects."
	| graphicsChoice computeChoice |
	graphicsChoice := self findGraphicsQueueFamily.
	computeChoice := self findComputeQueueFamily.
	^ (1 to: queueFamilyProps size) collect: [ :i |
		| index |
		index := i - 1.
		{
			index.
			VkQueueFlag nameForFlags: (queueFamilyProps at: i).
			index = graphicsChoice.
			index = computeChoice } ]
]

{ #category : 'private' }
VkPhysicalDevice >> readCooperativeMatrixConfigurations: aCount with: aCommand count: countBuf [
	"A device may report the extension and still offer no configuration, which is a list of
	 none rather than an error. The second call can also answer fewer entries than the
	 first, so the count it leaves behind is the one decoded."
	| buffer |
	aCount = 0 ifTrue: [ ^ #() ].
	buffer := ExternalAddress allocate:
		          aCount * VkCooperativeMatrixConfiguration structureByteSize.
	^ [
	  VkCooperativeMatrixConfiguration prepareEntriesIn: buffer count: aCount.
	  self
		  callCooperativeMatrixProperties: aCommand
		  count: countBuf
		  properties: buffer.
	  VkCooperativeMatrixConfiguration
		  readAllFrom: buffer
		  count: (countBuf unsignedLongAt: 1) ] ensure: [ buffer free ]
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
VkPhysicalDevice >> supportsGraphics [
	^ self findGraphicsQueueFamily notNil
]

{ #category : 'testing' }
VkPhysicalDevice >> supportsGraphicsAndComputeOnOneQueue [
	"The requirement an offscreen graphics context actually needs: it creates a single
	 queue from findComputeQueueFamily and submits graphics work on it, so a device whose
	 graphics and compute families differ cannot be used without a second queue this
	 context does not create."
	| graphics compute |
	graphics := self findGraphicsQueueFamily.
	compute := self findComputeQueueFamily.
	^ graphics notNil and: [ compute notNil and: [ graphics = compute ] ]
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

{ #category : 'testing' }
VkPhysicalDevice >> supportsSwapchain [
	"Unary, because device selection asks its requirements by perform:."

	^ self supportsExtension: self class swapchainExtensionName
]

{ #category : 'querying' }
VkPhysicalDevice >> supportsVulkanMemoryModel [
	"Whether this device can have the vulkanMemoryModel feature enabled, which a cooperative
	 matrix module needs: spirv-val refuses Shader plus CooperativeMatrixKHR without the
	 VulkanMemoryModel capability. vkGetPhysicalDeviceFeatures2 is core, so no instance handle
	 and no extension command is needed, and the flag is read before the chain is freed."

	^ VkPhysicalDeviceFeatures2
		  of: handle
		  chainedWith: VkPhysicalDeviceVulkanMemoryModelFeatures
		  do: [ :head :features | features vulkanMemoryModel ~= 0 ]
]
