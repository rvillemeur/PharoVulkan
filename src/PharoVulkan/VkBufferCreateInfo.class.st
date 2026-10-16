"
The request passed to `vkCreateBuffer`: a chain header, flags, the byte size, the usage mask that says which kinds of descriptor and transfer the buffer may serve, the sharing mode and an optional queue family list. The layout is declared in `fieldsDesc`, so `VkBuffer >> allocate` fills it through generated accessors and `externalInstance` answers a zeroed block already stamped with the one structure type; `sharingModeExclusive` names the zero the sharing mode reads as. The `size` accessor overrides `Object >> size` for this class only, which is deliberate: the field is called `size` in Vulkan and the structure is never asked for a collection size.

`VkMemoryAllocateInfo` and `VkMemoryRequirements` carry the other half of making a buffer usable, and `VkBuffer` drives all three.
"
Class {
	#name : 'VkBufferCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_PQUEUEFAMILYINDICES',
		'OFFSET_QUEUEFAMILYINDEXCOUNT',
		'OFFSET_SHARINGMODE',
		'OFFSET_SIZE',
		'OFFSET_STYPE',
		'OFFSET_USAGE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkBufferCreateInfo class >> fieldsDesc [
	"size is a VkDeviceSize, so eight bytes wide and eight byte aligned: four bytes of padding
	 follow flags. pQueueFamilyIndices is a uint32 array the caller owns and is declared void*
	 rather than uint32*, because the field is a pointer whatever it points at."

	^ #( int32 sType; void* pNext; uint32 flags; uint64 size; uint32 usage;
		uint32 sharingMode; uint32 queueFamilyIndexCount;
		void* pQueueFamilyIndices )
]

{ #category : 'constants' }
VkBufferCreateInfo class >> sharingModeExclusive [
	"VK_SHARING_MODE_EXCLUSIVE. It is zero, so a freshly zeroed request already asks for a
	 buffer owned by one queue family at a time, which is what every buffer in this project
	 wants; the constant is named so the zero can be read."

	^ 0
]

{ #category : 'constants' }
VkBufferCreateInfo class >> sharingModeNameFor: aValue [
	"Only the exclusive mode is named, because it is the only one this project ever asks for.
	 Any other value is printed as the number it is rather than given a name this class cannot
	 vouch for."

	^ aValue = self sharingModeExclusive
		  ifTrue: [ 'exclusive' ]
		  ifFalse: [ aValue printString ]
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkBufferCreateInfo >> initializeConstantFields [
	"The structure type, and nothing else. A fresh store already reads as the degenerate
	 request: no flags, no bytes, no usage, exclusive sharing (which is zero) and no queue
	 family list."

	self sType: VkStructureType bufferCreateInfo
]

{ #category : 'inspector' }
VkBufferCreateInfo >> inspectorRequest: aBuilder [
	"What this request asks the driver for, in the driver's terms: the raw words are in the
	 Fields tab, and this tab names them."

	<inspectorPresentationOrder: 30 title: 'Request'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Attribute' evaluated: [ :each |
				   each at: #attribute ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each at: #value ]);
		  items: self requestRows;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> pQueueFamilyIndices [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PQUEUEFAMILYINDICES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> pQueueFamilyIndices: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PQUEUEFAMILYINDICES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> queueFamilyIndexCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEXCOUNT
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> queueFamilyIndexCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEXCOUNT put: anObject
]

{ #category : 'accessing' }
VkBufferCreateInfo >> requestRows [
	"The request read as what it asks the driver for: the byte count, the usage mask decoded by
	 the flag constants that declare those bits, the sharing mode named by the class, and
	 whether a queue family list is attached. Every row is read from the structure's own
	 accessors, so none of them can drift from the declared layout, and reading changes
	 nothing."

	^ { (Dictionary newFrom: {
			   (#attribute -> 'Bytes').
			   (#value -> self size printString) }).
		  (Dictionary newFrom: {
			   (#attribute -> 'Usage').
			   (#value -> (VkBufferUsage nameForFlags: self usage)) }).
		  (Dictionary newFrom: {
			   (#attribute -> 'Sharing').
			   (#value -> (self class sharingModeNameFor: self sharingMode)) }).
		  (Dictionary newFrom: {
			   (#attribute -> 'Queue families').
			   (#value -> self queueFamilyIndexCount printString) }) } collect: [
		  :each | each beReadOnlyObject ]
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> sharingMode [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHARINGMODE
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> sharingMode: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHARINGMODE put: anObject
]

{ #category : 'accessing' }
VkBufferCreateInfo >> size [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_SIZE
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> size: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_SIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> usage [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_USAGE
]

{ #category : 'accessing - structure variables' }
VkBufferCreateInfo >> usage: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_USAGE put: anObject
]
