"
Named constants for VkMemoryPropertyFlagBits combinations used when allocating device memory. Key method: hostVisibleAndCoherent (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | HOST_COHERENT_BIT = 3).
"
Class {
	#name : 'VkMemoryProperty',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkMemoryProperty class >> hostVisibleAndCoherent [
	^ 3
]
