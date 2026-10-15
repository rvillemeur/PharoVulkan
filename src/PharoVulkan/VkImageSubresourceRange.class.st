"
The VkImageSubresourceRange an image view request carries by value: which aspect of the image the view reads, and the runs of mip levels and array layers it covers. VkImageAspect names the aspect bits. This project views the colour aspect of one mip level and one array layer. VkImageSubresourceLayers is the copy region's shape and names a single mip level rather than a run, which is why the two are separate structures. Nested by value inside VkImageViewCreateInfo.
"
Class {
	#name : 'VkImageSubresourceRange',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ASPECTMASK',
		'OFFSET_BASEARRAYLAYER',
		'OFFSET_BASEMIPLEVEL',
		'OFFSET_LAYERCOUNT',
		'OFFSET_LEVELCOUNT'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkImageSubresourceRange class >> fieldsDesc [
	"Which aspect of the image the view reads, and the runs of mip levels and array layers it
	 covers. VkImageSubresourceLayers is the copy region's shape and names a single mip level;
	 a view names a run of them, so the two are different structures."

	^ #( uint32 aspectMask; uint32 baseMipLevel; uint32 levelCount;
	     uint32 baseArrayLayer; uint32 layerCount )
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> aspectMask [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ASPECTMASK
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> aspectMask: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ASPECTMASK put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> baseArrayLayer [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BASEARRAYLAYER
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> baseArrayLayer: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BASEARRAYLAYER put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> baseMipLevel [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BASEMIPLEVEL
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> baseMipLevel: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BASEMIPLEVEL put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> layerCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LAYERCOUNT
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> layerCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LAYERCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> levelCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LEVELCOUNT
]

{ #category : 'accessing - structure variables' }
VkImageSubresourceRange >> levelCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LEVELCOUNT put: anObject
]
