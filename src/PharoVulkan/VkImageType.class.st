"
Named constants for VkImageType, the dimensionality an image is created with. Key method: type2D (VK_IMAGE_TYPE_2D = 1), the only one this project creates, because every attachment it renders into is a flat colour target. A VkValueConstants subclass, so the inherited nameForValue: names a dimensionality for the Image tab.
"
Class {
	#name : 'VkImageType',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkImageType class >> constantProtocol [
	"Where this class files its constants, for the inherited reverse lookup."

	^ 'constants'
]

{ #category : 'constants' }
VkImageType class >> type2D [
	"VK_IMAGE_TYPE_2D"

	^ 1
]
