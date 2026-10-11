"
Named constants for VkQueueFlagBits, read off a queue family's flags word.
Key methods: graphicsBit, computeBit, transferBit, sparseBindingBit (the single bits),
namedBits (the table VkFlagConstants decodes a driver's flags word with).
"
Class {
	#name : 'VkQueueFlag',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkQueueFlag class >> computeBit [
	"VK_QUEUE_COMPUTE_BIT"
	^ 2
]

{ #category : 'constants' }
VkQueueFlag class >> graphicsBit [
	"VK_QUEUE_GRAPHICS_BIT"
	^ 1
]

{ #category : 'decoding' }
VkQueueFlag class >> namedBits [
	^ {
		self graphicsBit -> 'Graphics'.
		self computeBit -> 'Compute'.
		self transferBit -> 'Transfer'.
		self sparseBindingBit -> 'SparseBinding' }
]

{ #category : 'constants' }
VkQueueFlag class >> sparseBindingBit [
	"VK_QUEUE_SPARSE_BINDING_BIT"
	^ 8
]

{ #category : 'constants' }
VkQueueFlag class >> transferBit [
	"VK_QUEUE_TRANSFER_BIT"
	^ 4
]
