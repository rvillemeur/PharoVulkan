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
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
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

{ #category : 'inspector' }
VkRect2D >> inspectorRect: aBuilder [
	"The offset and the extent of this rectangle, and whether it starts at the origin of what
	 it covers. The same rectangle is a scissor in one command and a render area in another, so
	 the tab names neither. The rows are read back through the accessors, so opening the tab
	 cannot change the rectangle."

	<inspectorPresentationOrder: 30 title: 'Rectangle'>
	| rows |
	rows := self rectRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Offset'. (rows at: #offset) }.
				  { 'At the origin'. (rows at: #atTheOrigin) }.
				  { 'Extent'. (rows at: #extent) } };
		  yourself
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

{ #category : 'reporting' }
VkRect2D >> rectRows [
	"The offset and the extent of this rectangle, and whether it starts at the origin of what
	 it covers. A rectangle serves both the scissor and the render pass's render area, so the
	 rows say nothing about which of the two this one is. Fresh rows over copied values."

	^ Dictionary new
		  at: #offset put: self offset x @ self offset y;
		  at: #extent put: self extent width @ self extent height;
		  at: #atTheOrigin
		  put: (self offset x = 0 and: [ self offset y = 0 ]);
		  yourself
]
