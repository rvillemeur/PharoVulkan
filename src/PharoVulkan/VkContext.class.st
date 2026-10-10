"
Top-level Vulkan context. Owns the VkInstance, selects a physical device and queue family, creates a logical VkDevice, and retrieves the queue. Key methods: computeContextForExtensions:, graphicsContextForExtensions:, destroy.
"
Class {
	#name : 'VkContext',
	#superclass : 'Object',
	#instVars : [
		'instance',
		'physicalDevice',
		'device',
		'computeQueue',
		'computeQueueFamily'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'factory' }
VkContext class >> computeContext [
    ^ self new initializeCompute
]

{ #category : 'constants' }
VkContext class >> deviceCreateInfoSize [
    ^ 72
]

{ #category : 'constants' }
VkContext class >> featureEnabled [
    "VK_TRUE."
    ^ 1
]

{ #category : 'context' }
VkContext class >> graphicsContextForExtensions: extNames [
    "extNames: Array of String (from SDL_Vulkan_GetInstanceExtensions)."
    ^ self new initializeGraphicsWithExtensions: extNames
]

{ #category : 'constants' }
VkContext class >> halfPrecisionExtensionNames [
    "Both are needed before a kernel may declare an f16 storage buffer: one for the type,
     one for 16-bit access to a buffer."
    ^ #( 'VK_KHR_shader_float16_int8' 'VK_KHR_16bit_storage' )
]

{ #category : 'constants' }
VkContext class >> pointerSize [
    ^ 8
]

{ #category : 'constants' }
VkContext class >> shaderFloat16Int8FeaturesSize [
    ^ 24
]

{ #category : 'constants' }
VkContext class >> storage16BitFeaturesSize [
    ^ 32
]

{ #category : 'constants' }
VkContext class >> synchronization2FeaturesSize [
    ^ 24
]

{ #category : 'private' }
VkContext >> allocateCString: aString [
	"Vulkan takes names as NUL-terminated C strings; the caller owns the memory and frees it."

	| bytes buf |
	bytes := aString asByteArray copyWith: 0.
	buf := ExternalAddress allocate: bytes size.
	bytes doWithIndex: [ :byte :i | buf byteAt: i put: byte ].
	^ buf
]

{ #category : 'private' }
VkContext >> buildDeviceCreateInfo: queueInfoBuf [
	"VkDeviceCreateInfo (72 bytes): 0:sType 8:pNext 16:flags 20:queueCreateInfoCount
	 24:pQueueCreateInfos 32:enabledLayerCount 40:ppEnabledLayerNames 48:enabledExtensionCount
	 56:ppEnabledExtensionNames 64:pEnabledFeatures.
	 Everything allocated here is released by freeDeviceCreateInfo:."

	| buf names array |
	names := self enabledDeviceExtensionNames.
	array := self buildExtensionNameArray: names.
	buf := ExternalAddress allocate: self class deviceCreateInfoSize.
	buf unsignedLongAt: 1 put: VkStructureType deviceCreateInfo.
	buf pointerAt: 9 put: self buildFeatureChain.
	buf unsignedLongAt: 17 put: 0.
	buf unsignedLongAt: 21 put: 1.
	buf pointerAt: 25 put: queueInfoBuf.
	buf unsignedLongAt: 33 put: 0.
	buf pointerAt: 41 put: ExternalAddress null.
	buf unsignedLongAt: 49 put: names size.
	buf pointerAt: 57 put: (array ifNil: [ ExternalAddress null ]).
	buf pointerAt: 65 put: ExternalAddress null.
	^ buf
]

{ #category : 'private' }
VkContext >> buildDeviceQueueCreateInfo: familyIndex [
    "VkDeviceQueueCreateInfo (40 bytes): 0:sType 4:pad 8:pNext 16:flags 20:queueFamilyIndex 24:queueCount 28:pad 32:pQueuePriorities"
    | buf priorityBuf |
    priorityBuf := ExternalAddress allocate: 4.
    priorityBuf floatAt: 1 put: 1.0.
    buf := ExternalAddress allocate: 40.
    buf unsignedLongAt: 1 put: VkStructureType deviceQueueCreateInfo.
    buf unsignedLongAt: 5 put: 0.
    buf pointerAt: 9 put: ExternalAddress null.
    buf unsignedLongAt: 17 put: 0.
    buf unsignedLongAt: 21 put: familyIndex.
    buf unsignedLongAt: 25 put: 1.
    buf unsignedLongAt: 29 put: 0.
    buf pointerAt: 33 put: priorityBuf.
    ^ buf
]

{ #category : 'private' }
VkContext >> buildExtensionNameArray: aNameCollection [
	"Answers nil for an empty list rather than a zero-length allocation, so the create info can
	 hold a null pointer beside its count of none."

	| array stride |
	aNameCollection isEmpty ifTrue: [ ^ nil ].
	stride := self class pointerSize.
	array := ExternalAddress allocate: aNameCollection size * stride.
	aNameCollection doWithIndex: [ :each :i |
		array pointerAt: i - 1 * stride + 1 put: (self allocateCString: each) ].
	^ array
]

{ #category : 'private' }
VkContext >> buildFeatureChain [
	"VkPhysicalDeviceSynchronization2Features (24 bytes): 0:sType 8:pNext 16:synchronization2.
	 Synchronization2 is the project's only sync API, so it is always asked for; half precision
	 hangs off it when the device has the extensions."

	| sync2 |
	sync2 := ExternalAddress allocate: self class synchronization2FeaturesSize.
	sync2
		unsignedLongAt: 1
		put: VkStructureType physicalDeviceSynchronization2Features.
	sync2 pointerAt: 9 put: (self halfPrecisionAvailable
			 ifTrue: [ self buildHalfPrecisionFeatures ]
			 ifFalse: [ ExternalAddress null ]).
	sync2 unsignedLongAt: 17 put: self class featureEnabled.
	^ sync2
]

{ #category : 'private' }
VkContext >> buildHalfPrecisionFeatures [
	"VkPhysicalDeviceShaderFloat16Int8Features (24 bytes): 0:sType 8:pNext 16:shaderFloat16
	 20:shaderInt8
	 VkPhysicalDevice16BitStorageFeatures (32 bytes): 0:sType 8:pNext
	 16:storageBuffer16BitAccess 20:uniformAndStorageBuffer16BitAccess 24:storagePushConstant16
	 28:storageInputOutput16
	 ExternalAddress allocate: hands back uninitialised memory, so every field is written,
	 including the ones left off."

	| float16 storage16 |
	storage16 := ExternalAddress allocate: self class storage16BitFeaturesSize.
	storage16
		unsignedLongAt: 1
		put: VkStructureType physicalDevice16BitStorageFeatures.
	storage16 pointerAt: 9 put: ExternalAddress null.
	storage16 unsignedLongAt: 17 put: self class featureEnabled.
	storage16 unsignedLongAt: 21 put: 0.
	storage16 unsignedLongAt: 25 put: 0.
	storage16 unsignedLongAt: 29 put: 0.
	float16 := ExternalAddress allocate:
		           self class shaderFloat16Int8FeaturesSize.
	float16
		unsignedLongAt: 1
		put: VkStructureType physicalDeviceShaderFloat16Int8Features.
	float16 pointerAt: 9 put: storage16.
	float16 unsignedLongAt: 17 put: self class featureEnabled.
	float16 unsignedLongAt: 21 put: 0.
	^ float16
]

{ #category : 'accessing' }
VkContext >> computeQueue [
    ^ computeQueue
]

{ #category : 'accessing' }
VkContext >> computeQueueFamily [
    ^ computeQueueFamily
]

{ #category : 'querying' }
VkContext >> cooperativeMatrixAvailable [
	"Answers for the device this context runs kernels on, which is the device a kernel path
	 would have to gate on. Another device on the same machine may well answer differently —
	 PVCooperativeMatrixSurvey is the one that looks at them all."

	^ physicalDevice supportsCooperativeMatrix
]

{ #category : 'initialization' }
VkContext >> createGraphicsDevice [
    | queueInfo sync2Feat extNameBytes extName extPtrBuf deviceInfo devBuf result devHandle |
    queueInfo := self buildDeviceQueueCreateInfo: computeQueueFamily.
    [ sync2Feat := ExternalAddress allocate: 24.
      [ sync2Feat unsignedLongAt: 1 put: VkStructureType physicalDeviceSynchronization2Features.
        sync2Feat pointerAt: 9 put: ExternalAddress null.
        sync2Feat unsignedLongAt: 17 put: 1.
        extNameBytes := 'VK_KHR_swapchain' asByteArray copyWith: 0.
        extName := ExternalAddress allocate: extNameBytes size.
        [ 1 to: extNameBytes size do: [:i | extName byteAt: i put: (extNameBytes at: i)].
          extPtrBuf := ExternalAddress allocate: 8.
          [ extPtrBuf pointerAt: 1 put: extName.
            deviceInfo := ExternalAddress allocate: 72.
            [ deviceInfo unsignedLongAt: 1 put: VkStructureType deviceCreateInfo.
              deviceInfo pointerAt: 9 put: sync2Feat.
              deviceInfo unsignedLongAt: 17 put: 0.
              deviceInfo unsignedLongAt: 21 put: 1.
              deviceInfo pointerAt: 25 put: queueInfo.
              deviceInfo unsignedLongAt: 33 put: 0.
              deviceInfo pointerAt: 41 put: ExternalAddress null.
              deviceInfo unsignedLongAt: 49 put: 1.
              deviceInfo pointerAt: 57 put: extPtrBuf.
              deviceInfo pointerAt: 65 put: ExternalAddress null.
              devBuf := ExternalAddress allocate: 8.
              [ result := Vk createDevice: physicalDevice handle createInfo: deviceInfo allocator: ExternalAddress null deviceOut: devBuf.
                Vk checkResult: result.
                devHandle := VkDevice_H fromHandle: (devBuf pointerAt: 1).
                device := VkDevice on: devHandle physicalDevice: physicalDevice context: self
              ] ensure: [ devBuf free ]
            ] ensure: [ deviceInfo free ]
          ] ensure: [ extPtrBuf free ]
        ] ensure: [ extName free ]
      ] ensure: [ sync2Feat free ].
      (queueInfo pointerAt: 33) free
    ] ensure: [ queueInfo free ]
]

{ #category : 'initialization' }
VkContext >> createLogicalDevice [

	| queueInfo deviceInfo devBuf result devHandle |
	queueInfo := self buildDeviceQueueCreateInfo: computeQueueFamily.
	[
	deviceInfo := self buildDeviceCreateInfo: queueInfo.
	[
	devBuf := ExternalAddress allocate: self class pointerSize.
	[
	result := Vk
		          createDevice: physicalDevice handle
		          createInfo: deviceInfo
		          allocator: ExternalAddress null
		          deviceOut: devBuf.
	Vk checkResult: result.
	devHandle := VkDevice_H fromHandle: (devBuf pointerAt: 1).
	device := VkDevice
		          on: devHandle
		          physicalDevice: physicalDevice
		          context: self ] ensure: [ devBuf free ] ] ensure: [
		self freeDeviceCreateInfo: deviceInfo ].
	(queueInfo pointerAt: 33) free ] ensure: [ queueInfo free ]
]

{ #category : 'lifecycle' }
VkContext >> destroy [

	device ifNotNil: [
			Vk deviceWaitIdle: device handle.
			device destroy.
			device := nil ].
	instance ifNotNil: [
			Vk destroyInstance: instance allocator: ExternalAddress null.
			instance invalidate.
			instance := nil ].
	computeQueue ifNotNil: [
			computeQueue handle invalidate.
			computeQueue := nil ].
	physicalDevice ifNotNil: [
			physicalDevice handle invalidate.
			physicalDevice := nil ].
	computeQueueFamily := nil
]

{ #category : 'accessing' }
VkContext >> device [
    ^ device
]

{ #category : 'reporting' }
VkContext >> deviceFeatureReport [
	"Reads the pNext chain back out of a chain built for this context instead of restating what
	 buildFeatureChain writes, and frees it again, so inspecting a context leaves it untouched."

	| chain names |
	physicalDevice ifNil: [ ^ { ('Device' -> 'destroyed') } ].
	chain := self buildFeatureChain.
	names := [
	         (self featureChainTypesIn: chain) collect: [ :each |
		         (VkStructureType nameForValue: each)
			         ifNil: [ each printString ]
			         ifNotNil: [ :name | name asString ] ] ] ensure: [
		         self freeFeatureChain: chain ].
	^ {
		  ('Half precision available' -> self halfPrecisionAvailable printString).
		  ('Enabled extensions'
		   -> (', ' join: self enabledDeviceExtensionNames)).
		  ('Feature chain' -> (', ' join: names)) }
]

{ #category : 'querying' }
VkContext >> enabledDeviceExtensionNames [
	"The device extensions this context asks for, which is the half precision pair where the
	 device has them and nothing at all where it does not."

	^ self halfPrecisionAvailable
		  ifTrue: [ self class halfPrecisionExtensionNames ]
		  ifFalse: [ #() ]
]

{ #category : 'private' }
VkContext >> extensionNamesIn: aCreateInfo [
	"Decodes the enabled extension names back out of a create info, reusing the physical
	 device's decoder so there is one place that walks a Vulkan name."

	| count array stride |
	count := aCreateInfo unsignedLongAt: 49.
	array := aCreateInfo pointerAt: 57.
	(count = 0 or: [ array isNull ]) ifTrue: [ ^ #() ].
	stride := self class pointerSize.
	^ (1 to: count) collect: [ :i |
		  VkPhysicalDevice
			  extensionNameIn: (array pointerAt: i - 1 * stride + 1)
			  at: 0 ]
]

{ #category : 'private' }
VkContext >> featureChainTypesIn: aStruct [
	"Every struct in a pNext chain starts with its sType and carries its successor at offset 8,
	 so the chain can be read back without knowing which structs are on it."

	| types current |
	types := OrderedCollection new.
	current := aStruct.
	[ current isNull ] whileFalse: [
		types add: (current unsignedLongAt: 1).
		current := current pointerAt: 9 ].
	^ types asArray
]

{ #category : 'initialization' }
VkContext >> fetchComputeQueue [

	| buf |
	buf := ExternalAddress allocate: 8.
	computeQueue := [
		                Vk
			                getDeviceQueue: device handle
			                queueFamilyIndex: computeQueueFamily
			                queueIndex: 0
			                queue: buf.
		                VkQueue
			                on: (VkQueue_H fromHandle: (buf pointerAt: 1))
			                familyIndex: computeQueueFamily ] ensure: [
		                buf free ]
]

{ #category : 'fetching' }
VkContext >> fetchGraphicsQueue [

	| buf |
	buf := ExternalAddress allocate: 8.
	computeQueue := [
		                Vk
			                getDeviceQueue: device handle
			                queueFamilyIndex: computeQueueFamily
			                queueIndex: 0
			                queue: buf.
		                VkQueue
			                on: (VkQueue_H fromHandle: (buf pointerAt: 1))
			                familyIndex: computeQueueFamily ] ensure: [
		                buf free ]
]

{ #category : 'private' }
VkContext >> freeDeviceCreateInfo: aCreateInfo [
	"Releases everything buildDeviceCreateInfo: allocated, the create info included: the pNext
	 chain, the name array, and each name in it."

	| count array stride |
	self freeFeatureChain: (aCreateInfo pointerAt: 9).
	count := aCreateInfo unsignedLongAt: 49.
	array := aCreateInfo pointerAt: 57.
	stride := self class pointerSize.
	array isNull ifFalse: [
		1 to: count do: [ :i | (array pointerAt: i - 1 * stride + 1) free ].
		array free ].
	aCreateInfo free
]

{ #category : 'private' }
VkContext >> freeFeatureChain: aStruct [
	"Walks the chain forward, keeping the successor before freeing the struct that holds it."

	| current next |
	current := aStruct.
	[ current isNull ] whileFalse: [
		next := current pointerAt: 9.
		current free.
		current := next ]
]

{ #category : 'querying' }
VkContext >> halfPrecisionAvailable [
	"Asks the driver rather than assuming: the same context must come up on a device that
	 offers neither extension."

	^ self class halfPrecisionExtensionNames allSatisfy: [ :each |
		  physicalDevice supportsExtension: each ]
]

{ #category : 'initialization' }
VkContext >> initializeCompute [
	"Create instance with Vulkan 1.3 API version so device dispatch table includes vkQueueSubmit2."

	| appInfo info buf result |
	appInfo := ExternalAddress allocate: 48.
	instance := [
		            appInfo
			            unsignedLongAt: 1
			            put: VkStructureType applicationInfo.
		            appInfo pointerAt: 9 put: ExternalAddress null.
		            appInfo pointerAt: 17 put: ExternalAddress null.
		            appInfo unsignedLongAt: 25 put: 0.
		            appInfo pointerAt: 33 put: ExternalAddress null.
		            appInfo unsignedLongAt: 41 put: 0.
		            appInfo unsignedLongAt: 45 put: VkApiVersion vulkan13.
		            info := ExternalAddress allocate: 64.
		            [
			            info
				            unsignedLongAt: 1
				            put: VkStructureType instanceCreateInfo.
			            info pointerAt: 9 put: ExternalAddress null.
			            info unsignedLongAt: 17 put: 0.
			            info pointerAt: 25 put: appInfo.
			            info unsignedLongAt: 33 put: 0.
			            info pointerAt: 41 put: ExternalAddress null.
			            info unsignedLongAt: 49 put: 0.
			            info pointerAt: 57 put: ExternalAddress null.
			            buf := ExternalAddress allocate: 8.
			            [
				            result := Vk
					                      primCreateInstance: info
					                      allocator: ExternalAddress null
					                      instanceOut: buf.
				            Vk checkResult: result.
				            VkInstance_H fromHandle: (buf pointerAt: 1) ] ensure: [
				            buf free ] ] ensure: [ info free ] ] ensure: [
		            appInfo free ].
	self selectPhysicalDevice.
	self createLogicalDevice.
	self fetchComputeQueue.
	^ self
]

{ #category : 'initialization' }
VkContext >> initializeGraphicsWithExtensions: extNames [
    | appInfo info extPtrs extArray buf result |
    appInfo := ExternalAddress allocate: 48.
    [ appInfo unsignedLongAt: 1 put: VkStructureType applicationInfo.
      appInfo pointerAt: 9 put: ExternalAddress null.
      appInfo pointerAt: 17 put: ExternalAddress null.
      appInfo unsignedLongAt: 25 put: 0.
      appInfo pointerAt: 33 put: ExternalAddress null.
      appInfo unsignedLongAt: 41 put: 0.
      appInfo unsignedLongAt: 45 put: VkApiVersion vulkan13.
      info := ExternalAddress allocate: 64.
      [ extPtrs := extNames collect: [:n |
            | bytes p |
            bytes := n asByteArray copyWith: 0.
            p := ExternalAddress allocate: bytes size.
            1 to: bytes size do: [:i | p byteAt: i put: (bytes at: i)].
            p].
        extArray := ExternalAddress allocate: extNames size * 8.
        [ extPtrs doWithIndex: [:p :i | extArray pointerAt: (i - 1) * 8 + 1 put: p].
          info unsignedLongAt: 1 put: VkStructureType instanceCreateInfo.
          info pointerAt: 9 put: ExternalAddress null.
          info unsignedLongAt: 17 put: 0.
          info pointerAt: 25 put: appInfo.
          info unsignedLongAt: 33 put: 0.
          info pointerAt: 41 put: ExternalAddress null.
          info unsignedLongAt: 49 put: extNames size.
          info pointerAt: 57 put: extArray.
          buf := ExternalAddress allocate: 8.
          [ result := Vk primCreateInstance: info allocator: ExternalAddress null instanceOut: buf.
            Vk checkResult: result.
            instance := VkInstance_H fromHandle: (buf pointerAt: 1)
          ] ensure: [ buf free ]
        ] ensure: [ extArray free. extPtrs do: [:p | p free] ]
      ] ensure: [ info free ]
    ] ensure: [ appInfo free ].
    self selectGraphicsPhysicalDevice.
    self createGraphicsDevice.
    self fetchGraphicsQueue.
    ^ self
]

{ #category : 'inspector' }
VkContext >> inspectorDeviceFeatures: aBuilder [
	<inspectorPresentationOrder: 10 title: 'Device features'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Setting' evaluated: [ :each | each key ]);
		  addColumn:
			  (SpStringTableColumn title: 'Value' evaluated: [ :each | each value ]);
		  items: self deviceFeatureReport;
		  yourself
]

{ #category : 'accessing' }
VkContext >> instance [
    ^ instance
]

{ #category : 'accessing' }
VkContext >> physicalDevice [
    ^ physicalDevice
]

{ #category : 'selection' }
VkContext >> selectGraphicsPhysicalDevice [
    | handles |
    handles := Vk enumeratePhysicalDevices: instance.
    handles isEmpty ifTrue: [ VkError signal: 'No Vulkan physical devices found' ].
    handles do: [ :h |
        | pd |
        pd := VkPhysicalDevice on: h.
        pd findGraphicsQueueFamily ifNotNil: [ :idx |
            physicalDevice := pd.
            computeQueueFamily := idx.
            ^ self ] ].
    VkError signal: 'No device with graphics+compute queue found'
]

{ #category : 'initialization' }
VkContext >> selectPhysicalDevice [
    | handles |
    handles := Vk enumeratePhysicalDevices: instance.
    handles isEmpty ifTrue: [ VkError signal: 'No Vulkan physical devices found' ].
    "Pick first device that has a compute queue"
    handles do: [ :h |
        | pd |
        pd := VkPhysicalDevice on: h.
        pd findComputeQueueFamily ifNotNil: [ :idx |
            physicalDevice := pd.
            computeQueueFamily := idx.
            ^ self ] ].
    VkError signal: 'No device with compute queue found'
]

{ #category : 'querying' }
VkContext >> subgroupArithmeticAvailable [
	"Asks the device rather than assuming: a kernel that reduces across a subgroup needs the
	 arithmetic operations, which a device may leave out while still reporting a subgroup."

	^ physicalDevice supportsSubgroupArithmetic
]
