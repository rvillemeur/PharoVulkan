"
The VkRenderPassBeginInfo that vkCmdBeginRenderPass takes: which render pass runs over which framebuffer, the area of the attachments it covers, and the clear values its load operations use. The render area is a VkRect2D carried by value. The clear values are a union of arrays, which uFFI in this image cannot declare, so they are a block written by a named stride and pointed at from here. VkCommandBuffer class >> renderPassBeginInfoFor:framebuffer:extent:clearValues: is the only writer, and passRows is what the Pass tab reads.
"
Class {
	#name : 'VkRenderPassBeginInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_CLEARVALUECOUNT',
		'OFFSET_FRAMEBUFFER',
		'OFFSET_PCLEARVALUES',
		'OFFSET_PNEXT',
		'OFFSET_RENDERAREA',
		'OFFSET_RENDERPASS',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'constants' }
VkRenderPassBeginInfo class >> clearComponentByteCount [
	"A clear colour component is a float. The clear values are a union of arrays rather than a
	 declared structure, so there is no field specification to read a width from and the stride is
	 named here, beside the pointer it applies to."

	^ 4
]

{ #category : 'constants' }
VkRenderPassBeginInfo class >> clearComponentCount [
	"Four components per clear colour, in the order Vulkan reads them. The count belongs to this
	 request because this request declares the pointer the colours are read through, and both the
	 writer above and the report below read them by the same named stride."

	^ 4
]

{ #category : 'field definition' }
VkRenderPassBeginInfo class >> fieldsDesc [
	"The render area is carried by value; the clear values are pointed at, because a clear value
	 is a union of arrays and uFFI in this image cannot declare an array field."

	^ #( int32 sType; void* pNext; VkRenderPass_H* renderPass;
	     VkFramebuffer_H* framebuffer; VkRect2D renderArea;
	     uint32 clearValueCount; void* pClearValues )
]

{ #category : 'accessing' }
VkRenderPassBeginInfo >> clearColorComponents [
	"The clear colour the pointer leads to, as the r, g, b, a floats the writer put there. A
	 clear value has no field specification to read an offset from, so the components are read
	 by the named stride; a begin info nobody has given values to answers none rather than
	 reading whatever lies at address zero."

	self pClearValues isNull ifTrue: [ ^ #(  ) ].
	^ (1 to: self class clearComponentCount) collect: [ :index |
		  self pClearValues getHandle floatAt:
			  index - 1 * self class clearComponentByteCount + 1 ]
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> clearValueCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_CLEARVALUECOUNT
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> clearValueCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_CLEARVALUECOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> framebuffer [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_FRAMEBUFFER) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> framebuffer: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_FRAMEBUFFER put: anObject getHandle.
]

{ #category : 'initialization' }
VkRenderPassBeginInfo >> initializeConstantFields [
	"Only the structure type is fixed by the type. Both handles, the render area and the clear
	 values belong to the recorder, and a pass over no area with no clear value listed is a
	 fresh block as it stands."

	self sType: VkStructureType renderPassBeginInfo
]

{ #category : 'inspector' }
VkRenderPassBeginInfo >> inspectorPass: aBuilder [
	"What this begin info opens: whether the pass and the framebuffer are set, the area of the
	 attachments it covers, the clear colour its load operation reads, and the kind of contents
	 the project records. An empty clear colour means the pointer leads nowhere any more, which
	 the row says in words rather than showing an empty array. The rows are read back through
	 the accessors, so opening the tab cannot change the structure."

	<inspectorPresentationOrder: 30 title: 'Pass'>
	| rows |
	rows := self passRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Render pass'. (rows at: #renderPassSet) }.
				  { 'Framebuffer'. (rows at: #framebufferSet) }.
				  { 'Render area offset'. (rows at: #renderAreaOffset) }.
				  { 'Render area'. (rows at: #renderArea) }.
				  { 'Clear values'. (rows at: #clearValueCount) }.
				  { 'Clear colour'.
				  ((rows at: #clearColor) ifEmpty: [ 'values out of reach' ]) }.
				  { 'Subpass contents'. (rows at: #subpassContentsName) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> pClearValues [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PCLEARVALUES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> pClearValues: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PCLEARVALUES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing' }
VkRenderPassBeginInfo >> passRows [
	"What this begin info really says, read back through its own accessors: the area the pass
	 covers, whether the pass and the framebuffer are set, and the clear colour behind the
	 pointer, read by the same named stride the writer used. The subpass contents are not a
	 field of this structure — they are an argument of the call — so that row asks the class
	 that names the project's choice. The rows are built fresh over read values, so reading them
	 cannot change the structure."

	^ Dictionary newFrom: {
			  (#renderPassSet -> self renderPass isNull not).
			  (#framebufferSet -> self framebuffer isNull not).
			  (#renderAreaOffset
			   -> (self renderArea offset x @ self renderArea offset y)).
			  (#renderArea
			   -> (self renderArea extent width @ self renderArea extent height)).
			  (#clearValueCount -> self clearValueCount).
			  (#clearColor -> self clearColorComponents).
			  (#subpassContentsName
			   -> (VkSubpassContents nameForValue: VkRenderConfig subpassContents)) }
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> renderArea [
	"This method was automatically generated"
	^ VkRect2D fromHandle: (handle referenceStructAt: OFFSET_RENDERAREA length: VkRect2D byteSize)
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> renderArea: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_RENDERAREA put: anObject getHandle length: VkRect2D byteSize
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> renderPass [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_RENDERPASS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> renderPass: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_RENDERPASS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkRenderPassBeginInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
