"
The `VkCommandPoolCreateFlagBits` this project uses, with `namedBits` so the Pool tab can name a mask instead of printing it. `resetCommandBufferBit` is the one every pool here asks for: it lets a single command buffer be reset without resetting the whole pool, which is what re-recording one buffer per dispatch needs.
"
Class {
	#name : 'VkCommandPoolCreateFlag',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'decoding' }
VkCommandPoolCreateFlag class >> namedBits [
	"Value -> name for every pool creation bit this class names, lowest bit first. The decoder
	 reads this list, so naming one more bit never touches the decoding itself."

	^ { (self resetCommandBufferBit -> 'ResetCommandBuffer') }
]

{ #category : 'constants' }
VkCommandPoolCreateFlag class >> resetCommandBufferBit [
	"Lets one command buffer be reset on its own, with vkResetCommandBuffer or by beginning it
	 again. Without it a buffer can only be recycled by resetting the whole pool."

	^ 1
]
