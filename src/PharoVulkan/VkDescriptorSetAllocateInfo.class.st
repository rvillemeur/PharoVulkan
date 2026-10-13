"
VkDescriptorSetAllocateInfo, the allocate info vkAllocateDescriptorSets reads. Declared field by field, so uFFI computes every offset including the four byte hole it puts between descriptorSetCount and the eight byte aligned pSetLayouts; the struct is forty bytes. descriptorPool is a handle and therefore pointer wide, not a count. pSetLayouts points at an array of descriptorSetCount set layout handles rather than at one handle, which is why VkDescriptorPool builds that array separately and frees it after the driver has read it. initialize names the structure type and clears the chain pointer, and FFIStructure class >> fromHandle: sends it, so an instance from externalInstance is as ready as one from new; VkDescriptorPool >> allocateSet: writes only the pool, the count and the array. Key methods: descriptorPool:, descriptorSetCount:, pSetLayouts:, layoutRows.
"
Class {
	#name : 'VkDescriptorSetAllocateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DESCRIPTORPOOL',
		'OFFSET_DESCRIPTORSETCOUNT',
		'OFFSET_PNEXT',
		'OFFSET_PSETLAYOUTS',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDescriptorSetAllocateInfo class >> exampleForOneSetOfThreeBindings [
	"One click: the allocate info VkDescriptorPool writes for a three-buffer compute kernel,
	 with the structure type, the pool slot and the set count side by side in the Request tab.
	 The pool handle and the layout array stay null: an example answers an object that outlives
	 the call, and a pointer to a store this example does not own would be read after that
	 store has gone. The live pointers are covered by VkBindingsTest and by
	 VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers."
	<sampleInstance>
	^ self new
		  descriptorSetCount: VkDescriptorPool setAllocationCount;
		  yourself
]

{ #category : 'field definition' }
VkDescriptorSetAllocateInfo class >> fieldsDesc [
	"VkDescriptorSetAllocateInfo, read by vkAllocateDescriptorSets. descriptorPool is a handle,
	 so it is pointer wide; pNext, descriptorPool and pSetLayouts are all eight byte aligned,
	 which makes uFFI put a four byte hole between descriptorSetCount and pSetLayouts by
	 itself. The struct is forty bytes. pSetLayouts points at an array of descriptorSetCount
	 layout handles, not at one handle."
	^ #(
		int32 sType;
		void* pNext;
		VkDescriptorPool_H* descriptorPool;
		uint32 descriptorSetCount;
		void* pSetLayouts
	)
]

{ #category : 'labels' }
VkDescriptorSetAllocateInfo class >> nullLabel [
	"A pointer field is reported as set or not set rather than as an address: the address tells
	 a reader nothing and differs on every run."
	^ 'not set'
]

{ #category : 'labels' }
VkDescriptorSetAllocateInfo class >> setLabel [
	^ 'set'
]

{ #category : 'labels' }
VkDescriptorSetAllocateInfo class >> structureTypeNameFor: aValue [
	"Found by asking VkStructureType which of its own constants answers the value the store
	 holds, so the tab names the type the driver will read rather than restating a constant
	 here. A value no constant answers is shown as the number it is."
	^ (VkStructureType class selectors
		   detect: [ :each |
			   (VkStructureType class >> each) numArgs = 0 and: [
				   (VkStructureType perform: each) = aValue ] ]
		   ifNone: [ ^ aValue printString ]) asString
]

{ #category : 'reporting' }
VkDescriptorSetAllocateInfo >> describeField: aFieldName value: aValue [
	"What a row shows for one field. The structure type is named by asking VkStructureType, a
	 count is the number itself, and a pointer is reported as set or not set."

	aFieldName = #sType ifTrue: [
		^ self class structureTypeNameFor: aValue ].
	aValue isNumber ifTrue: [ ^ aValue printString ].
	^ aValue isNull
		  ifTrue: [ self class nullLabel ]
		  ifFalse: [ self class setLabel ]
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorPool [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_DESCRIPTORPOOL) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorPool: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_DESCRIPTORPOOL put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorSetCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DESCRIPTORSETCOUNT
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> descriptorSetCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DESCRIPTORSETCOUNT put: anObject
]

{ #category : 'initialization' }
VkDescriptorSetAllocateInfo >> initialize [
	"The two members the driver reads before any of ours: the structure type that tells it what
	 this block of bytes is, and a cleared chain pointer. FFIStructure class >> fromHandle:
	 sends this, so an instance from externalInstance arrives as ready as one from new and the
	 allocating method writes only the pool, the count and the layout array."

	super initialize.
	self
		sType: VkStructureType descriptorSetAllocateInfo;
		pNext: ExternalAddress null
]

{ #category : 'inspector' }
VkDescriptorSetAllocateInfo >> inspectorRequest: aBuilder [
	"The allocation this info asks for, in Vulkan's terms rather than in bytes: the Layout tab
	 inherited from VkStructure shows where each field sits, this one shows what each field
	 says. Every row is read back through the generated accessors, so the tab cannot claim a
	 request the driver will not be given, and nothing is written."

	<inspectorPresentationOrder: 20 title: 'Request'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Field' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each second ]);
		  items: self requestReport;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pSetLayouts [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSETLAYOUTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> pSetLayouts: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSETLAYOUTS put: anObject getHandle.
]

{ #category : 'reporting' }
VkDescriptorSetAllocateInfo >> requestReport [
	"What this allocate info asks the driver for: one row per declared field, read through the
	 accessor uFFI generated for it. The rows come from the compiled field specification rather
	 than from a list kept here, so a field added to fieldsDesc appears by itself and the
	 report cannot name a field the struct does not have. Reading only, so a report built on a
	 filled in structure leaves its bytes alone."

	^ self class layoutRows collect: [ :row |
		  | fieldName |
		  fieldName := row first.
		  {
			  fieldName asString.
			  (self describeField: fieldName value: (self perform: fieldName)) } ]
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkDescriptorSetAllocateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
