"
Named constants for VkBufferUsageFlagBits, the usage bitmask a buffer is created with, plus the names those bits carry when a flag word is decoded for a human. Key methods: transferDstBit, storageBufferBit, namedBits. VkBuffer class >> storageBufferUsage predates this class and answers the same value as storageBufferBit.
"
Class {
	#name : 'VkBufferUsage',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'decoding' }
VkBufferUsage class >> namedBits [
	^ {
		  (self transferDstBit -> 'TransferDst').
		  (self storageBufferBit -> 'StorageBuffer').
		  (self vertexBufferBit -> 'VertexBuffer') }
]

{ #category : 'constants' }
VkBufferUsage class >> storageBufferBit [
	"VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, bit 5."

	^ 32
]

{ #category : 'constants' }
VkBufferUsage class >> transferDstBit [
	"VK_BUFFER_USAGE_TRANSFER_DST_BIT, bit 1."

	^ 2
]

{ #category : 'constants' }
VkBufferUsage class >> vertexBufferBit [
	"VK_BUFFER_USAGE_VERTEX_BUFFER_BIT, bit 7."

	^ 128
]
