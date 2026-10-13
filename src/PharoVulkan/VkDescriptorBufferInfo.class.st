"
VkDescriptorBufferInfo: which buffer a descriptor points at, and which part of it. Declared field by field, so uFFI computes all three offsets; the struct is twenty four bytes with no hole, because the handle is pointer wide and both VkDeviceSize members are uint64. range must name a real length: zero is not a legal descriptor, and VK_WHOLE_SIZE — every bit of the field set, answered by the class-side wholeSize — means the buffer from the given offset to its end. The range is written by whoever builds the info rather than by initialize, because uFFI's getter for a field pointing at this type answers it through fromHandle:, which runs the initialization over the pointee's store; see VkStructure >> initialize. VkDescriptorSet >> updateStorageBuffer:atBinding: builds the one this project sends. Key methods: buffer:, range:, class-side wholeSize.
"
Class {
	#name : 'VkDescriptorBufferInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BUFFER',
		'OFFSET_OFFSET',
		'OFFSET_RANGE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDescriptorBufferInfo class >> exampleWholeStorageBuffer [
	"One click: the buffer info a compute kernel writes for one of its storage buffers, which
	 is the whole buffer from its start. Built in object memory, so nothing has to be freed,
	 and rebuilt on every call. The buffer handle stays null: an example answers an object that
	 outlives the call, and a handle to a buffer this example does not own would be read after
	 that buffer has gone."
	<sampleInstance>
	^ self new
		  range: self wholeSize;
		  yourself
]

{ #category : 'field definition' }
VkDescriptorBufferInfo class >> fieldsDesc [
	"VkDescriptorBufferInfo: which buffer a descriptor points at, and which part of it. buffer
	 is a handle and therefore pointer wide; offset and range are VkDeviceSize, which is
	 uint64. All three sit on eight byte boundaries, so the struct is twenty four bytes with no
	 hole. range must be uint64 because VK_WHOLE_SIZE is every bit of it set."
	^ #(
		VkBuffer_H* buffer;
		uint64 offset;
		uint64 range
	)
]

{ #category : 'constants' }
VkDescriptorBufferInfo class >> wholeSize [
	"VK_WHOLE_SIZE, the value the C header gives: it tells the driver to use the buffer from
	 the given offset to its end. It is every bit of a VkDeviceSize set, and the test checks it
	 against the declared width of the range field, so a field declared narrower than uint64
	 fails rather than truncating this sentinel into a real length."
	^ 16rFFFFFFFFFFFFFFFF
]

{ #category : 'accessing - structure variables' }
VkDescriptorBufferInfo >> buffer [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_BUFFER) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorBufferInfo >> buffer: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_BUFFER put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorBufferInfo >> offset [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_OFFSET
]

{ #category : 'accessing - structure variables' }
VkDescriptorBufferInfo >> offset: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_OFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkDescriptorBufferInfo >> range [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_RANGE
]

{ #category : 'accessing - structure variables' }
VkDescriptorBufferInfo >> range: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_RANGE put: anObject
]
