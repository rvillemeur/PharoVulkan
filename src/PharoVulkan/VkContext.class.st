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
		'computeQueueFamily',
		'deviceRequirements',
		'chosenDeviceName'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'factory' }
VkContext class >> computeContext [
    ^ self new initializeCompute
]

{ #category : 'instance creation' }
VkContext class >> computeContextRequiring: aCollectionOfSelectors [
	"Each selector is a unary predicate a VkPhysicalDevice answers, for instance
	 #supportsCooperativeMatrix. Device selection then stops being a matter of position."
	^ self new initializeComputeRequiring: aCollectionOfSelectors
]

{ #category : 'instance creation' }
VkContext class >> cooperativeMatrixContext [
	"On this machine the device that offers VK_KHR_cooperative_matrix is not the first one
	 enumerated, so a cooperative matrix kernel cannot use the plain compute context. Both
	 capabilities are required, not just the extension: a module declaring CooperativeMatrixKHR
	 must also declare VulkanMemoryModel, which needs the matching device feature."

	^ self computeContextRequiring: #( #supportsCooperativeMatrix #supportsVulkanMemoryModel )
]

{ #category : 'constants' }
VkContext class >> cooperativeMatrixFeaturesSize [
	"VkPhysicalDeviceCooperativeMatrixFeaturesKHR (24 bytes): 0:sType 8:pNext
	 16:cooperativeMatrix 20:cooperativeMatrixRobustBufferAccess."
	^ 24
]

{ #category : 'constants' }
VkContext class >> deviceCreateInfoSize [
    ^ 72
]

{ #category : 'examples' }
VkContext class >> exampleDeviceChosenByCapabilityOnThisMachine [
	"One click: the context a cooperative matrix kernel would run on, destroyed before it is
	 handed over. The Device choice tab names the requirement and the device that met it,
	 which on this machine is not the first device enumerated. Falls back to the plain
	 compute context where no device offers the extension."
	<sampleInstance>
	| context |
	context := [ self cooperativeMatrixContext ]
		           on: VkError
		           do: [ :signal | self computeContext ].
	context destroy.
	^ context
]

{ #category : 'examples' }
VkContext class >> exampleOffscreenContextOnThisMachine [
	"One click: the context an offscreen graphics render would use on whatever device
	 this image finds, destroyed before it is handed back. The Device choice tab names
	 the requirement (supportsGraphicsAndComputeOnOneQueue) and the device that met it,
	 which destroy does not clear."
	<sampleInstance>
	| context |
	context := self offscreenGraphicsContext.
	context destroy.
	^ context
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
VkContext class >> graphicsExtensionNames [
	"What the graphics path asks of the device beyond the core: presenting to a surface. The
	 compute path asks for none of these and the half precision names are optional and device
	 dependent, which is why they are a list of their own."

	^ #( 'VK_KHR_swapchain' )
]

{ #category : 'constants' }
VkContext class >> halfPrecisionExtensionNames [
    "Both are needed before a kernel may declare an f16 storage buffer: one for the type,
     one for 16-bit access to a buffer."
    ^ #( 'VK_KHR_shader_float16_int8' 'VK_KHR_16bit_storage' )
]

{ #category : 'factory' }
VkContext class >> offscreenGraphicsContext [
	"A device whose graphics and compute families differ would need a second queue,
	 which this context does not create, so it does not qualify rather than failing later
	 when a draw is submitted on a queue that cannot accept it."
	^ self computeContextRequiring: #( #supportsGraphicsAndComputeOnOneQueue )
]

{ #category : 'constants' }
VkContext class >> pointerSize [
    ^ 8
]

{ #category : 'constants' }
VkContext class >> queueCreateInfosPerDevice [
	"One queue create info is handed to vkCreateDevice, because the context creates its queues
	 on one family. It is not the same number as queuesPerFamily: that one says how many queues
	 that single family is asked for."

	^ 1
]

{ #category : 'constants' }
VkContext class >> queuePriority [
	"The highest priority the specification allows, since the one queue created competes with
	 nothing else in this project."

	^ 1.0
]

{ #category : 'constants' }
VkContext class >> queuePriorityByteCount [
	"A queue priority is a float, and the array of them has no field specification to read a
	 width from, so the stride is named here."

	^ 4
]

{ #category : 'constants' }
VkContext class >> queuesPerFamily [
	"One queue is created on the family the context chose. Every path in this project submits
	 from a single queue, and a device whose graphics and compute families differ is rejected
	 at selection rather than given a second queue here."

	^ 1
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

{ #category : 'initialization' }
VkContext >> buildCooperativeMatrixFeatures [
	"ExternalAddress allocate: hands back uninitialised memory, so the robust buffer access
	 field is written too, even though this context does not ask for it."
	| features |
	features := ExternalAddress allocate:
		            self class cooperativeMatrixFeaturesSize.
	features
		unsignedLongAt: 1
		put: VkStructureType physicalDeviceCooperativeMatrixFeaturesKHR.
	features pointerAt: 9 put: ExternalAddress null.
	features unsignedLongAt: 17 put: self class featureEnabled.
	features unsignedLongAt: 21 put: 0.
	^ features
]

{ #category : 'initialization' }
VkContext >> buildDeviceCreateInfo: aQueueCreateInfo [
	"The structure is declared field by field, so the driver reads what the accessors wrote.
	 Its store lives outside object memory, because the driver holds the pointer until
	 vkCreateDevice returns. Everything allocated here — the feature chain and the extension
	 name array with its names — is released by freeDeviceCreateInfo:; the queue create info is
	 the caller's and is released by freeDeviceQueueCreateInfo:."

	| names array |
	names := self enabledDeviceExtensionNames.
	array := self buildExtensionNameArray: names.
	^ VkDeviceCreateInfo externalInstance
		  pNext: self buildFeatureChain;
		  queueCreateInfoCount: self class queueCreateInfosPerDevice;
		  pQueueCreateInfos: aQueueCreateInfo getHandle;
		  enabledExtensionCount: names size;
		  ppEnabledExtensionNames:
			  (array ifNil: [ ExternalAddress null ]);
		  yourself
]

{ #category : 'initialization' }
VkContext >> buildDeviceQueueCreateInfo: familyIndex [
	"The structure is declared field by field, so the driver reads what the accessors wrote.
	 Its store and the priority array both live outside object memory, because the driver holds
	 the pointer until vkCreateDevice returns; freeDeviceQueueCreateInfo: releases both."

	^ VkDeviceQueueCreateInfo externalInstance
		  queueFamilyIndex: familyIndex;
		  queueCount: self class queuesPerFamily;
		  pQueuePriorities: self queuePriorityArrayOutsideObjectMemory;
		  yourself
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

{ #category : 'initialization' }
VkContext >> buildFeatureChain [
	"VkPhysicalDeviceSynchronization2Features (24 bytes): 0:sType 8:pNext 16:synchronization2.
	 Synchronization2 is the project's only sync API, so it is always asked for; the optional
	 structs hang off it, each only where the device has the matching extension."
	| sync2 |
	sync2 := ExternalAddress allocate: self class synchronization2FeaturesSize.
	sync2
		unsignedLongAt: 1
		put: VkStructureType physicalDeviceSynchronization2Features.
	sync2 pointerAt: 9 put: self buildOptionalFeatureChain.
	sync2 unsignedLongAt: 17 put: self class featureEnabled.
	^ sync2
]

{ #category : 'initialization' }
VkContext >> buildGraphicsDeviceCreateInfo: aQueueCreateInfo [
	"The graphics device asks for the swapchain extension and nothing else, so the name array
	 holds one name. Everything allocated here is released by freeGraphicsDeviceCreateInfo:."

	| names array |
	names := self class graphicsExtensionNames.
	array := self buildExtensionNameArray: names.
	^ VkDeviceCreateInfo externalInstance
		  pNext: self buildSynchronization2Features;
		  queueCreateInfoCount: self class queueCreateInfosPerDevice;
		  pQueueCreateInfos: aQueueCreateInfo getHandle;
		  enabledExtensionCount: names size;
		  ppEnabledExtensionNames: array;
		  yourself
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

{ #category : 'initialization' }
VkContext >> buildOptionalFeatureChain [
	"The structs that depend on what the device offers, linked in the order they are built.
	 The memory model goes in only beside cooperative matrix, which is the one path in this
	 project that needs the capability. Answers a null pointer when the device offers none of
	 them."

	| head |
	head := ExternalAddress null.
	self halfPrecisionAvailable ifTrue: [
		head := self chain: self buildHalfPrecisionFeatures onto: head ].
	(self cooperativeMatrixAvailable and: [ self vulkanMemoryModelAvailable ])
		ifTrue: [
			head := self chain: self buildVulkanMemoryModelFeatures onto: head.
			head := self chain: self buildCooperativeMatrixFeatures onto: head ].
	^ head
]

{ #category : 'initialization' }
VkContext >> buildSynchronization2Features [
	"VkPhysicalDeviceSynchronization2Features (24 bytes): 0:sType 8:pNext 16:synchronization2.
	 The chain the graphics device asks for holds this one structure: the optional half
	 precision structs are a compute concern and buildFeatureChain hangs them off its own copy.
	 Released by freeFeatureChain:, which walks whatever is on the chain."

	| sync2 |
	sync2 := ExternalAddress allocate: self class synchronization2FeaturesSize.
	sync2
		unsignedLongAt: 1
		put: VkStructureType physicalDeviceSynchronization2Features.
	sync2 pointerAt: 9 put: ExternalAddress null.
	sync2 unsignedLongAt: 17 put: self class featureEnabled.
	^ sync2
]

{ #category : 'initialization' }
VkContext >> buildVulkanMemoryModelFeatures [
	"Built through the structure class rather than from hand-written offsets, so the size and
	 the field positions come from the member list. externalInstance zeroes the block, which
	 leaves the device scope and availability-visibility chains flags off: this context asks
	 only for the memory model itself."

	| features |
	features := VkPhysicalDeviceVulkanMemoryModelFeatures externalInstance.
	features sType: VkPhysicalDeviceVulkanMemoryModelFeatures structureType.
	features pNext: ExternalAddress null.
	features vulkanMemoryModel: self class featureEnabled.
	^ features getHandle
]

{ #category : 'private' }
VkContext >> chain: aStruct onto: aSuccessor [
	"Links one struct in front of a chain. buildHalfPrecisionFeatures answers a pair already
	 linked together, so the successor goes at the end of what is handed in, not at offset 8
	 of its head."
	| last next |
	last := aStruct.
	[
	next := last pointerAt: 9.
	next isNull ] whileFalse: [ last := next ].
	last pointerAt: 9 put: aSuccessor.
	^ aStruct
]

{ #category : 'accessing' }
VkContext >> chosenDeviceName [
	^ chosenDeviceName ifNil: [ '' ]
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
VkContext >> createDeviceFromCreateInfo: aCreateInfo [
	"The one call both device paths make. The out parameter is a single handle and not a
	 structure, so it is one pointer wide and read at its only index."

	| devBuf result devHandle |
	devBuf := ExternalAddress allocate: self class pointerSize.
	^ [
	  result := Vk
		            createDevice: physicalDevice handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            deviceOut: devBuf.
	  Vk checkResult: result.
	  devHandle := VkDevice_H fromHandle: (devBuf pointerAt: 1).
	  device := VkDevice
		            on: devHandle
		            physicalDevice: physicalDevice
		            context: self ] ensure: [ devBuf free ]
]

{ #category : 'initialization' }
VkContext >> createGraphicsDevice [
	"The graphics path asks for the swapchain extension and for synchronization2, and nothing
	 the device happens to offer besides, so it builds its own create info rather than the one
	 buildDeviceCreateInfo: assembles from what the device supports."

	| queueInfo deviceInfo |
	queueInfo := self buildDeviceQueueCreateInfo: computeQueueFamily.
	[
	deviceInfo := self buildGraphicsDeviceCreateInfo: queueInfo.
	[ self createDeviceFromCreateInfo: deviceInfo ] ensure: [
		self freeDeviceCreateInfo: deviceInfo ] ] ensure: [
		self freeDeviceQueueCreateInfo: queueInfo ]
]

{ #category : 'initialization' }
VkContext >> createLogicalDevice [
	"The compute path asks the device what it offers and chains the optional feature structs
	 accordingly, which is what buildDeviceCreateInfo: assembles."

	| queueInfo deviceInfo |
	queueInfo := self buildDeviceQueueCreateInfo: computeQueueFamily.
	[
	deviceInfo := self buildDeviceCreateInfo: queueInfo.
	[ self createDeviceFromCreateInfo: deviceInfo ] ensure: [
		self freeDeviceCreateInfo: deviceInfo ] ] ensure: [
		self freeDeviceQueueCreateInfo: queueInfo ]
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
VkContext >> deviceChoiceRowFor: aSelector [
	| row |
	row := Dictionary new.
	row
		at: #requirement put: aSelector;
		at: #satisfiedBy put: self chosenDeviceName.
	^ row beReadOnlyObject
]

{ #category : 'reporting' }
VkContext >> deviceChoiceRows [
	"One row for the compute queue, which every context demands, then one per extra
	 requirement. The list is the one selection actually used, so the tab cannot drift from
	 it, and the rows survive destroy because the device name was copied at selection time."
	^ { self deviceChoiceRowFor: #findComputeQueueFamily }
	  , (self deviceRequirements collect: [ :selector |
			   self deviceChoiceRowFor: selector ])
]

{ #category : 'reporting' }
VkContext >> deviceFeatureReport [
	"Reads the chain back out instead of restating what buildFeatureChain writes."
	physicalDevice ifNil: [ ^ { ('Device' -> 'destroyed') } ].
	^ {
		  ('Half precision available' -> self halfPrecisionAvailable printString).
		  ('Cooperative matrix available'
		   -> self cooperativeMatrixAvailable printString).
		  ('Enabled extensions'
		   -> (', ' join: self enabledDeviceExtensionNames)).
		  ('Feature chain' -> (', ' join:
			    (self featureChainStructureNames collect: [ :each |
				     each asString ]))) }
]

{ #category : 'accessing' }
VkContext >> deviceRequirements [
	"No requirement at all is the plain compute case: any device with a compute queue."
	^ deviceRequirements ifNil: [ #() ]
]

{ #category : 'private' }
VkContext >> deviceSatisfiesRequirements: aPhysicalDevice [
	"A requirement the device cannot even be asked about is a mistake in the caller, not a
	 device that fails to qualify, so it is raised rather than answered false."
	^ self deviceRequirements allSatisfy: [ :selector |
		  (aPhysicalDevice respondsTo: selector) ifFalse: [
			  VkError signal:
				  'A physical device cannot be asked about: ' , selector ].
		  aPhysicalDevice perform: selector ]
]

{ #category : 'querying' }
VkContext >> enabledDeviceExtensionNames [
	"The device extensions this context asks for: each one only where the chosen device
	 reports it, because device creation fails on an extension the device does not have."
	^ (self halfPrecisionAvailable
		   ifTrue: [ self class halfPrecisionExtensionNames ]
		   ifFalse: [ #() ])
	  ,
	  (self cooperativeMatrixAvailable
		   ifTrue: [ { VkPhysicalDevice cooperativeMatrixExtensionName } ]
		   ifFalse: [ #() ])
]

{ #category : 'querying' }
VkContext >> extensionNamesIn: aCreateInfo [
	"Decodes the enabled extension names back out of a create info, reusing the physical
	 device's decoder so there is one place that walks a Vulkan name. The count and the array
	 come through the declared accessors; the array itself is an array of C strings and has no
	 field specification, so it is walked by the named stride."

	| count array stride |
	count := aCreateInfo enabledExtensionCount.
	array := aCreateInfo ppEnabledExtensionNames getHandle.
	(count = 0 or: [ array isNull ]) ifTrue: [ ^ #() ].
	stride := self class pointerSize.
	^ (1 to: count) collect: [ :index |
		  VkPhysicalDevice
			  extensionNameIn: (array pointerAt: index - 1 * stride + 1)
			  at: 0 ]
]

{ #category : 'reporting' }
VkContext >> featureChainStructureNames [
	"The structures the chain this context asks for actually contains, read back out of a
	 freshly built chain and freed again, so asking does not disturb the live device. A
	 structure type this image has no constant for reads as its raw number."
	| chain |
	chain := self buildFeatureChain.
	^ [
	  (self featureChainTypesIn: chain) collect: [ :each |
		  (VkStructureType nameForValue: each) ifNil: [ each ] ] ] ensure: [
		  self freeFeatureChain: chain ]
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

{ #category : 'initialization' }
VkContext >> freeDeviceCreateInfo: aCreateInfo [
	"Releases everything buildDeviceCreateInfo: allocated, the create info's own store
	 included: the pNext chain, the extension name array with each name in it, and the store.
	 Every field it needs is read through an accessor, so no offset is counted here."

	self freeFeatureChain: aCreateInfo pNext getHandle.
	self
		freeExtensionNameArray: aCreateInfo ppEnabledExtensionNames getHandle
		count: aCreateInfo enabledExtensionCount.
	aCreateInfo getHandle free
]

{ #category : 'initialization' }
VkContext >> freeDeviceQueueCreateInfo: aQueueCreateInfo [
	"Releases both blocks buildDeviceQueueCreateInfo: allocated. The pair exists because a
	 caller that freed only the structure leaked the priority array, which is what the hand
	 written callers did on the path where device creation raised."

	aQueueCreateInfo pQueuePriorities free.
	aQueueCreateInfo getHandle free
]

{ #category : 'initialization' }
VkContext >> freeExtensionNameArray: anArray count: aCount [
	"Paired with buildExtensionNameArray:, which allocated the array and every name in it. The
	 array of C strings is an array and not a structure, so it has no field specification and is
	 walked by the named stride; nil stands for the empty list the builder answers nothing for."

	| stride |
	(anArray isNil or: [ anArray isNull ]) ifTrue: [ ^ self ].
	stride := self class pointerSize.
	1 to: aCount do: [ :index |
		(anArray pointerAt: index - 1 * stride + 1) free ].
	anArray free
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
VkContext >> initializeComputeRequiring: aCollectionOfSelectors [
	deviceRequirements := aCollectionOfSelectors.
	^ self initializeCompute
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
VkContext >> inspectorDeviceChoice: aBuilder [
	"Why this device and not the first one enumerated: the requirements asked for, each
	 beside the device that satisfied them. Reflects the list selection used, and reads
	 nothing from the driver, so it also answers after the context is destroyed."
	<inspectorPresentationOrder: 20 title: 'Device choice'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Requirement' evaluated: [ :each |
					   each at: #requirement ]);
		  addColumn: (SpStringTableColumn title: 'Satisfied by' evaluated: [ :each |
					   each at: #satisfiedBy ]);
		  items: self deviceChoiceRows;
		  yourself
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

{ #category : 'initialization' }
VkContext >> queuePriorityArrayOutsideObjectMemory [
	"One float per queue asked for. This is an array of floats rather than a structure, so there
	 is no field specification to read an offset from and the stride is the named one."

	| priorities |
	priorities := ExternalAddress allocate:
		              self class queuesPerFamily
		              * self class queuePriorityByteCount.
	1 to: self class queuesPerFamily do: [ :index |
		priorities
			floatAt: index - 1 * self class queuePriorityByteCount + 1
			put: self class queuePriority ].
	^ priorities
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
	"A device qualifies when it has a compute queue and answers true to every requirement
	 the context was asked for. Position in the enumeration decides nothing by itself. The
	 chosen name is copied out now, because the handle it comes from dies with the instance."
	| handles |
	handles := Vk enumeratePhysicalDevices: instance.
	handles isEmpty ifTrue: [
		VkError signal: 'No Vulkan physical devices found' ].
	handles do: [ :handle |
		| candidate queueFamily |
		candidate := VkPhysicalDevice on: handle.
		queueFamily := candidate findComputeQueueFamily.
		(queueFamily notNil and: [ self deviceSatisfiesRequirements: candidate ])
			ifTrue: [
				physicalDevice := candidate.
				computeQueueFamily := queueFamily.
				chosenDeviceName := candidate properties deviceNameString.
				^ self ] ].
	VkError signal: self unsatisfiedRequirementsMessage
]

{ #category : 'querying' }
VkContext >> subgroupArithmeticAvailable [
	"Asks the device rather than assuming: a kernel that reduces across a subgroup needs the
	 arithmetic operations, which a device may leave out while still reporting a subgroup."

	^ physicalDevice supportsSubgroupArithmetic
]

{ #category : 'private' }
VkContext >> unsatisfiedRequirementsMessage [
	"Names what was asked for, because 'no suitable device' tells the reader nothing about
	 which capability the machine is missing."
	^ String streamContents: [ :stream |
		  stream nextPutAll: 'No device with a compute queue'.
		  self deviceRequirements do: [ :selector |
			  stream
				  nextPutAll: ' and ';
				  nextPutAll: selector ] ]
]

{ #category : 'querying' }
VkContext >> vulkanMemoryModelAvailable [
	"Asked of the device this context runs on. A cooperative matrix kernel needs it as much as
	 the extension: spirv-val refuses Shader plus CooperativeMatrixKHR without the
	 VulkanMemoryModel capability, and that capability needs this feature enabled."

	^ physicalDevice supportsVulkanMemoryModel
]
