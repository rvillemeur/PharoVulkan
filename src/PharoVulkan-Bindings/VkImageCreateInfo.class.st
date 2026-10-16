"
The request vkCreateImage reads: the dimensionality, the format, the extent carried by value, the mip and layer counts, the sample count, the tiling, the usage flags, the sharing mode, the queue families as a count and a pointer, and the layout the image starts in. Most of it is the zeros a fresh block holds — optimal tiling, the exclusive sharing mode and the undefined initial layout are all zero — so VkImage class >> createInfoForFormat:extent:usage:, its one writer, writes eight fields of fifteen. imageRows is what the Image tab reads.
"
Class {
	#name : 'VkImageCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ARRAYLAYERS',
		'OFFSET_EXTENT',
		'OFFSET_FLAGS',
		'OFFSET_FORMAT',
		'OFFSET_IMAGETYPE',
		'OFFSET_INITIALLAYOUT',
		'OFFSET_MIPLEVELS',
		'OFFSET_PNEXT',
		'OFFSET_PQUEUEFAMILYINDICES',
		'OFFSET_QUEUEFAMILYINDEXCOUNT',
		'OFFSET_SAMPLES',
		'OFFSET_SHARINGMODE',
		'OFFSET_STYPE',
		'OFFSET_TILING',
		'OFFSET_USAGE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkImageCreateInfo class >> fieldsDesc [
	"The extent is a VkExtent3D carried by value, so uFFI places its three words inside this
	 structure at offsets twenty-eight, thirty-two and thirty-six. The queue family indices
	 are an array, which uFFI in this image cannot declare, so they are pointed at; every
	 image here is exclusive to one family, so the pointer stays null and the count zero.
	 Four bytes of padding follow the count, and four more follow the initial layout, which
	 is what rounds the structure to eighty-eight bytes."

	^ #( int32 sType; void* pNext; uint32 flags; int32 imageType; int32 format;
	     VkExtent3D extent; uint32 mipLevels; uint32 arrayLayers; uint32 samples;
	     int32 tiling; uint32 usage; int32 sharingMode; uint32 queueFamilyIndexCount;
	     void* pQueueFamilyIndices; int32 initialLayout )
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> arrayLayers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ARRAYLAYERS
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> arrayLayers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ARRAYLAYERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> extent [
	"This method was automatically generated"
	^ VkExtent3D fromHandle: (handle referenceStructAt: OFFSET_EXTENT length: VkExtent3D byteSize)
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> extent: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_EXTENT put: anObject getHandle length: VkExtent3D byteSize
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> format [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_FORMAT
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> format: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_FORMAT put: anObject
]

{ #category : 'reporting' }
VkImageCreateInfo >> imageRows [
	"What this request asks the driver for, named through the constant classes rather than
	 restated here: the dimensionality, the format, the tiling, the usage flags and the
	 layout the image starts in. The extent is answered as a point and a depth separately,
	 because a reader cares that the image is flat. Read only, so the tab leaves the store
	 alone."

	^ Dictionary new
		  at: #imageTypeName put: ((VkImageType nameForValue: self imageType)
				   ifNil: [ self imageType printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #formatName put: ((VkFormat nameForValue: self format)
				   ifNil: [ self format printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #extent put: self extent width @ self extent height;
		  at: #depth put: self extent depth;
		  at: #mipLevels put: self mipLevels;
		  at: #arrayLayers put: self arrayLayers;
		  at: #tilingName put: ((VkImageTiling nameForValue: self tiling)
				   ifNil: [ self tiling printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #usageNames put: (VkImageUsage nameForFlags: self usage);
		  at: #initialLayoutName
		  put: ((VkImageLayout nameForValue: self initialLayout)
				   ifNil: [ self initialLayout printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #sharedBetweenQueueFamilies
		  put: self sharingMode ~= VkRenderConfig sharingModeExclusive;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> imageType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_IMAGETYPE
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> imageType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_IMAGETYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> initialLayout [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_INITIALLAYOUT
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> initialLayout: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_INITIALLAYOUT put: anObject
]

{ #category : 'initialization' }
VkImageCreateInfo >> initializeConstantFields [
	"The structure type is the only field fixed by the type. Nothing else may be written
	 here: the extent is nested by value, and its getter answers a view onto this store
	 through fromHandle:, which runs initialize again."

	self sType: VkStructureType imageCreateInfo
]

{ #category : 'inspector' }
VkImageCreateInfo >> inspectorImage: aBuilder [
	"What the driver is asked to create, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from imageRows, which reads this store and the
	 extent nested in it and follows no pointer, so opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Image'>
	| rows |
	rows := self imageRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Asks' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Dimensionality'. (rows at: #imageTypeName) }.
				  { 'Format'. (rows at: #formatName) }.
				  { 'Extent'. (rows at: #extent) }.
				  { 'Depth'. (rows at: #depth) }.
				  { 'Mip levels'. (rows at: #mipLevels) }.
				  { 'Array layers'. (rows at: #arrayLayers) }.
				  { 'Tiling'. (rows at: #tilingName) }.
				  { 'Usage'. (rows at: #usageNames) }.
				  { 'Layout on creation'. (rows at: #initialLayoutName) }.
				  { 'Shared between queue families'.
				  (rows at: #sharedBetweenQueueFamilies) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> mipLevels [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MIPLEVELS
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> mipLevels: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MIPLEVELS put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> pQueueFamilyIndices [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PQUEUEFAMILYINDICES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> pQueueFamilyIndices: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PQUEUEFAMILYINDICES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> queueFamilyIndexCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEXCOUNT
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> queueFamilyIndexCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEXCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> samples [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLES
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> samples: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLES put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> sharingMode [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_SHARINGMODE
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> sharingMode: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_SHARINGMODE put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> tiling [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_TILING
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> tiling: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_TILING put: anObject
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> usage [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_USAGE
]

{ #category : 'accessing - structure variables' }
VkImageCreateInfo >> usage: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_USAGE put: anObject
]
