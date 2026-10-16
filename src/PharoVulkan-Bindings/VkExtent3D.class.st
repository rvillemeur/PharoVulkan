"
The VkExtent3D a copy region carries by value: the width, height and depth of the region in texels. A two dimensional image has a depth of one, which VkCommandBuffer class >> copyDepth names. Nested by value inside VkBufferImageCopy.
"
Class {
	#name : 'VkExtent3D',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DEPTH',
		'OFFSET_HEIGHT',
		'OFFSET_WIDTH'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkExtent3D class >> fieldsDesc [

	^ #( uint32 width; uint32 height; uint32 depth )
]

{ #category : 'accessing - structure variables' }
VkExtent3D >> depth [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPTH
]

{ #category : 'accessing - structure variables' }
VkExtent3D >> depth: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPTH put: anObject
]

{ #category : 'accessing - structure variables' }
VkExtent3D >> height [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_HEIGHT
]

{ #category : 'accessing - structure variables' }
VkExtent3D >> height: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_HEIGHT put: anObject
]

{ #category : 'accessing - structure variables' }
VkExtent3D >> width [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_WIDTH
]

{ #category : 'accessing - structure variables' }
VkExtent3D >> width: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_WIDTH put: anObject
]
