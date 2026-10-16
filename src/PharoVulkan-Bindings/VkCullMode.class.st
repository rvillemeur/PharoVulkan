"
Which triangle faces the driver discards before rasterization, one constant per bit, plus none for the word of no bits. nameForFlags: names that word, because culling nothing is a mode in Vulkan rather than an absence; every other word decodes through the bits declared in namedBits.
"
Class {
	#name : 'VkCullMode',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkCullMode class >> backBit [
	"Triangles facing away from the viewer are discarded before rasterization."

	^ 2
]

{ #category : 'constants' }
VkCullMode class >> frontBit [
	"Triangles facing the viewer are discarded before rasterization."

	^ 1
]

{ #category : 'decoding' }
VkCullMode class >> nameForNoBits [
	"Culling nothing is a mode of its own in Vulkan rather than an absence of bits, so the word
	 of no bits is named here. The inherited decoder would answer nothing at all for it, which
	 reads as a missing value."

	^ 'none'
]

{ #category : 'decoding' }
VkCullMode class >> namedBits [

	^ {
		  (self frontBit -> #frontBit).
		  (self backBit -> #backBit) }
]

{ #category : 'constants' }
VkCullMode class >> none [
	"No face is discarded: both windings are rasterized. A word of no bits, which is why the
	 decoder here names it rather than leaving the inherited one to answer nothing."

	^ 0
]
