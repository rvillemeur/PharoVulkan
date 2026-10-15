"
The VkComponentMapping an image view request carries by value: one VkComponentSwizzle per colour channel. Every view this project creates reads the channels unswizzled, so all four fields stay at VkComponentSwizzle identity, which is zero and is what a zeroed request already holds. Nested by value inside VkImageViewCreateInfo, so its getter answers a view onto the request's own store.
"
Class {
	#name : 'VkComponentMapping',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_A',
		'OFFSET_B',
		'OFFSET_G',
		'OFFSET_R'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkComponentMapping class >> fieldsDesc [
	"One VkComponentSwizzle per colour channel, in the order the C structure declares them."

	^ #( int32 r; int32 g; int32 b; int32 a )
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> a [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_A
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> a: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_A put: anObject
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> b [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_B
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> b: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_B put: anObject
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> g [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_G
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> g: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_G put: anObject
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> r [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_R
]

{ #category : 'accessing - structure variables' }
VkComponentMapping >> r: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_R put: anObject
]
