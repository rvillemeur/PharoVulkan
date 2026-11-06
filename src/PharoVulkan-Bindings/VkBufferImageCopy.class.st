"
The VkBufferImageCopy that vkCmdCopyImageToBuffer takes: where in the buffer the copy starts, how the rows are packed there, and which part of the image is read. It nests three structures by value — the subresource, the offset and the extent — so declaring it declares them too and uFFI places the lot. No field is fixed by the type, because the structure carries no chain header. VkCommandBuffer class >> regionForExtent: is the only writer, and copyRows is what the Copy tab reads.
"
Class {
	#name : 'VkBufferImageCopy',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BUFFERIMAGEHEIGHT',
		'OFFSET_BUFFEROFFSET',
		'OFFSET_BUFFERROWLENGTH',
		'OFFSET_IMAGEEXTENT',
		'OFFSET_IMAGEOFFSET',
		'OFFSET_IMAGESUBRESOURCE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'constants' }
VkBufferImageCopy class >> exampleExtent [
	"A non-square extent, so the example cannot hide a width and a height written to each
	 other's field."

	^ 3 @ 2
]

{ #category : 'field definition' }
VkBufferImageCopy class >> fieldsDesc [
	"The three nested structures are carried by value, not by pointer, so they are declared by
	 name and uFFI places their fields inside these fifty-six bytes."

	^ #( uint64 bufferOffset; uint32 bufferRowLength;
	     uint32 bufferImageHeight;
	     VkImageSubresourceLayers imageSubresource; VkOffset3D imageOffset;
	     VkExtent3D imageExtent )
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> bufferImageHeight [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BUFFERIMAGEHEIGHT
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> bufferImageHeight: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BUFFERIMAGEHEIGHT put: anObject
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> bufferOffset [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_BUFFEROFFSET
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> bufferOffset: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_BUFFEROFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> bufferRowLength [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BUFFERROWLENGTH
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> bufferRowLength: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BUFFERROWLENGTH put: anObject
]

{ #category : 'accessing' }
VkBufferImageCopy >> copyRows [
	"What this region really says, read back through its own accessors: where in the buffer the
	 copy starts, whether the rows are tightly packed — which a zero row length means, said in
	 words rather than left as a zero for a reader to interpret — the aspect named by the class
	 that owns the bits, and which part of the image is read. The rows are built fresh on every
	 call over read values, so reading them cannot change the region."

	^ Dictionary newFrom: {
			  (#bufferOffset -> self bufferOffset).
			  (#tightlyPackedRows
			   -> (self bufferRowLength = 0 and: [ self bufferImageHeight = 0 ])).
			  (#aspectMask -> self imageSubresource aspectMask).
			  (#aspectNames
			   -> (VkImageAspect nameForFlags: self imageSubresource aspectMask)).
			  (#mipLevel -> self imageSubresource mipLevel).
			  (#baseArrayLayer -> self imageSubresource baseArrayLayer).
			  (#layerCount -> self imageSubresource layerCount).
			  (#imageOffset -> (self imageOffset x @ self imageOffset y)).
			  (#imageOffsetZ -> self imageOffset z).
			  (#extent -> (self imageExtent width @ self imageExtent height)).
			  (#depth -> self imageExtent depth) }
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> imageExtent [
	"This method was automatically generated"
	^ VkExtent3D fromHandle: (handle referenceStructAt: OFFSET_IMAGEEXTENT length: VkExtent3D byteSize)
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> imageExtent: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_IMAGEEXTENT put: anObject getHandle length: VkExtent3D byteSize
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> imageOffset [
	"This method was automatically generated"
	^ VkOffset3D fromHandle: (handle referenceStructAt: OFFSET_IMAGEOFFSET length: VkOffset3D byteSize)
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> imageOffset: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_IMAGEOFFSET put: anObject getHandle length: VkOffset3D byteSize
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> imageSubresource [
	"This method was automatically generated"
	^ VkImageSubresourceLayers fromHandle: (handle referenceStructAt: OFFSET_IMAGESUBRESOURCE length: VkImageSubresourceLayers byteSize)
]

{ #category : 'accessing - structure variables' }
VkBufferImageCopy >> imageSubresource: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_IMAGESUBRESOURCE put: anObject getHandle length: VkImageSubresourceLayers byteSize
]

{ #category : 'inspector' }
VkBufferImageCopy >> inspectorCopy: aBuilder [
	"What this region copies, in Vulkan's terms: the packing of the rows in the buffer, the
	 aspect of the image named by the class that owns the bits, the mip level and layers read,
	 and the box inside the image. The rows are read back through the accessors, so opening the
	 tab cannot change the region."

	<inspectorPresentationOrder: 30 title: 'Copy'>
	| rows |
	rows := self copyRows.
	^ PVFactRow
		  tableOf: {
				  (PVFactRow name: 'Buffer offset' value: (rows at: #bufferOffset)).
				  (PVFactRow
					   name: 'Tightly packed rows'
					   value: (rows at: #tightlyPackedRows)).
				  (PVFactRow name: 'Aspect' value: (rows at: #aspectNames)).
				  (PVFactRow name: 'Mip level' value: (rows at: #mipLevel)).
				  (PVFactRow
					   name: 'First array layer'
					   value: (rows at: #baseArrayLayer)).
				  (PVFactRow name: 'Layers' value: (rows at: #layerCount)).
				  (PVFactRow name: 'Image offset' value: (rows at: #imageOffset)).
				  (PVFactRow name: 'Extent' value: (rows at: #extent)).
				  (PVFactRow name: 'Depth' value: (rows at: #depth)) }
		  nameColumn: 'Property'
		  valueColumn: 'Value'
		  in: aBuilder
]
