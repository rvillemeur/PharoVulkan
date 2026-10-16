"
Named constants for VkImageUsageFlagBits, the ways an image may be used, declared for the uses this project actually asks for: transferSrcBit (VK_IMAGE_USAGE_TRANSFER_SRC_BIT = 1) and colorAttachmentBit (VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 16).

A VkFlagConstants subclass, so nameForFlags: decodes a usage word by reading namedBits; a bit no constant here names is surfaced as raw hex rather than dropped.
"
Class {
	#name : 'VkImageUsage',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkImageUsage class >> colorAttachmentBit [
	^ 16
]

{ #category : 'decoding' }
VkImageUsage class >> namedBits [
	"Value -> name for every bit this class names, lowest bit first. The decoder reads
	 this list, so naming one more bit never touches the decoding itself."

	^ {
		  (self transferSrcBit -> 'TransferSrc').
		  (self colorAttachmentBit -> 'ColorAttachment') }
]

{ #category : 'constants' }
VkImageUsage class >> transferSrcBit [
	"VK_IMAGE_USAGE_TRANSFER_SRC_BIT"

	^ 1
]
