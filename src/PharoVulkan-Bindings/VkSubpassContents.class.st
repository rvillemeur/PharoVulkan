"
Named constants for VkSubpassContents, which says whether a subpass is recorded inline in the command buffer it begins in or in secondary buffers it executes. This project records inline. Key methods: inline, secondaryCommandBuffers.
"
Class {
	#name : 'VkSubpassContents',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkSubpassContents class >> constantProtocol [
	"The protocol the value methods live in, which the inherited decoder reflects over."

	^ #constants
]

{ #category : 'constants' }
VkSubpassContents class >> inline [
	"VK_SUBPASS_CONTENTS_INLINE: the subpass is recorded in the buffer that begins the pass."

	^ 0
]

{ #category : 'constants' }
VkSubpassContents class >> secondaryCommandBuffers [
	"VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS: the subpass is recorded in secondary
	 buffers the pass executes. This project allocates primary buffers only."

	^ 1
]
