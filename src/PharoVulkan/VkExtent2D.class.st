"
The VkExtent2D a rectangle carries by value: the width and height in pixels. Nested by value inside VkRect2D.
"
Class {
	#name : 'VkExtent2D',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_HEIGHT',
		'OFFSET_WIDTH'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkExtent2D class >> fieldsDesc [

	^ #( uint32 width; uint32 height )
]

{ #category : 'accessing - structure variables' }
VkExtent2D >> height [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_HEIGHT
]

{ #category : 'accessing - structure variables' }
VkExtent2D >> height: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_HEIGHT put: anObject
]

{ #category : 'accessing - structure variables' }
VkExtent2D >> width [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_WIDTH
]

{ #category : 'accessing - structure variables' }
VkExtent2D >> width: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_WIDTH put: anObject
]
