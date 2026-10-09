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
VkCoreTest >> testComputeContextCreation [
	self assert: ctx device notNil.
	self assert: ctx computeQueue notNil.
	self assert: ctx physicalDevice notNil
]

{ #category : 'as yet unclassified' }
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

{ #category : 'as yet unclassified' }
VkCoreTest >> testComputeContextEnablesOnlyExtensionsTheDeviceSupports [
	"Asking for an extension the driver does not have fails device creation, so the enabled
	 list may never run ahead of what the physical device reports."

	ctx enabledDeviceExtensionNames do: [ :each |
		self assert: (ctx physicalDevice supportsExtension: each) ]
]

{ #category : 'as yet unclassified' }
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
		(queueInfo pointerAt: 33) free.
		queueInfo free ]
]

{ #category : 'as yet unclassified' }
VkCoreTest >> testDeviceCreateInfoChainsTheHalfPrecisionFeatureStructs [
	"Synchronization2 is always asked for; the two half precision structs follow it only where
	 the device offers the extensions."

	| queueInfo info types half |
	queueInfo := ctx buildDeviceQueueCreateInfo: ctx computeQueueFamily.
	info := ctx buildDeviceCreateInfo: queueInfo.
	[
	types := ctx featureChainTypesIn: (info pointerAt: 9).
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
			(queueInfo pointerAt: 33) free.
			queueInfo free ]
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

{ #category : 'as yet unclassified' }
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

{ #category : 'as yet unclassified' }
VkCoreTest >> testPhysicalDeviceRejectsAnExtensionItDoesNotHave [
	"The degenerate names: one no driver can report, and the empty one."

	self deny: (ctx physicalDevice supportsExtension: 'VK_KHR_no_such_extension').
	self deny: (ctx physicalDevice supportsExtension: '')
]

{ #category : 'tests' }
VkCoreTest >> testPhysicalDeviceSelection [
	self assert: (ctx physicalDevice findComputeQueueFamily >= 0)
]
