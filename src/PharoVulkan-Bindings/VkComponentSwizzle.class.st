"
Named constants for VkComponentSwizzle, the per-channel source an image view reads each colour channel from. Key methods: identity, which is what every view in this project asks for and is also what a zeroed request already says, and the inherited nameForValue:, through which a view names the swizzle a request holds. VkComponentMapping carries four of these by value.
"
Class {
	#name : 'VkComponentSwizzle',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkComponentSwizzle class >> constantProtocol [
	"Where this class files its constants, for the inherited reverse lookup."

	^ 'constants'
]

{ #category : 'constants' }
VkComponentSwizzle class >> identity [
	"VK_COMPONENT_SWIZZLE_IDENTITY: the channel reads the channel of the same name. Every
	 view this project creates asks for it on all four channels."

	^ 0
]

{ #category : 'constants' }
VkComponentSwizzle class >> one [
	"VK_COMPONENT_SWIZZLE_ONE."

	^ 2
]

{ #category : 'constants' }
VkComponentSwizzle class >> zero [
	"VK_COMPONENT_SWIZZLE_ZERO, named so a swizzle a driver reported as zeroed on purpose is
	 told apart from the identity in a view."

	^ 1
]
