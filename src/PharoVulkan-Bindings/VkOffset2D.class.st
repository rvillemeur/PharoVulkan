"
The VkOffset2D a rectangle carries by value: the x and y corner in pixels, signed because Vulkan allows a negative offset. Nested by value inside VkRect2D.
"
Class {
	#name : 'VkOffset2D',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_X',
		'OFFSET_Y'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkOffset2D class >> fieldsDesc [
	"Signed, because Vulkan allows a negative offset."

	^ #( int32 x; int32 y )
]

{ #category : 'accessing - structure variables' }
VkOffset2D >> x [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_X
]

{ #category : 'accessing - structure variables' }
VkOffset2D >> x: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_X put: anObject
]

{ #category : 'accessing - structure variables' }
VkOffset2D >> y [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_Y
]

{ #category : 'accessing - structure variables' }
VkOffset2D >> y: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_Y put: anObject
]
