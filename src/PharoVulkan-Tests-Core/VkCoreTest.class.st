Class {
	#name : 'VkCoreTest',
	#superclass : 'TestCase',
	#instVars : [
		'ctx'
	],
	#category : 'PharoVulkan-Tests-Core',
	#package : 'PharoVulkan-Tests-Core'
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
	ctx := VkContext computeContext
]

{ #category : 'running' }
VkCoreTest >> tearDown [
	ctx destroy
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
VkCoreTest >> testPhysicalDeviceSelection [
	self assert: (ctx physicalDevice findComputeQueueFamily >= 0)
]
