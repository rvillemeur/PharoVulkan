"
Named constants for VkDescriptorType enum values. Covers the subset used by this project. Key method: storageBuffer (VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7).
"
Class {
	#name : 'VkDescriptorType',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkDescriptorType class >> constantProtocol [
	^ #constants
]

{ #category : 'constants' }
VkDescriptorType class >> storageBuffer [
	^ 7
]
