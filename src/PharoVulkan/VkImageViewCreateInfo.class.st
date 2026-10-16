"
The request vkCreateImageView reads: which image the view looks at, the type and format it reads the image as, the per-channel swizzle and the subresource range it covers. The swizzle is a VkComponentMapping and the range a VkImageSubresourceRange, both carried by value. VkImage class >> viewRequestFor:format: is its one writer — the swapchain's views and the offscreen image's view are created by the same request from the same builder. viewRows is what the View tab reads.
"
Class {
	#name : 'VkImageViewCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_COMPONENTS',
		'OFFSET_FLAGS',
		'OFFSET_FORMAT',
		'OFFSET_IMAGE',
		'OFFSET_PNEXT',
		'OFFSET_STYPE',
		'OFFSET_SUBRESOURCERANGE',
		'OFFSET_VIEWTYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkImageViewCreateInfo class >> fieldsDesc [
	"The image is a handle, so it is declared as one and answers isNull. The swizzle and the
	 subresource range are carried by value, which is why their getters answer a view onto this
	 structure's own store."

	^ #( int32 sType; void* pNext; uint32 flags; VkImage_H* image;
	     int32 viewType; int32 format; VkComponentMapping components;
	     VkImageSubresourceRange subresourceRange )
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> components [
	"This method was automatically generated"
	^ VkComponentMapping fromHandle: (handle referenceStructAt: OFFSET_COMPONENTS length: VkComponentMapping byteSize)
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> components: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_COMPONENTS put: anObject getHandle length: VkComponentMapping byteSize
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> format [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_FORMAT
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> format: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_FORMAT put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> image [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_IMAGE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> image: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_IMAGE put: anObject getHandle.
]

{ #category : 'initialization' }
VkImageViewCreateInfo >> initializeConstantFields [
	"The structure type is the only field fixed by the type. The identity swizzle a view here
	 always asks for is zero, which the zeroed block already says, so writing it would be
	 writing what is already there; the writer names it in a comment instead."

	self sType: VkStructureType imageViewCreateInfo
]

{ #category : 'inspector' }
VkImageViewCreateInfo >> inspectorView: aBuilder [
	"What the driver is asked for when a view is created, rather than where the fields sit:
	 the Layout and Fields tabs answer that. Every row comes from viewRows, which reads the
	 store through the generated accessors, so the tab cannot claim something the request does
	 not hold and opening it leaves the request alone. The image is named as set or not set,
	 and no pointer is followed."

	<inspectorPresentationOrder: 30 title: 'View'>
	| rows |
	rows := self viewRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Image set'. (rows at: #imageSet) }.
				  { 'Format'. (rows at: #formatName) }.
				  { 'Aspect'. (rows at: #aspectNames) }.
				  { 'Mip levels'. (rows at: #mipLevels) }.
				  { 'Array layers'. (rows at: #arrayLayers) }.
				  { 'Swizzle'. (rows at: #swizzleNames) }.
				  { 'Unswizzled'. (rows at: #identitySwizzle) } };
		  yourself
]

{ #category : 'reporting' }
VkImageViewCreateInfo >> nameForSwizzle: aValue [
	"The name VkComponentSwizzle carries for one channel's source, as a string, so a row and
	 the test that reads it compare strings. A value no constant names is shown as the number
	 it is rather than hidden behind nil."

	^ (VkComponentSwizzle nameForValue: aValue)
		  ifNil: [ aValue printString ]
		  ifNotNil: [ :name | name asString ]
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> subresourceRange [
	"This method was automatically generated"
	^ VkImageSubresourceRange fromHandle: (handle referenceStructAt: OFFSET_SUBRESOURCERANGE length: VkImageSubresourceRange byteSize)
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> subresourceRange: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_SUBRESOURCERANGE put: anObject getHandle length: VkImageSubresourceRange byteSize
]

{ #category : 'reporting' }
VkImageViewCreateInfo >> viewRows [
	"What this request asks for, in Vulkan's terms: the format and the four swizzles under the
	 names their constant classes carry, the aspect bits decoded, and the mip and layer runs as
	 the intervals they cover. A format or a swizzle no constant names is shown as the number
	 it is rather than as nil. The image is reported as set or not, because its address says
	 nothing to a reader and differs on every run. Read only, so the View tab leaves the store
	 alone."

	| swizzles |
	swizzles := #( #r #g #b #a ) collect: [ :each |
		            self nameForSwizzle: (self components perform: each) ].
	^ Dictionary new
		  at: #imageSet put: self image isNull not;
		  at: #formatName
		  put: ((VkFormat nameForValue: self format)
				   ifNil: [ self format printString ]
				   ifNotNil: [ :name | name asString ]);
		  at: #aspectNames
		  put: (VkImageAspect nameForFlags: self subresourceRange aspectMask);
		  at: #mipLevels
		  put: (self subresourceRange baseMipLevel to:
				   self subresourceRange baseMipLevel + self subresourceRange levelCount - 1);
		  at: #arrayLayers
		  put: (self subresourceRange baseArrayLayer to:
				   self subresourceRange baseArrayLayer + self subresourceRange layerCount
				   - 1);
		  at: #swizzleNames put: (', ' join: swizzles);
		  at: #identitySwizzle
		  put: (swizzles allSatisfy: [ :each |
					   each = (self nameForSwizzle: VkComponentSwizzle identity) ]);
		  yourself
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> viewType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_VIEWTYPE
]

{ #category : 'accessing - structure variables' }
VkImageViewCreateInfo >> viewType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_VIEWTYPE put: anObject
]
