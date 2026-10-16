"
Named constants for VkCompositeAlphaFlagBitsKHR, how a surface's alpha channel is combined with whatever is behind the window. All four bits the specification declares are named, because the driver reports which modes a surface accepts; this project asks for opaqueBit. A VkFlagConstants subclass, so nameForFlags: decodes a mask by reading namedBits. VkRenderConfig class >> compositeAlphaOpaqueBit delegates here so the value has one home.
"
Class {
	#name : 'VkCompositeAlpha',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkCompositeAlpha class >> inheritBit [

	^ 8
]

{ #category : 'decoding' }
VkCompositeAlpha class >> namedBits [
	"Value -> name for every composite alpha mode the specification declares, lowest bit
	 first. This project asks for the opaque mode; the driver reports which modes the
	 surface accepts, so all four are named."

	^ {
		  (self opaqueBit -> 'Opaque').
		  (self preMultipliedBit -> 'PreMultiplied').
		  (self postMultipliedBit -> 'PostMultiplied').
		  (self inheritBit -> 'Inherit') }
]

{ #category : 'constants' }
VkCompositeAlpha class >> opaqueBit [

	^ 1
]

{ #category : 'constants' }
VkCompositeAlpha class >> postMultipliedBit [

	^ 4
]

{ #category : 'constants' }
VkCompositeAlpha class >> preMultipliedBit [

	^ 2
]
