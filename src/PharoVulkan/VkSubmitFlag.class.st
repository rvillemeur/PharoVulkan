"
Named constants for VkSubmitFlagBits, the flags word of a submit batch. Vulkan defines one bit, the protected submit, which this project never asks for: every batch here submits with no flags. Key methods: protectedBit, and namedBits, through which the inherited nameForFlags: decodes the word for a view.
"
Class {
	#name : 'VkSubmitFlag',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'decoding' }
VkSubmitFlag class >> namedBits [
	"The one bit Vulkan defines for a submit batch. A mask carrying any other bit shows it as
	 hex rather than hiding it."

	^ { self protectedBit -> 'Protected' }
]

{ #category : 'constants' }
VkSubmitFlag class >> protectedBit [
	"VK_SUBMIT_PROTECTED_BIT, bit 0: the batch is a protected submission, which needs a
	 protected-capable queue this project does not ask for."

	^ 1
]
