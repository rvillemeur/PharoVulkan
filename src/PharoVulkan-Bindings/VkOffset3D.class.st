"
The VkOffset3D a copy region carries by value: the x, y and z corner of the region inside an image, in texels. The fields are signed, because Vulkan allows a negative offset for a blit. This project copies whole images, so all three stay at the zero a fresh block holds. Nested by value inside VkBufferImageCopy.
"
Class {
	#name : 'VkOffset3D',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_X',
		'OFFSET_Y',
		'OFFSET_Z'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkOffset3D class >> fieldsDesc [
	"Signed, because Vulkan allows a negative offset for a blit."

	^ #( int32 x; int32 y; int32 z )
]

{ #category : 'accessing - structure variables' }
VkOffset3D >> x [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_X
]

{ #category : 'accessing - structure variables' }
VkOffset3D >> x: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_X put: anObject
]

{ #category : 'accessing - structure variables' }
VkOffset3D >> y [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_Y
]

{ #category : 'accessing - structure variables' }
VkOffset3D >> y: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_Y put: anObject
]

{ #category : 'accessing - structure variables' }
VkOffset3D >> z [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_Z
]

{ #category : 'accessing - structure variables' }
VkOffset3D >> z: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_Z put: anObject
]
