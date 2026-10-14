"
The VkRect2D Vulkan uses wherever a region of an image is named: an offset and an extent carried by value, sixteen bytes in all. It is the render area of a render pass begin info and the scissor rectangle of a pipeline. Nested by value rather than pointed at.
"
Class {
	#name : 'VkRect2D',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_EXTENT',
		'OFFSET_OFFSET'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkRect2D class >> fieldsDesc [
	"Both nested structures are carried by value, so they are declared by name and uFFI places
	 their fields inside these sixteen bytes."

	^ #( VkOffset2D offset; VkExtent2D extent )
]

{ #category : 'accessing - structure variables' }
VkRect2D >> extent [
	"This method was automatically generated"
	^ VkExtent2D fromHandle: (handle referenceStructAt: OFFSET_EXTENT length: VkExtent2D byteSize)
]

{ #category : 'accessing - structure variables' }
VkRect2D >> extent: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_EXTENT put: anObject getHandle length: VkExtent2D byteSize
]

{ #category : 'accessing - structure variables' }
VkRect2D >> offset [
	"This method was automatically generated"
	^ VkOffset2D fromHandle: (handle referenceStructAt: OFFSET_OFFSET length: VkOffset2D byteSize)
]

{ #category : 'accessing - structure variables' }
VkRect2D >> offset: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_OFFSET put: anObject getHandle length: VkOffset2D byteSize
]
