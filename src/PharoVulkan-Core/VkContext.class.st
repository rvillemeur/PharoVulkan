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
		'chosenDeviceName',
		'surfaceExtensionNames'
	],
	#category : 'PharoVulkan-Core-Device',
	#package : 'PharoVulkan-Core',
	#tag : 'Device'
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

{ #category : 'constants' }
VkContext class >> computeInstanceExtensionNames [
	"The compute path needs no instance extension: it never presents to a surface, and
	 everything it calls is core Vulkan 1.3."

	^ #( )
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
	 dependent, which is why they are a list of their own. The name is taken from the device
	 class, which is where selection reads it to refuse a device that cannot present."

	^ { VkPhysicalDevice swapchainExtensionName }
]

{ #category : 'constants' }
VkContext class >> halfPrecisionExtensionNames [
    "Both are needed before a kernel may declare an f16 storage buffer: one for the type,
     one for 16-bit access to a buffer."
    ^ #( 'VK_KHR_shader_float16_int8' 'VK_KHR_16bit_storage' )
]

{ #category : 'constants' }
VkContext class >> instanceApiVersion [
	"Vulkan 1.3 is what the instance asks for, and it is not a free choice: the device
	 dispatch table carries vkQueueSubmit2 only from 1.3 on, and this project submits every
	 batch of work through it."

	^ VkApiVersion vulkan13
]

{ #category : 'factory' }
VkContext class >> offscreenGraphicsContext [
	"A device whose graphics and compute families differ would need a second queue,
	 which this context does not create, so it does not qualify rather than failing later
	 when a draw is submitted on a queue that cannot accept it."
	^ self computeContextRequiring: #( #supportsGraphicsAndComputeOnOneQueue )
]

{ #category : 'constants' }
VkContext class >> onlyQueueIndex [
"Queues are indexed from zero inside their family, and queuesPerFamily creates one, so the
	 queue every path of this project submits from is at index zero. Named here because the
	 number is the consequence of that decision and not a free choice of the call site."

^ 0
]

{ #category : 'constants' }
VkContext class >> pointerSize [
    ^ 8
]

{ #category : 'instance creation' }
VkContext class >> presentingContextForExtensions: aNameCollection [
	"One context for compute and for presentation both. The instance carries the surface
	 extensions the window system named, and the device is chosen and built by the compute path,
	 so the kernels keep every feature buildFeatureChain asks for. The queue family must do
	 graphics and compute both, because this context creates one queue and dispatches and
	 presents on that one."

	^ self new initializePresentingForExtensions: aNameCollection
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

{ #category : 'private' }
VkContext >> allocateCString: aString [
	"Vulkan takes names as NUL-terminated C strings; the caller owns the memory and frees it."

	| bytes buf |
	bytes := aString asByteArray copyWith: 0.
	buf := ExternalAddress allocate: bytes size.
	bytes doWithIndex: [ :byte :i | buf byteAt: i put: byte ].
	^ buf
]

{ #category : 'private - instance' }
VkContext >> buildApplicationInfo [
	"The application info both instance paths pass. Only the API version is asked for; the
	 application and engine names are the fields a driver may match a workaround on, and this
	 project wants none, so they stay the null pointers a fresh store gives."

	^ VkApplicationInfo externalInstance
		  apiVersion: self class instanceApiVersion;
		  yourself
]

{ #category : 'initialization' }
VkContext >> buildCooperativeMatrixFeatures [
	"Robust buffer access is left off: a kernel here reads only inside the buffers it was
	 given. externalInstance zeroes the block, which is what writes that flag off."

	^ VkPhysicalDeviceCooperativeMatrixFeaturesKHR externalInstance
		  cooperativeMatrix: self class featureEnabled;
		  getHandle
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
	 hold a null pointer beside its count of none. The caller owns the array and every C string
	 in it: freeExtensionNameArray:count: releases them."

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
	"Synchronization2 is the project's only sync API, so it is always asked for; the optional
	 structs hang off it, each only where the device has the matching extension."

	| sync2 |
	sync2 := VkPhysicalDeviceSynchronization2Features externalInstance
		         synchronization2: self class featureEnabled;
		         pNext: self buildOptionalFeatureChain;
		         yourself.
	^ sync2 getHandle
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

{ #category : 'initialization' }
VkContext >> buildHalfPrecisionFeatures [
	"The pair the half precision path asks for, already linked: sixteen bit storage buffers to
	 hold the halves and shaderFloat16 to compute with them. Each structure declares flags this
	 project leaves off — integer eight bit arithmetic, and sixteen bit uniforms, push
	 constants and interface variables — and externalInstance zeroes the block, which is what
	 writes them off."

	| float16 storage16 |
	storage16 := VkPhysicalDevice16BitStorageFeatures externalInstance
		             storageBuffer16BitAccess: self class featureEnabled;
		             yourself.
	float16 := VkPhysicalDeviceShaderFloat16Int8Features externalInstance
		           shaderFloat16: self class featureEnabled;
		           pNext: storage16 getHandle;
		           yourself.
	^ float16 getHandle
]

{ #category : 'private - instance' }
VkContext >> buildInstanceCreateInfo: anApplicationInfo extensions: aNameCollection [
	"The struct vkCreateInstance is given, for both paths: the compute path asks for no
	 instance extensions, the graphics path for the ones SDL names. The application info
	 belongs to the caller, which is why it is passed in and freed there."

	| array |
	array := self buildExtensionNameArray: aNameCollection.
	^ VkInstanceCreateInfo externalInstance
		  pApplicationInfo: anApplicationInfo getHandle;
		  enabledExtensionCount: aNameCollection size;
		  ppEnabledExtensionNames:
			  (array ifNil: [ ExternalAddress null ]);
		  yourself
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
	"The chain the graphics device asks for holds this one structure: the optional half
	 precision structs are a compute concern and buildFeatureChain hangs them off its own copy.
	 The store lives outside object memory and is released by freeFeatureChain:, which walks
	 whatever is on the chain."

	^ VkPhysicalDeviceSynchronization2Features externalInstance
		  synchronization2: self class featureEnabled;
		  getHandle
]

{ #category : 'initialization' }
VkContext >> buildVulkanMemoryModelFeatures [
	"The device scope and the availability-visibility chains are left off: this context asks
	 only for the memory model itself, which is what a cooperative matrix kernel needs.
	 externalInstance zeroes the block, which is what writes those two off."

	^ VkPhysicalDeviceVulkanMemoryModelFeatures externalInstance
		  vulkanMemoryModel: self class featureEnabled;
		  getHandle
]

{ #category : 'initialization' }
VkContext >> chain: aStruct onto: aSuccessor [
	"Links one struct in front of a chain. buildHalfPrecisionFeatures answers a pair already
	 linked together, so the successor goes at the end of what is handed in, not behind its
	 head. Each link is read and written through VkBaseOutStructure, the header every structure
	 in a chain starts with, so no offset is counted here."

	| last next |
	last := VkBaseOutStructure fromHandle: aStruct.
	[
	next := last pNext getHandle.
	next isNull ] whileFalse: [ last := VkBaseOutStructure fromHandle: next ].
	last pNext: aSuccessor.
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
		  device := VkDevice on: devHandle physicalDevice: physicalDevice ]
		  ensure: [ devBuf free ]
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

{ #category : 'private - instance' }
VkContext >> createInstanceFromCreateInfo: aCreateInfo [
	"The one vkCreateInstance call both paths make. The out parameter is a single handle and
	 not a structure, so it is one pointer wide and read at its only index."

	| buf result |
	buf := ExternalAddress allocate: self class pointerSize.
	^ [
	  result := Vk
		            primCreateInstance: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            instanceOut: buf.
	  Vk checkResult: result.
	  instance := VkInstance_H fromHandle: (buf pointerAt: 1) ] ensure: [
		  buf free ]
]

{ #category : 'private - instance' }
VkContext >> createInstanceWithExtensions: aNameCollection [
	"Both paths differ only in the instance extensions they name, so both come through here.
	 Each block is freed by the method paired with the one that built it, in an ensure:, so a
	 refused vkCreateInstance leaks nothing."

	| appInfo createInfo |
	appInfo := self buildApplicationInfo.
	^ [
	  createInfo := self
		                buildInstanceCreateInfo: appInfo
		                extensions: aNameCollection.
	  [ self createInstanceFromCreateInfo: createInfo ] ensure: [
		  self freeInstanceCreateInfo: createInfo ] ] ensure: [
		  self freeApplicationInfo: appInfo ]
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

{ #category : 'device creation' }
VkContext >> enabledDeviceExtensionNames [
	"The device extensions this context asks for: each one only where the chosen device
	 reports it, because device creation fails on an extension the device does not have.
	 A presenting context adds the swapchain extension, which its device was required to
	 report when it was selected."

	^ (self halfPrecisionAvailable
		   ifTrue: [ self class halfPrecisionExtensionNames ]
		   ifFalse: [ #() ])
	  ,
	  (self cooperativeMatrixAvailable
		   ifTrue: [ { VkPhysicalDevice cooperativeMatrixExtensionName } ]
		   ifFalse: [ #() ])
	  ,
	  (surfaceExtensionNames
		   ifNil: [ #() ]
		   ifNotNil: [ self class graphicsExtensionNames ])
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

{ #category : 'querying' }
VkContext >> featureChainTypesIn: aStruct [
	"Every structure in a pNext chain starts with the VkBaseOutStructure header, so the chain
	 can be read back without knowing which structures are on it. The view declares no
	 constant field of its own, so reading a structure through it leaves that structure's own
	 type alone."

	| types current |
	types := OrderedCollection new.
	current := aStruct.
	[ current isNull ] whileFalse: [
		| header |
		header := VkBaseOutStructure fromHandle: current.
		types add: header sType.
		current := header pNext getHandle ].
	^ types asArray
]

{ #category : 'initialization' }
VkContext >> fetchComputeQueue [
	"The out parameter is a single handle and not a structure, so it is one pointer wide and
	 read at its only index, the way createInstanceFromCreateInfo: reads its own."

	| buf |
	buf := ExternalAddress allocate: self class pointerSize.
	computeQueue := [
	                Vk
		                getDeviceQueue: device handle
		                queueFamilyIndex: computeQueueFamily
		                queueIndex: self class onlyQueueIndex
		                queue: buf.
	                VkQueue on: (VkQueue_H fromHandle: (buf pointerAt: 1)) ]
		                ensure: [ buf free ]
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
		                VkQueue on:
			                (VkQueue_H fromHandle: (buf pointerAt: 1)) ]
		                ensure: [ buf free ]
]

{ #category : 'private - instance' }
VkContext >> freeApplicationInfo: anApplicationInfo [
	"Paired with buildApplicationInfo. The structure owns no other block, because the names
	 it could point at were never allocated."

	anApplicationInfo getHandle free
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

{ #category : 'initialization' }
VkContext >> freeFeatureChain: aStruct [
	"Walks the chain forward through the VkBaseOutStructure header, keeping the successor
	 before freeing the struct that holds it."

	| current next |
	current := aStruct.
	[ current isNull ] whileFalse: [
		next := (VkBaseOutStructure fromHandle: current) pNext getHandle.
		current free.
		current := next ]
]

{ #category : 'private - instance' }
VkContext >> freeInstanceCreateInfo: aCreateInfo [
	"Paired with buildInstanceCreateInfo:extensions:, which allocated the name array and the
	 structure. The application info is the caller's and is not freed here."

	self
		freeExtensionNameArray: aCreateInfo ppEnabledExtensionNames getHandle
		count: aCreateInfo enabledExtensionCount.
	aCreateInfo getHandle free
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
	self createInstanceWithExtensions: self instanceExtensionNames.
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
VkContext >> initializeGraphicsWithExtensions: aNameCollection [
	"The names come from SDL_Vulkan_GetInstanceExtensions: whatever the window system needs
	 to put a surface on a window."

	self createInstanceWithExtensions: aNameCollection.
	self selectGraphicsPhysicalDevice.
	self createGraphicsDevice.
	self fetchGraphicsQueue.
	^ self
]

{ #category : 'initialization' }
VkContext >> initializePresentingForExtensions: aNameCollection [
	"The names are remembered because two later steps read them: the instance is created with
	 them, and enabledDeviceExtensionNames adds the swapchain extension only for a context that
	 has them."

	surfaceExtensionNames := aNameCollection.
	^ self initializeComputeRequiring:
		  #( #supportsGraphicsAndComputeOnOneQueue #supportsSwapchain )
]

{ #category : 'inspector' }
VkContext >> inspectorDeviceChoice: aBuilder [
	"Why this device and not the first one enumerated: the requirements asked for, each
	 beside the device that satisfied them. Reflects the list selection used, and reads
	 nothing from the driver, so it also answers after the context is destroyed."

	<inspectorPresentationOrder: 20 title: 'Device choice'>
	^ PVFactRow
		  tableOf: (self deviceChoiceRows collect: [ :each |
				   PVFactRow
					   name: (each at: #requirement)
					   value: (each at: #satisfiedBy) ])
		  nameColumn: 'Requirement'
		  valueColumn: 'Satisfied by'
		  in: aBuilder
]

{ #category : 'inspector' }
VkContext >> inspectorDeviceFeatures: aBuilder [

	<inspectorPresentationOrder: 10 title: 'Device features'>
	^ PVFactRow
		  tableOf: (self deviceFeatureReport collect: [ :each |
				   PVFactRow name: each key value: each value ])
		  nameColumn: 'Setting'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing' }
VkContext >> instance [
    ^ instance
]

{ #category : 'accessing' }
VkContext >> instanceExtensionNames [
	"What the instance of this context is created with: nothing for plain compute, and whatever
	 the window system named for a context that also presents."

	^ surfaceExtensionNames ifNil: [ self class computeInstanceExtensionNames ]
]

{ #category : 'accessing' }
VkContext >> physicalDevice [
    ^ physicalDevice
]

{ #category : 'private' }
VkContext >> queuePriorityArrayOutsideObjectMemory [
	"One float per queue asked for. This is an array of floats rather than a structure, so there
	 is no field specification to read an offset from and the stride is the named one. The caller
	 owns the block: freeDeviceQueueCreateInfo: releases it with the structure that points at it."

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

{ #category : 'accessing' }
VkContext >> surfaceExtensionNames [
	"The surface instance extensions this context was created with, or nil for a compute-only
	 one. A caller that holds a window compares its own names against these: an instance created
	 without the extension a window needs cannot make a surface on it."

	^ surfaceExtensionNames
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
