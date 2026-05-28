"
Named constants for VkAttachmentLoadOp and VkAttachmentStoreOp values used in render-pass attachment descriptions. Key methods: loadClear, loadDontCare, storeStore, storeDiscard.
"
Class {
	#name : 'VkAttachmentOp',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkAttachmentOp class >> loadClear [
	^ 1
]

{ #category : 'constants' }
VkAttachmentOp class >> loadDontCare [
	^ 2
]

{ #category : 'constants' }
VkAttachmentOp class >> storeDiscard [
	^ 1
]

{ #category : 'constants' }
VkAttachmentOp class >> storeStore [
	^ 0
]
