"
SUnit test suite for core Vulkan lifecycle: VkContext creation, physical device selection, queue retrieval, buffer allocation/mapping, and command pool/buffer allocation.
"
Class {
	#name : 'VkCoreTest',
	#superclass : 'TestCase',
	#instVars : [
		'ctx'
	],
	#category : 'PharoVulkan-Tests-Core',
	#package : 'PharoVulkan-Tests',
	#tag : 'Core'
}

{ #category : 'private' }
VkCoreTest >> configurationWithDistinctMembers [
	"A configuration decoded from a block this test wrote itself, one different number per
	 member, so a wrong offset shows as a swapped pair instead of passing by accident. No
	 device is involved: the layout is what is under test."
	| buffer configuration |
	buffer := ExternalAddress allocate:
		          VkCooperativeMatrixConfiguration structureByteSize.
	^ [
	  VkCooperativeMatrixConfiguration prepareEntriesIn: buffer count: 1.
	  VkCooperativeMatrixConfiguration memberFieldNames withIndexDo: [ :name :index |
		  buffer
			  unsignedLongAt: (VkCooperativeMatrixConfiguration offsetOf: name) + 1
			  put: index * 3 ].
	  configuration := VkCooperativeMatrixConfiguration readFrom: buffer at: 0 ]
		  ensure: [ buffer free ]
]

{ #category : 'helpers' }
VkCoreTest >> floatArrayToBytes: anArray [
	"Pack float array as little-endian IEEE 754 32-bit words"
	| bytes |
	bytes := ByteArray new: anArray size * 4.
	anArray doWithIndex: [:f :i |
		| word base |
		word := f asFloat asIEEE32BitWord.
		base := (i - 1) * 4 + 1.
		bytes at: base     put: (word bitAnd: 16rFF).
		bytes at: base + 1 put: ((word >> 8)  bitAnd: 16rFF).
		bytes at: base + 2 put: ((word >> 16) bitAnd: 16rFF).
		bytes at: base + 3 put: ((word >> 24) bitAnd: 16rFF)].
	^ bytes
]

{ #category : 'running' }
VkCoreTest >> setUp [

	super setUp.
	ctx := VkContext computeContext
]

{ #category : 'running' }
VkCoreTest >> tearDown [

	ctx destroy.
	super tearDown
]

{ #category : 'tests' }
VkCoreTest >> testBufferCapacityCheckAnswersWhatAWriteWouldDo [
	"The inspector view and the write share one predicate. The fact to state is that the
	 predicate and the write agree at the boundary, including the empty and exact cases."

	| buf capacity |
	capacity := 16.
	buf := VkBuffer on: ctx device size: capacity usage: VkBuffer storageBufferUsage.
	[
	#( 0 8 16 ) do: [ :count |
		self assert: (buf fitsByteCount: count).
		buf copyFromByteArray: (ByteArray new: count) ].
	self deny: (buf fitsByteCount: capacity + 1).
	self
		should: [ buf copyFromByteArray: (ByteArray new: capacity + 1) ]
		raise: SizeMismatch ] ensure: [ buf destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testBufferRefusesMoreBytesThanItHolds [
	"The bytes leave through a mapped raw pointer, so an oversized collection would write past
	 the mapping instead of failing. The sizes must be compared before the first byte moves.
	 An exact fit and an empty write are the degenerate cases that must still go through."

	| buf capacity |
	capacity := 16.
	buf := VkBuffer on: ctx device size: capacity usage: VkBuffer storageBufferUsage.
	[
	self
		should: [ buf copyFromByteArray: (ByteArray new: capacity + 1) ]
		raise: SizeMismatch.
	self
		should: [ buf put: (1 to: capacity // 4 + 1) asArray as: #f32 ]
		raise: SizeMismatch.
	buf copyFromByteArray: (ByteArray new: capacity).
	buf copyFromByteArray: (ByteArray new: 0) ] ensure: [ buf destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testBufferRoundtrip [
	"Write float data to HOST_VISIBLE buffer, read back, verify bytes match"
	| buf data out |
	buf := VkBuffer on: ctx device size: 256 usage: 32.
	[
		data := self floatArrayToBytes: ((1 to: 64) asArray collect: [:i | i - 1]).
		buf copyFromByteArray: data.
		out := buf copyToByteArray.
		self assert: out equals: data
	] ensure: [ buf destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testChainedPropertiesQueryLinksTheBlockItIsGiven [
	"The chain is built outside the image and freed again, so the query hands both structures to
	 a block instead of answering memory that has gone. The facts: the head carries its own
	 structure type, its pNext holds the address of the chained block, the block keeps the type
	 it was given, and the driver filled it. pNext reads back as a void pointer rather than an
	 ExternalAddress, so the two are compared as the addresses they are."

	| device verdict |
	device := ctx physicalDevice.
	verdict := VkPhysicalDeviceProperties2
		           of: device handle
		           chainedWith: VkPhysicalDeviceSubgroupProperties
		           do: [ :head :block |
			           {
				           head sType.
				           head pNext asInteger = block getHandle asInteger.
				           block sType.
				           block subgroupSize } ].
	self assert: verdict first equals: VkStructureType physicalDeviceProperties2.
	self assert: verdict second.
	self
		assert: verdict third
		equals: VkStructureType physicalDeviceSubgroupProperties.
	self assert: verdict fourth equals: 32
]

{ #category : 'tests' }
VkCoreTest >> testComputeContextCreation [
	self assert: ctx device notNil.
	self assert: ctx computeQueue notNil.
	self assert: ctx physicalDevice notNil
]

{ #category : 'tests' }
VkCoreTest >> testComputeContextEnablesHalfPrecisionWhenTheDeviceOffersIt [
	"Half precision is gated rather than assumed, so this states the gate both ways round and
	 keeps passing on a device without the extensions."

	| wanted |
	wanted := VkContext halfPrecisionExtensionNames.
	ctx halfPrecisionAvailable
		ifTrue: [
			self assert: (wanted allSatisfy: [ :each |
					 ctx enabledDeviceExtensionNames includes: each ]) ]
		ifFalse: [
			self assert: (wanted anySatisfy: [ :each |
					 (ctx physicalDevice supportsExtension: each) not ]) ]
]

{ #category : 'tests' }
VkCoreTest >> testComputeContextEnablesOnlyExtensionsTheDeviceSupports [
	"Asking for an extension the driver does not have fails device creation, so the enabled
	 list may never run ahead of what the physical device reports."

	ctx enabledDeviceExtensionNames do: [ :each |
		self assert: (ctx physicalDevice supportsExtension: each) ]
]

{ #category : 'tests' }
VkCoreTest >> testComputeLimitsOfThisDeviceAgreeWithTheDriver [
	"The compute limits the emitter needs reach it through generated accessors on
	 VkPhysicalDeviceLimits. A wrong offset answers a plausible number rather than an error, so
	 the facts are pinned against what this machine's driver really reports: 48 KiB of shared
	 memory and 1024 invocations per work group. The last assertion holds on every device, not
	 only this one: no single dimension of a work group can hold more invocations than a whole
	 work group may have."

	| device |
	device := ctx physicalDevice.
	self assert: device maxComputeSharedMemorySize equals: 48 * 1024.
	self assert: device maxComputeWorkGroupInvocations equals: 1024.
	self assert: device maxComputeWorkGroupSize size equals: 3.
	self assert: (device maxComputeWorkGroupSize allSatisfy: [ :each |
			 each between: 1 and: device maxComputeWorkGroupInvocations ])
]

{ #category : 'tests' }
VkCoreTest >> testConfigurationDecodesEveryMemberTheLayoutDeclares [
	| configuration |
	configuration := self configurationWithDistinctMembers.
	VkCooperativeMatrixConfiguration memberFieldNames withIndexDo: [ :name :index |
		self assert: (configuration perform: name) equals: index * 3 ]
]

{ #category : 'tests' }
VkCoreTest >> testConfigurationRowsNameEveryMemberWithoutChangingIt [
	| configuration before rows |
	configuration := self configurationWithDistinctMembers.
	before := VkCooperativeMatrixConfiguration memberFieldNames collect: [ :name |
		          configuration perform: name ].
	rows := configuration configurationRows.
	self
		assert: (rows collect: [ :each | each at: #member ])
		equals: VkCooperativeMatrixConfiguration memberFieldNames.
	self
		assert: (VkCooperativeMatrixConfiguration memberFieldNames collect: [ :name |
				 configuration perform: name ])
		equals: before
]

{ #category : 'tests' }
VkCoreTest >> testContextAsksForCooperativeMatrixExactlyWhenItsDeviceOffersIt [
	"The capability in a module is invalid unless the feature was enabled at device
	 creation, and asking for the extension on a device without it fails device creation,
	 so the two have to follow the device rather than a flag chosen by hand."
	self
		assert: (ctx enabledDeviceExtensionNames includes:
				 VkPhysicalDevice cooperativeMatrixExtensionName)
		equals: ctx cooperativeMatrixAvailable.
	self
		assert: (ctx featureChainStructureNames includes:
				 #physicalDeviceCooperativeMatrixFeaturesKHR)
		equals: ctx cooperativeMatrixAvailable
]

{ #category : 'tests' }
VkCoreTest >> testContextEnablesTheVulkanMemoryModelWhereItAsksForCooperativeMatrix [
	"spirv-val refuses a module that declares Shader and CooperativeMatrixKHR without
	 VulkanMemoryModel, and that capability needs the matching device feature, so the two
	 have to be enabled together. The default context may well land on a device without the
	 extension, so a context built by requiring the capability is checked too."

	| survey |
	self
		assert: (ctx featureChainStructureNames includes:
				 #physicalDeviceVulkanMemoryModelFeatures)
		equals:
			(ctx cooperativeMatrixAvailable and: [ ctx vulkanMemoryModelAvailable ]).
	survey := PVCooperativeMatrixSurvey new setContext: ctx.
	survey availableSomewhere ifFalse: [ ^ self ].
	VkContext cooperativeMatrixContext ifNotNil: [ :coopContext |
		[
		self assert: coopContext cooperativeMatrixAvailable.
		self assert: coopContext vulkanMemoryModelAvailable.
		self assert: (coopContext featureChainStructureNames includes:
				 #physicalDeviceVulkanMemoryModelFeatures).
		self assert: (coopContext featureChainStructureNames includes:
				 #physicalDeviceCooperativeMatrixFeaturesKHR) ] ensure: [
			coopContext destroy ] ]
]

{ #category : 'tests' }
VkCoreTest >> testContextRequiringACapabilityNoDeviceCanBeAskedAboutFailsNamingIt [
	| error |
	error := [
	         VkContext computeContextRequiring:
		         #( #supportsSomethingNoDeviceAnswers ) ]
		         on: VkError
		         do: [ :signal | signal ].
	self assert: (error messageText includesSubstring:
			 'supportsSomethingNoDeviceAnswers')
]

{ #category : 'tests' }
VkCoreTest >> testContextRequiringCooperativeMatrixPicksADeviceThatSupportsIt [
	"Consistency rather than this machine's device list: where some device offers the
	 extension the context must land on one of those, and where none does the request must
	 fail instead of falling back to a device that cannot run the kernel."
	| offeredSomewhere |
	offeredSomewhere := (Vk enumeratePhysicalDevices: ctx instance) anySatisfy: [
		                    :handle |
		                    (VkPhysicalDevice on: handle)
			                    supportsCooperativeMatrix ].
	offeredSomewhere
		ifTrue: [
			| required |
			required := VkContext cooperativeMatrixContext.
			[ self assert: required physicalDevice supportsCooperativeMatrix ] ensure: [
				required destroy ] ]
		ifFalse: [ self should: [ VkContext cooperativeMatrixContext ] raise: VkError ]
]

{ #category : 'tests' }
VkCoreTest >> testCooperativeMatrixAvailabilityOnTheContextAgreesWithItsDevice [
	"VkContext answers for the device it actually runs kernels on, which is what a kernel
	 path would have to gate on."

	self
		assert: ctx cooperativeMatrixAvailable
		equals: ctx physicalDevice supportsCooperativeMatrix
]

{ #category : 'tests-cooperative-matrix' }
VkCoreTest >> testCooperativeMatrixConfigurationsAreEmptyWhereTheExtensionIsAbsent [
	"A device that never reported the extension has nothing to offer, and the query must
	 answer that rather than reading a count the driver never wrote."

	| devices |
	devices := (Vk enumeratePhysicalDevices: ctx instance) collect: [ :each |
		           VkPhysicalDevice on: each ].
	(devices reject: [ :each | each supportsCooperativeMatrix ]) do: [ :each |
		self assert:
			(each cooperativeMatrixConfigurationsOn: ctx instance) isEmpty ]
]

{ #category : 'tests' }
VkCoreTest >> testCooperativeMatrixExtensionNameIsTheKhrOne [
	"The name is a constant rather than a literal at each call site, and it must be the name a
	 driver can report: every Vulkan extension name carries the prefix."

	self
		assert: VkPhysicalDevice cooperativeMatrixExtensionName
		equals: VkPhysicalDevice extensionNamePrefix , 'KHR_cooperative_matrix'
]

{ #category : 'tests' }
VkCoreTest >> testCooperativeMatrixSkipReasonNamesTheExtensionWhenTheContextDeviceLacksIt [
	"The skip must say why it happened, and nothing is skipped on a device that has the
	 extension. The test states the implication rather than this machine's answer, so it
	 holds on a device of either kind."

	| survey |
	survey := PVCooperativeMatrixSurvey on: ctx.
	survey availableOnContextDevice
		ifTrue: [ self assert: survey skipReason isNil ]
		ifFalse: [
			self assert: (survey skipReason includesSubstring:
					 VkPhysicalDevice cooperativeMatrixExtensionName) ]
]

{ #category : 'tests' }
VkCoreTest >> testCooperativeMatrixSupportAgreesWithTheExtensionList [
	"The predicate asks the extension list the driver reported, so it cannot answer yes on a
	 device whose list lacks the extension."

	self
		assert: ctx physicalDevice supportsCooperativeMatrix
		equals: (ctx physicalDevice extensionNames includes:
				 VkPhysicalDevice cooperativeMatrixExtensionName)
]

{ #category : 'tests' }
VkCoreTest >> testCooperativeMatrixSurveyCoversEveryPhysicalDevice [
	"The survey asks every device the loader offers, not only the one the context chose. On
	 this machine the chosen device and the supporting device are not the same one."

	| survey |
	survey := PVCooperativeMatrixSurvey on: ctx.
	self
		assert: survey deviceReports size
		equals: (Vk enumeratePhysicalDevices: ctx instance) size
]

{ #category : 'tests' }
VkCoreTest >> testCooperativeMatrixSurveyNamesTheDevicesThatSupportIt [
	"Availability anywhere on the machine and availability on the device the context runs on
	 are different facts, and the survey answers both. Every supporting name must come from a
	 report that says so, so the two cannot disagree."

	| survey |
	survey := PVCooperativeMatrixSurvey on: ctx.
	self
		assert: survey availableSomewhere
		equals: survey supportingDeviceNames notEmpty.
	survey supportingDeviceNames do: [ :each |
		self assert: (survey deviceReports anySatisfy: [ :report |
				 (report at: #name) = each and: [ report at: #supported ] ]) ]
]

{ #category : 'tests' }
VkCoreTest >> testCooperativeMatrixSurveyReportsAfterItsContextIsGone [
	"The example destroys the context it built, and a destroyed context enumerates nothing, so
	 the survey must hold what it read rather than ask again when the table is drawn."

	| survey |
	survey := PVCooperativeMatrixSurvey exampleSurveyOfThisMachine.
	self assert: survey deviceReports notEmpty.
	self assert: (survey reportRows last at: #name) equals: 'Verdict'
]

{ #category : 'tests - descriptors' }
VkCoreTest >> testDescriptorPoolCountsSetsAndDescriptorsSeparately [
	"One set holding three storage-buffer descriptors is the shape every compute kernel here
	 allocates, and it needs two different numbers: maxSets 1, descriptorCount 3. A pool that
	 takes one number asks the driver for three sets where one is enough, and a kernel with no
	 buffers asks it for none."
	| layout pool set buffers |
	set := nil.
	buffers := (1 to: VkDescriptorPool exampleDescriptorCount) collect: [ :each |
		           VkBuffer
			           storageBuffer: VkDescriptorPool exampleElementCount
			           on: ctx device ].
	layout := VkDescriptorSetLayout on: ctx device.
	0 to: VkDescriptorPool exampleDescriptorCount - 1 do: [ :binding |
		layout
			addStorageBufferBinding: binding
			stageFlags: VkShaderStage computeBit ].
	layout create.
	pool := VkDescriptorPool
		        on: ctx device
		        maxSets: VkDescriptorPool exampleMaxSets
		        descriptorCount: VkDescriptorPool exampleDescriptorCount.
	[
	set := pool allocateSet: layout.
	buffers doWithIndex: [ :buffer :index |
		set updateStorageBuffer: buffer atBinding: index - 1 ].
	self assert: pool maxSets equals: VkDescriptorPool exampleMaxSets.
	self
		assert: pool descriptorCount
		equals: VkDescriptorPool exampleDescriptorCount.
	self assert: pool setsAllocated equals: VkDescriptorPool exampleMaxSets ]
		ensure: [
			set ifNotNil: [ set handle invalidate ].
			pool destroy.
			layout destroy.
			buffers do: [ :each | each destroy ] ]
]

{ #category : 'tests - descriptors' }
VkCoreTest >> testDescriptorPoolViewNamesBothCountsAndTheTypeItRequests [
	"The example releases the pool, its set and its context, as every example here does, so
	 the Pool tab must read the counts the instance kept. The descriptor type row is found by
	 asking VkDescriptorType which constant answers the value the create info writes, so it
	 cannot name a type the pool does not request. Building the tab must not change what the
	 pool reports."
	| pool rows |
	pool := VkDescriptorPool exampleStorageBufferPoolForThreeBuffers.
	rows := pool poolReport.
	self
		assert: (self valueOfRowNamed: VkDescriptorPool maxSetsRowName in: rows)
		equals: VkDescriptorPool exampleMaxSets printString.
	self
		assert:
		(self valueOfRowNamed: VkDescriptorPool descriptorCountRowName in: rows)
		equals: VkDescriptorPool exampleDescriptorCount printString.
	self
		assert:
		(self valueOfRowNamed: VkDescriptorPool setsAllocatedRowName in: rows)
		equals: VkDescriptorPool exampleMaxSets printString.
	self
		assert:
		(self valueOfRowNamed: VkDescriptorPool descriptorTypeRowName in: rows)
		equals: #storageBuffer asString.
	pool inspectorPool: SpPresenter new.
	self
		assertCollection: (pool poolReport collect: [ :each | each at: #value ])
		hasSameElements: (rows collect: [ :each | each at: #value ]).
	self
		assert:
		(self
			 valueOfRowNamed: VkDescriptorPool setsAllocatedRowName
			 in: VkDescriptorPool new poolReport)
		equals: 0 printString
]

{ #category : 'tests' }
VkCoreTest >> testDeviceChoiceRowsNameEveryRequirementAsked [
	| context asked |
	context := VkContext computeContextRequiring:
		           #( #supportsSubgroupArithmetic ).
	context destroy.
	asked := context deviceChoiceRows collect: [ :each |
		         each at: #requirement ].
	self assert: (asked includes: #supportsSubgroupArithmetic)
]

{ #category : 'tests' }
VkCoreTest >> testDeviceChoiceRowsNameTheDeviceAfterTheContextIsGone [
	"The rows are what the inspector tab shows, and the example destroys its context before
	 handing it over, so the choice has to be recorded rather than re-queried."
	| context rows |
	context := VkContext computeContext.
	context destroy.
	rows := context deviceChoiceRows.
	self assert: rows size equals: context deviceRequirements size + 1.
	self deny: context chosenDeviceName isEmpty.
	self
		assert: (rows collect: [ :each | each at: #satisfiedBy ])
		equals: (rows collect: [ :each | context chosenDeviceName ])
]

{ #category : 'tests' }
VkCoreTest >> testDeviceCreateInfoCarriesEveryEnabledExtension [
	"Reads back the struct handed to vkCreateDevice: an extension the context says it enables
	 counts for nothing unless it reaches that field."

	| queueInfo info |
	queueInfo := ctx buildDeviceQueueCreateInfo: ctx computeQueueFamily.
	info := ctx buildDeviceCreateInfo: queueInfo.
	[
	self
		assert: (ctx extensionNamesIn: info) asArray
		equals: ctx enabledDeviceExtensionNames asArray ] ensure: [
		ctx freeDeviceCreateInfo: info.
		
		ctx freeDeviceQueueCreateInfo: queueInfo ]
]

{ #category : 'tests' }
VkCoreTest >> testDeviceCreateInfoChainsTheHalfPrecisionFeatureStructs [
	"Synchronization2 is always asked for; the two half precision structs follow it only where
	 the device offers the extensions."

	| queueInfo info types half |
	queueInfo := ctx buildDeviceQueueCreateInfo: ctx computeQueueFamily.
	info := ctx buildDeviceCreateInfo: queueInfo.
	[
	types := ctx featureChainTypesIn: info pNext getHandle.
	half := {
		        VkStructureType physicalDeviceShaderFloat16Int8Features.
		        VkStructureType physicalDevice16BitStorageFeatures }.
	self
		assert: types first
		equals: VkStructureType physicalDeviceSynchronization2Features.
	ctx halfPrecisionAvailable
		ifTrue: [
			self assert: (half allSatisfy: [ :each | types includes: each ]) ]
		ifFalse: [
			self assert: (half noneSatisfy: [ :each | types includes: each ]) ] ]
		ensure: [
			ctx freeDeviceCreateInfo: info.
			
			ctx freeDeviceQueueCreateInfo: queueInfo ]
]

{ #category : 'tests' }
VkCoreTest >> testDeviceQueueCreateInfoAsksForOneQueueAtFullPriority [
	"Read back from the struct handed to vkCreateDevice: the family the context chose, one
	 queue, and one priority per queue asked for. The priorities are an array of floats and not
	 a structure, so they are read through the store by the named stride, which is what the
	 driver does too."

	| info priorities |
	info := ctx buildDeviceQueueCreateInfo: ctx computeQueueFamily.
	[
	self assert: info queueFamilyIndex equals: ctx computeQueueFamily.
	self assert: info queueCount equals: VkContext queuesPerFamily.
	priorities := info pQueuePriorities getHandle.
	1 to: VkContext queuesPerFamily do: [ :index |
		self
			assert: (priorities
					 floatAt: index - 1 * VkContext queuePriorityByteCount + 1)
			equals: VkContext queuePriority ] ] ensure: [
		ctx freeDeviceQueueCreateInfo: info ]
]

{ #category : 'tests' }
VkCoreTest >> testDeviceRequiredForCooperativeMatrixComesUpWithTheFeatureEnabled [
	"Consistency rather than this machine's device list: where some device offers the
	 extension, the context that demanded it must create its device with the extension and
	 the feature struct both in place."
	| offeredSomewhere required |
	offeredSomewhere := (Vk enumeratePhysicalDevices: ctx instance) anySatisfy: [
		                    :handle |
		                    (VkPhysicalDevice on: handle)
			                    supportsCooperativeMatrix ].
	offeredSomewhere ifFalse: [ ^ self deny: ctx cooperativeMatrixAvailable ].
	required := VkContext cooperativeMatrixContext.
	[
	self assert: (required enabledDeviceExtensionNames includes:
			 VkPhysicalDevice cooperativeMatrixExtensionName).
	self assert: (required featureChainStructureNames includes:
			 #physicalDeviceCooperativeMatrixFeaturesKHR).
	self deny: required device handle isNull ] ensure: [ required destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testErrorDescribesItselfWhetherItCarriesAResultOrAText [
	"Both ways of raising a VkError exist in this package, and a description that raises a
	 second error hides whichever failure came first."
	| fromText fromResult |
	fromText := [ VkError signal: 'plain explanation' ]
		            on: VkError
		            do: [ :signal | signal messageText ].
	fromResult := [ (VkResult withCode: VkResult vkErrorDeviceLost) signal ]
		              on: VkError
		              do: [ :signal | signal messageText ].
	self assert: fromText equals: 'plain explanation'.
	self assert: (fromResult includesSubstring: 'VK_ERROR_DEVICE_LOST')
]

{ #category : 'tests-cooperative-matrix' }
VkCoreTest >> testEveryCooperativeMatrixConfigurationNamesShapesAndTypesTheSpecificationDefines [
	"A misread offset answers a plausible-looking number, so each field is checked against
	 what the specification allows. A device that reports the extension must offer at least
	 one combination, since a kernel has to match one of them exactly."

	| devices |
	devices := (Vk enumeratePhysicalDevices: ctx instance) collect: [ :each |
		           VkPhysicalDevice on: each ].
	(devices select: [ :each | each supportsCooperativeMatrix ]) do: [ :device |
		| configurations |
		configurations := device cooperativeMatrixConfigurationsOn: ctx instance.
		self deny: configurations isEmpty.
		configurations do: [ :each |
			self assert: each mSize > 0.
			self assert: each nSize > 0.
			self assert: each kSize > 0.
			self assert: (VkScope isDefined: each scope).
			self assert: (VkComponentType isDefined: each aType).
			self assert: (VkComponentType isDefined: each bType).
			self assert: (VkComponentType isDefined: each cType).
			self assert: (VkComponentType isDefined: each resultType) ] ]
]

{ #category : 'tests' }
VkCoreTest >> testEveryDeviceAnswersWhetherItSupportsTheVulkanMemoryModel [
	"The answer comes from vkGetPhysicalDeviceFeatures2, a core command, so it needs no
	 instance handle and must come back as a boolean for every device on the machine,
	 including one that offers no cooperative matrix."

	(Vk enumeratePhysicalDevices: ctx instance) do: [ :handle |
		self assert:
			({ true. false } includes:
				 (VkPhysicalDevice on: handle) supportsVulkanMemoryModel) ]
]

{ #category : 'tests-extension-commands' }
VkCoreTest >> testExtensionCommandIsUnavailableWhenTheLoaderHasNoSuchSymbol [
	"An unresolved command must say so rather than call address zero, which would take the
	 whole image down instead of raising."

	| command |
	command := VkExtensionCommand on: ctx instance named: 'vkThereIsNoSuchCommandKHR'.
	self deny: command isAvailable.
	self
		should: [
			command
				callWithArguments: #( )
				parameterTypes: #( )
				returnType: #int32 ]
		raise: VkError
]

{ #category : 'tests-extension-commands' }
VkCoreTest >> testExtensionCommandReachesASymbolLibvulkanDoesNotExport [
	"libvulkan.so.1 exports no cooperative matrix entry point — 269 vk symbols, none of them
	 this one — so the only route to it is vkGetInstanceProcAddr. The command resolves here
	 because lavapipe is installed; what the test asks is whether the loader hands back an
	 address at all."

	| command |
	command := VkExtensionCommand
		           on: ctx instance
		           named: VkPhysicalDevice cooperativeMatrixPropertiesCommandName.
	self assert: command isAvailable.
	self deny: command address isNull
]

{ #category : 'tests - constants' }
VkCoreTest >> testFlagNamesJoinEveryNamedBitAndSurfaceAnUnnamedOne [
	"A flags word decodes to the names of the bits it carries, and a bit no constant names
	 is surfaced as raw hex rather than dropped, so a view can never hide a property the
	 driver reported. Stated over the subclasses, and over the named bits each one declares,
	 so a bit or a whole class added later is covered without editing this test."

	| classes |
	classes := VkFlagConstants subclasses.
	self deny: classes isEmpty.
	classes do: [ :flagClass |
		| allNamed |
		self deny: flagClass namedBits isEmpty.
		self assert: (flagClass nameForFlags: 0) equals: ''.
		flagClass namedBits do: [ :each |
			self assert: (flagClass nameForFlags: each key) equals: each value ].
		allNamed := flagClass namedBits
			            inject: 0
			            into: [ :bits :each | bits bitOr: each key ].
		flagClass namedBits do: [ :each |
			self assert: ((flagClass nameForFlags: allNamed) includesSubstring: each value) ].
		self
			assert: (flagClass nameForFlags: (allNamed bitOr: 16r8000))
			equals: (flagClass nameForFlags: allNamed) , '|8000h' ]
]

{ #category : 'tests' }
VkCoreTest >> testHalfBufferHoldsTwiceAsManyValuesAsAFloatBuffer [
	| halves floats |
	halves := VkBuffer storageBufferOfHalves: 8 on: ctx device.
	floats := VkBuffer storageBuffer: 8 on: ctx device.
	[
	self assert: halves size * 2 equals: floats size.
	self assert: halves getF16s size equals: 8 ] ensure: [
		halves destroy.
		floats destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testHalfBufferRoundtripSnapsEachValueToItsNearestHalf [
	"A half buffer is lossy by construction, so the fact to assert is not that the values
	 come back unchanged but that they come back as the nearest half of what went in."

	| buf values |
	values := {
		          0.0.
		          1.0.
		          -2.5.
		          (1 / 3).
		          Float infinity.
		          (1.0 timesTwoPower: -24) }.
	buf := VkBuffer storageBufferOfHalves: values size on: ctx device.
	[
	buf putF16s: values.
	self
		assert: buf getF16s
		equals:
			(values collect: [ :each |
				 PVFloat16 floatFromWord: (PVFloat16 wordForFloat: each) ]) ]
		ensure: [ buf destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testHalfPrecisionReportAgreesWithTheGate [
	"The Half precision tab is only worth having if it answers the gate rather than a copy of
	 it, so the last row must equal what the context decides."

	| report |
	report := ctx physicalDevice halfPrecisionReport.
	self
		assert: report size
		equals: VkContext halfPrecisionExtensionNames size + 1.
	self assert: report last value equals: ctx halfPrecisionAvailable
]

{ #category : 'tests' }
VkCoreTest >> testHostVisibleAndCoherentAsksForBothProperties [
	"The constant must assert both bits its name promises, not just host-visible."
	self
		assert: (VkMemoryProperty hostVisibleAndCoherent bitAnd: VkMemoryProperty hostVisibleBit)
		equals: VkMemoryProperty hostVisibleBit.
	self
		assert: (VkMemoryProperty hostVisibleAndCoherent bitAnd: VkMemoryProperty hostCoherentBit)
		equals: VkMemoryProperty hostCoherentBit
]

{ #category : 'tests' }
VkCoreTest >> testMemoryTypeRowsNameEveryTypeTheDriverReports [
	"The Memory types view must cover the whole table and agree with the allocator: one
	 row per type the driver reports, each row's flags and heap read from the device, and
	 the Chosen column marking exactly the type findMemoryType:properties: picks for
	 hostVisibleAndCoherent. Asking for the rows must not change the device."
	| device rows chosen |
	device := ctx physicalDevice.
	rows := device memoryTypeRows.
	self assert: rows size equals: device memoryTypeCount.
	rows doWithIndex: [ :row :i |
		self assert: row first equals: i - 1.
		self
			assert: row second
			equals: (VkMemoryProperty nameForFlags: (device memoryPropertyFlagsOfType: i - 1)).
		self assert: row third equals: (device memoryHeapIndexOfType: i - 1) ].
	chosen := rows select: [ :row | row fourth ].
	self assert: chosen size equals: 1.
	self
		assert: chosen first first
		equals: (device
				 findMemoryType: (1 bitShift: device memoryTypeCount) - 1
				 properties: VkMemoryProperty hostVisibleAndCoherent).
	self assert: device memoryTypeRows equals: rows
]

{ #category : 'tests' }
VkCoreTest >> testOffscreenGraphicsContextQueueCanDraw [
	"The context handed back must be able to draw with no window and no surface
	 extensions: its one queue family must be a graphics-capable one."
	| context |
	context := VkContext offscreenGraphicsContext.
	[ self assert: context physicalDevice supportsGraphics.
	  self
	  	assert: context computeQueueFamily
	  	equals: context physicalDevice findGraphicsQueueFamily ] ensure: [ context destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testOffscreenRequirementAgreesWithTheQueueFamiliesOfEveryDevice [
	"Consistency on whatever devices the loader offers, not this machine's list: the
	 predicate the offscreen context selects on must answer exactly what the two family
	 finders say, for every device, or selection could accept a device whose single
	 queue cannot take a draw."
	(Vk enumeratePhysicalDevices: ctx instance) do: [ :handle |
		| device graphics compute |
		device := VkPhysicalDevice on: handle.
		graphics := device findGraphicsQueueFamily.
		compute := device findComputeQueueFamily.
		self
			assert: device supportsGraphics
			equals: graphics notNil.
		self
			assert: device supportsGraphicsAndComputeOnOneQueue
			equals: (graphics notNil and: [ graphics = compute ]) ]
]

{ #category : 'tests' }
VkCoreTest >> testPhysicalDeviceNamesEveryExtensionItSupports [
	"Every name the driver reports must be a plain String the gate can match on, and the gate
	 must agree with the list it was built from."

	| names |
	names := ctx physicalDevice extensionNames.
	self deny: names isEmpty.
	self assert: names asSet size equals: names size.
	names do: [ :each |
		self assert: (each beginsWith: VkPhysicalDevice extensionNamePrefix).
		self assert: (ctx physicalDevice supportsExtension: each) ]
]

{ #category : 'tests' }
VkCoreTest >> testPhysicalDeviceRejectsAnExtensionItDoesNotHave [
	"The degenerate names: one no driver can report, and the empty one."

	self deny: (ctx physicalDevice supportsExtension: 'VK_KHR_no_such_extension').
	self deny: (ctx physicalDevice supportsExtension: '')
]

{ #category : 'tests' }
VkCoreTest >> testPhysicalDeviceSelection [
	self assert: (ctx physicalDevice findComputeQueueFamily >= 0)
]

{ #category : 'tests' }
VkCoreTest >> testQueueFamilyRowsNameEveryFamilyAndAgreeWithTheFinders [
	"The Queue families view must cover every family and agree with the finders a context
	 selects on, including on layouts this machine does not have."
	| layout rows |
	layout := PVQueueFamilyStub withQueueFlags: {
			          VkQueueFlag graphicsBit.
			          VkQueueFlag computeBit bitOr: VkQueueFlag transferBit }.
	rows := layout queueFamilyRows.
	self assert: rows size equals: 2.
	self assert: (rows collect: [ :row | row first ]) asArray equals: #( 0 1 ).
	self assert: rows first second equals: 'Graphics'.
	self assert: rows second second equals: 'Compute|Transfer'.
	self assert: (rows detect: [ :row | row third ]) first equals: layout findGraphicsQueueFamily.
	self assert: (rows detect: [ :row | row fourth ]) first equals: layout findComputeQueueFamily.
	self assert: (rows select: [ :row | row third ]) size equals: 1.
	self assert: (rows select: [ :row | row fourth ]) size equals: 1.
	self assert: (PVQueueFamilyStub withQueueFlags: #( )) queueFamilyRows isEmpty
]

{ #category : 'tests' }
VkCoreTest >> testQueueFamilyRulesHoldForEveryFamilyLayout [
	"The layouts this machine cannot show, stated as the rule rather than as one sample.
	 A single family carrying both bits qualifies; graphics and compute on separate
	 families does not, because the offscreen context creates one queue and submits both
	 kinds of work on it. The flags words are built from the named bits, so the table
	 states the rule in the same terms the predicates read."
	| graphics compute both split none |
	none := PVQueueFamilyStub withQueueFlags: #( ).
	graphics := PVQueueFamilyStub withQueueFlags: { VkQueueFlag graphicsBit }.
	compute := PVQueueFamilyStub withQueueFlags: { VkQueueFlag computeBit }.
	both := PVQueueFamilyStub withQueueFlags:
		        { VkQueueFlag graphicsBit bitOr: VkQueueFlag computeBit }.
	split := PVQueueFamilyStub withQueueFlags:
		         { VkQueueFlag graphicsBit. VkQueueFlag computeBit }.
	self assert: both supportsGraphics.
	self assert: both supportsGraphicsAndComputeOnOneQueue.
	self assert: graphics supportsGraphics.
	self deny: graphics supportsGraphicsAndComputeOnOneQueue.
	self deny: compute supportsGraphics.
	self deny: compute supportsGraphicsAndComputeOnOneQueue.
	self assert: split supportsGraphics.
	self deny: split supportsGraphicsAndComputeOnOneQueue.
	self deny: none supportsGraphics.
	self deny: none supportsGraphicsAndComputeOnOneQueue.
	self assert: none findGraphicsQueueFamily isNil.
	self assert: none findComputeQueueFamily isNil
]

{ #category : 'tests' }
VkCoreTest >> testStorageBufferByElementTypeRoundtripsBothWidths [
	"One entry point for both element widths, so a caller that works in either precision
	 holds one branch instead of three. The sizes differ by two, and each width answers the
	 values its format can hold."

	| halves floats values |
	values := #( 0.0 1.0 -2.5 0.5 ).
	halves := VkBuffer storageBuffer: values size of: #f16 on: ctx device.
	floats := VkBuffer storageBuffer: values size of: #f32 on: ctx device.
	[
	halves put: values as: #f16.
	floats put: values as: #f32.
	self assert: halves size * 2 equals: floats size.
	self assert: (halves elementsAs: #f16) equals: values.
	self assert: (floats elementsAs: #f32) equals: values ] ensure: [
		halves destroy.
		floats destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testStorageBufferMemoryTypeIsCoherent [
	"VkBuffer allocate picks its memory type with hostVisibleAndCoherent; the type it picks
	 must actually carry the coherent bit, or map/unmap can read stale bytes on hardware
	 where host-visible memory need not also be coherent.
	 This cannot go red on this machine: both the old constant 3 and the correct 6 select
	 memory type 1, which is coherent here, so the test guards other hardware rather than
	 proving the fix. What proves the fix is
	 testHostVisibleAndCoherentAsksForBothProperties."
	| buffer memReqs typeFilter typeIndex |
	buffer := VkBuffer storageBuffer: 4 on: ctx device.
	[ memReqs := ExternalAddress allocate: 24.
	  [ Vk
	  	getBufferMemoryRequirements: ctx device handle
	  	buffer: buffer handle
	  	memoryRequirements: memReqs.
	    typeFilter := memReqs unsignedLongAt: 17.
	    typeIndex := ctx device physicalDevice
	  	findMemoryType: typeFilter
	  	properties: VkMemoryProperty hostVisibleAndCoherent.
	    self
	  	assert: ((ctx device physicalDevice memoryPropertyFlagsOfType: typeIndex)
	  			bitAnd: VkMemoryProperty hostCoherentBit)
	  	equals: VkMemoryProperty hostCoherentBit
	  ] ensure: [ memReqs free ]
	] ensure: [ buffer destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testStorageBufferRefusesAnUnknownElementType [
	"The degenerate element type. Falling back to four bytes would allocate a buffer of the
	 wrong size and read it back at the wrong stride."

	| buf |
	self
		should: [ VkBuffer storageBuffer: 4 of: #f64 on: ctx device ]
		raise: PVTypeError.
	buf := VkBuffer storageBuffer: 4 of: #f32 on: ctx device.
	[
	self should: [ buf put: #( 1.0 ) as: #f64 ] raise: PVTypeError.
	self should: [ buf elementsAs: #f64 ] raise: PVTypeError ] ensure: [
		buf destroy ]
]

{ #category : 'tests' }
VkCoreTest >> testSubgroupArithmeticAvailabilityAgreesWithTheDevice [
	"A context answers what its own device reports, so a kernel asking the context for the
	 reduction cannot be told something the driver did not say. This machine supports the
	 arithmetic, so both answers are true here; the fact under test is that they are equal."

	self
		assert: ctx subgroupArithmeticAvailable
		equals: ctx physicalDevice supportsSubgroupArithmetic
]

{ #category : 'tests' }
VkCoreTest >> testSubgroupPropertiesOfThisDeviceAgreeWithTheDriver [
	"Subgroup properties arrive through vkGetPhysicalDeviceProperties2 and a pNext chain, so a
	 broken chain leaves the block untouched and every field reads zero. The size is pinned
	 against what this machine reports, 32, and the arithmetic verdict against the fact that
	 this driver offers it. The power of two assertion is a rule of the specification and holds
	 on every device, so a zero from an unwritten block cannot pass it."

	| device |
	device := ctx physicalDevice.
	self assert: device subgroupSize equals: 32.
	self assert: device subgroupSize isPowerOfTwo.
	self assert: device supportsSubgroupArithmetic
]

{ #category : 'tests' }
VkCoreTest >> testUnsatisfiedRequirementsMessageNamesEveryRequirementAsked [
	"What a failed selection would say. The builder reads only the requirement list, so it
	 can be asked of a context whose selection succeeded — which is the only way to reach
	 it on a machine that does satisfy the requirement. An unaskable selector raises
	 elsewhere, in deviceSatisfiesRequirements:, and is pinned by its own test."
	| context message |
	context := VkContext computeContextRequiring:
		           #( #supportsGraphicsAndComputeOnOneQueue #supportsGraphics ).
	message := [ context unsatisfiedRequirementsMessage ] ensure: [ context destroy ].
	self assert: (message includesSubstring: 'compute queue').
	self assert: (message includesSubstring: 'supportsGraphicsAndComputeOnOneQueue').
	self assert: (message includesSubstring: 'supportsGraphics')
]

{ #category : 'support' }
VkCoreTest >> valueOfRowNamed: aString in: someRows [
	^ (someRows detect: [ :each | (each at: #name) = aString ]) at: #value
]
