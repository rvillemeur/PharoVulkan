Class {
	#name : 'VkAttachmentOp',
	#superclass : 'Object',
	#category : 'PharoVulkan',
	#package : 'PharoVulkan'
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
