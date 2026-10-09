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
VkCoreTest >> testPhysicalDeviceSelection [
	self assert: (ctx physicalDevice findComputeQueueFamily >= 0)
]
