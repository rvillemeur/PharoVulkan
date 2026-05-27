Class {
	#name : 'VkImageLayout',
	#superclass : 'Object',
	#category : 'PharoVulkan',
	#package : 'PharoVulkan'
}

{ #category : 'constants' }
VkImageLayout class >> colorAttachmentOptimal [
	^ 2
]

{ #category : 'constants' }
VkImageLayout class >> presentSrcKHR [
	^ 1000001002
]

{ #category : 'constants' }
VkImageLayout class >> undefined [
	^ 0
]
