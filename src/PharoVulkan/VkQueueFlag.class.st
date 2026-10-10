"
Named constants for VkQueueFlagBits, read off a queue family's flags word.
Key methods: graphicsBit, computeBit, transferBit, sparseBindingBit (the single bits),
nameForFlags: (decodes a flags word back to names for the inspector).
"
Class {
	#name : 'VkQueueFlag',
	#superclass : 'Object',
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
VkQueueFlag class >> nameForFlags: flags [
	"Joins the names of the bits this project names; a bit no constant here carries is
	 shown as its raw hex rather than silently dropped."
	| known remainder names |
	known := {
		self graphicsBit -> 'Graphics'.
		self computeBit -> 'Compute'.
		self transferBit -> 'Transfer'.
		self sparseBindingBit -> 'SparseBinding' }.
	names := OrderedCollection new.
	remainder := flags.
	known do: [ :assoc |
		(flags bitAnd: assoc key) = assoc key ifTrue: [
			names add: assoc value.
			remainder := remainder bitAnd: assoc key bitInvert ] ].
	remainder ~= 0 ifTrue: [ names add: (remainder printPaddedWith: $0 to: 1 base: 16) , 'h' ].
	^ String streamContents: [ :s |
		names do: [ :n | s nextPutAll: n ] separatedBy: [ s nextPutAll: '|' ] ]
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
