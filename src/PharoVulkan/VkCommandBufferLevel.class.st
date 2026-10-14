"
The `VkCommandBufferLevel` values, with `nameForValue:` so the Buffer tab can name a level instead of printing it. A primary buffer is submitted to a queue; a secondary buffer is recorded into a primary one. This project allocates primary buffers only, and `VkCommandPool class >> allocationLevel` names the choice.
"
Class {
	#name : 'VkCommandBufferLevel',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkCommandBufferLevel class >> constantProtocol [
	^ #constants
]

{ #category : 'constants' }
VkCommandBufferLevel class >> primary [
	^ 0
]

{ #category : 'constants' }
VkCommandBufferLevel class >> secondary [
	^ 1
]
