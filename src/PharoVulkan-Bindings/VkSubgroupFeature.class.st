"
The VkSubgroupFeatureFlagBits values, one class-side constant per bit, used to read the supportedOperations field of VkPhysicalDeviceSubgroupProperties. Key methods: arithmeticBit, featureSelectors.
"
Class {
	#name : 'VkSubgroupFeature',
	#superclass : 'Object',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkSubgroupFeature class >> arithmeticBit [
	^ 4
]

{ #category : 'constants' }
VkSubgroupFeature class >> ballotBit [
	^ 8
]

{ #category : 'constants' }
VkSubgroupFeature class >> basicBit [
	^ 1
]

{ #category : 'constants' }
VkSubgroupFeature class >> clusteredBit [
	^ 64
]

{ #category : 'accessing' }
VkSubgroupFeature class >> featureSelectors [
	"Selected by protocol rather than by performing every unary class-side selector, which would
	 include this one and recurse."

	^ (self class selectors select: [ :each |
		   (self class >> each) protocolName = #constants ]) asSortedCollection asArray
]

{ #category : 'constants' }
VkSubgroupFeature class >> quadBit [
	^ 128
]

{ #category : 'constants' }
VkSubgroupFeature class >> shuffleBit [
	^ 16
]

{ #category : 'constants' }
VkSubgroupFeature class >> shuffleRelativeBit [
	^ 32
]

{ #category : 'constants' }
VkSubgroupFeature class >> voteBit [
	^ 2
]
