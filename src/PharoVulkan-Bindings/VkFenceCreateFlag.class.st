"
The `VkFenceCreateFlagBits` this project uses, with `namedBits` so the Fence tab can name a mask instead of printing it. `signaledBit` is the only one Vulkan defines: a fence created with it is already signalled, which is what `VkFenceWrapper class >> createSignaledDevice:` asks for so the first wait of a frame loop returns at once.
"
Class {
	#name : 'VkFenceCreateFlag',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'decoding' }
VkFenceCreateFlag class >> namedBits [
	^ { (self signaledBit -> 'Signaled') }
]

{ #category : 'constants' }
VkFenceCreateFlag class >> signaledBit [
	"VK_FENCE_CREATE_SIGNALED_BIT: the fence is created already signalled, so the first wait on
	 it returns at once. A frame loop that waits before it submits needs this on the fence it
	 starts with."

	^ 1
]
