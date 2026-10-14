"
The VkImageSubresourceLayers a copy region carries by value: which aspect of the image is copied, from which mip level, and which run of array layers. VkImageAspect names the aspect bits. This project copies the colour aspect of the first mip level and one layer, so only the aspect mask and the layer count are written. Nested by value inside VkBufferImageCopy.
"
Class {
	#name : 'VkImageSubresourceLayers',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ASPECTMASK',
		'OFFSET_BASEARRAYLAYER',
		'OFFSET_LAYERCOUNT',
		'OFFSET_MIPLEVEL'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkImageSubresourceLayers class >> fieldsDesc [

	^ #( uint32 aspectMask; uint32 mipLevel; uint32 baseArrayLayer;
	     uint32 layerCount )
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> aspectMask [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ASPECTMASK
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> aspectMask: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ASPECTMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> baseArrayLayer [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BASEARRAYLAYER
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> baseArrayLayer: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BASEARRAYLAYER put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> layerCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LAYERCOUNT
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> layerCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LAYERCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> mipLevel [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MIPLEVEL
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceLayers >> mipLevel: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MIPLEVEL put: anObject
]
