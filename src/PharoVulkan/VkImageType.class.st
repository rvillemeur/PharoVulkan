"
Named constants for VkImageType, the dimensionality an image is created with. Key method: type2D (VK_IMAGE_TYPE_2D = 1), the only one this project creates, because every attachment it renders into is a flat colour target.
"
Class {
	#name : 'VkImageType',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkImageType class >> type2D [
	"VK_IMAGE_TYPE_2D"

	^ 1
]
