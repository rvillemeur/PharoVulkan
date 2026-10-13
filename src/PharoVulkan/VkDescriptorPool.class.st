"
Vulkan descriptor pool. Holds storage-buffer descriptors for compute pipelines and allocates descriptor sets out of them. The two sizes are independent and both are kept: maxSets is how many sets may be allocated, descriptorCount is how many descriptors the pool holds in total, and one set usually holds several of them. Key methods: on:maxSets:descriptorCount:, allocateSet:, poolReport.
"
Class {
	#name : 'VkDescriptorPool',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'maxSets',
		'descriptorCount',
		'setsAllocated'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'labels' }
VkDescriptorPool class >> descriptorCountRowName [
	^ 'Descriptors the pool holds'
]

{ #category : 'constants' }
VkDescriptorPool class >> descriptorType [
	"Every descriptor in this pool is a storage buffer. The view asks this same method, so
	 the Pool tab cannot name a type the create info does not request."
	^ VkDescriptorType storageBuffer
]

{ #category : 'labels' }
VkDescriptorPool class >> descriptorTypeName [
	"Found by asking VkDescriptorType which of its own constants answers the value the create
	 info writes, so the name follows the request rather than restating it."
	^ (VkDescriptorType class selectors
		   detect: [ :each |
			   (VkDescriptorType class >> each) numArgs = 0 and: [
				   (VkDescriptorType perform: each) = self descriptorType ] ]
		   ifNone: [ ^ self descriptorType printString ]) asString
]

{ #category : 'labels' }
VkDescriptorPool class >> descriptorTypeRowName [
	^ 'Descriptor type'
]

{ #category : 'examples' }
VkDescriptorPool class >> exampleDescriptorCount [
	"Three storage buffers in that one set, as the vector-add kernel binds."
	^ 3
]

{ #category : 'examples' }
VkDescriptorPool class >> exampleElementCount [
	^ 64
]

{ #category : 'examples' }
VkDescriptorPool class >> exampleMaxSets [
	"One set, the shape a compute kernel allocates: every binding lives in that one set."
	^ 1
]

{ #category : 'examples' }
VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers [
	"One click: the pool a three-buffer compute kernel allocates, with one set allocated out
	 of it, then released with its context. The two counts and the allocation count live in
	 the instance, so the pool still answers after its handle and its device have gone, which
	 is what the Pool tab shows."
	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ self new ].
	^ [
	  | pool setLayout set |
	  setLayout := VkDescriptorSetLayout on: context device.
	  0 to: self exampleDescriptorCount - 1 do: [ :binding |
		  setLayout
			  addStorageBufferBinding: binding
			  stageFlags: VkShaderStage computeBit ].
	  setLayout create.
	  pool := self
		          on: context device
		          maxSets: self exampleMaxSets
		          descriptorCount: self exampleDescriptorCount.
	  set := pool allocateSet: setLayout.
	  set handle invalidate.
	  pool destroy.
	  setLayout destroy.
	  pool ] ensure: [ context destroy ]
]

{ #category : 'constants' }
VkDescriptorPool class >> handleByteCount [
	"A Vulkan handle is pointer wide. The driver writes one handle per call into the block this
	 class hands it, so the block is this many bytes per handle."
	^ ExternalAddress wordSize
]

{ #category : 'labels' }
VkDescriptorPool class >> maxSetsRowName [
	^ 'Sets the pool allows'
]

{ #category : 'labels' }
VkDescriptorPool class >> notCreatedLabel [
	^ 'not created'
]

{ #category : 'instance creation' }
VkDescriptorPool class >> on: aDevice maxSets: aMaxSetCount descriptorCount: aDescriptorCount [
	| pool |
	pool := self new.
	pool device: aDevice.
	pool create: aMaxSetCount descriptorCount: aDescriptorCount.
	^ pool
]

{ #category : 'constants' }
VkDescriptorPool class >> poolSizeCount [
	"One VkDescriptorPoolSize is written, because every descriptor in this pool is a storage
	 buffer."
	^ 1
]

{ #category : 'constants' }
VkDescriptorPool class >> setAllocationCount [
	"One set is allocated per call, so the allocate info asks for one and the layout array it
	 points at holds one handle. The array builder asks this method too, so the count and the
	 array it describes cannot disagree."
	^ 1
]

{ #category : 'labels' }
VkDescriptorPool class >> setsAllocatedRowName [
	^ 'Sets allocated so far'
]

{ #category : 'allocating' }
VkDescriptorPool >> allocateSet: aSetLayout [
	"One descriptor set allocated out of this pool, bound to the given layout. The layout
	 handle array outlives the allocate info that points at it and is freed here, after the
	 driver has read both."

	| layouts |
	layouts := self layoutArrayOutsideObjectMemory: aSetLayout.
	^ [ self setForLayoutArray: layouts layout: aSetLayout ]
		  ensure: [ layouts free ]
]

{ #category : 'lifecycle' }
VkDescriptorPool >> create: aMaxSetCount descriptorCount: aDescriptorCount [
	"The two counts are different numbers: maxSets bounds the sets allocated out of the pool,
	 descriptorCount the descriptors they hold between them. Both are kept in the instance, so
	 the Pool tab still answers after the handle has gone.
	 The pool size outlives the create info that points at it and is freed here, after the
	 driver has read both."

	| size |
	maxSets := aMaxSetCount.
	descriptorCount := aDescriptorCount.
	setsAllocated := 0.
	size := self poolSizeOutsideObjectMemory.
	handle := [ self handleForPoolSize: size ]
		          ensure: [ size getHandle free ]
]

{ #category : 'accessing' }
VkDescriptorPool >> descriptorCount [
	^ descriptorCount
]

{ #category : 'lifecycle' }
VkDescriptorPool >> destroy [

	handle isNil ifTrue: [ ^ self ].
	Vk
		destroyDescriptorPool: device handle
		descriptorPool: handle
		allocator: ExternalAddress null.
	handle invalidate.
	handle := nil
]

{ #category : 'accessing' }
VkDescriptorPool >> device: aDevice [
	device := aDevice
]

{ #category : 'accessing' }
VkDescriptorPool >> handle [
	^ handle
]

{ #category : 'private' }
VkDescriptorPool >> handleForCreateInfo: aCreateInfo [
	"vkCreateDescriptorPool writes the new pool's handle into an eight byte block outside the
	 image. The result is checked before that block is read, because a failed call leaves it
	 holding whatever was there."

	| poolBuf result |
	poolBuf := ExternalAddress allocate: 8.
	^ [
	  result := Vk
		            createDescriptorPool: device handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            descriptorPoolOut: poolBuf.
	  Vk checkResult: result.
	  VkDescriptorPool_H fromHandle: (poolBuf pointerAt: 1) ]
		  ensure: [ poolBuf free ]
]

{ #category : 'private' }
VkDescriptorPool >> handleForPoolSize: aPoolSize [
	"The create info, filled through the accessors uFFI generated, so no offset is counted
	 here. externalInstance runs initialize, so the structure type and the null chain pointer
	 are already in place and only the counts and the pointer are written. Its store is freed
	 as soon as the driver has read it; the pool size it points at belongs to the caller."

	| info |
	info := VkDescriptorPoolCreateInfo externalInstance
		        maxSets: maxSets;
		        poolSizeCount: self class poolSizeCount;
		        pPoolSizes: aPoolSize;
		        yourself.
	^ [ self handleForCreateInfo: info ] ensure: [ info getHandle free ]
]

{ #category : 'inspector' }
VkDescriptorPool >> inspectorPool: aBuilder [
	"What this pool was built for. The rows come from the counts the create info wrote and
	 from the type that same method requests, so the tab cannot claim a size the driver was
	 not asked for."
	<inspectorPresentationOrder: 10 title: 'Pool'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Quantity' evaluated: [ :each |
					   each at: #name ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each at: #value ]);
		  items: self poolReport;
		  yourself
]

{ #category : 'private' }
VkDescriptorPool >> layoutArrayOutsideObjectMemory: aSetLayout [
	"The array of set layout handles the allocate info points at. This one is an array of
	 pointers rather than a structure, so uFFI has no field specification to compute offsets
	 from and the element index is computed here. It is the only place in the pool that still
	 indexes a block of bytes, and it indexes it by the handle width rather than by a counted
	 constant. The store is outside object memory because the allocate info holds a pointer to
	 it: a store inside the image could be moved by the garbage collector between that pointer
	 being written and the driver reading it. The caller frees it."

	| width layouts |
	width := self class handleByteCount.
	layouts := ExternalAddress allocate: self class setAllocationCount * width.
	1 to: self class setAllocationCount do: [ :index |
		layouts
			pointerAt: index - 1 * width + 1
			put: aSetLayout handle getHandle ].
	^ layouts
]

{ #category : 'accessing' }
VkDescriptorPool >> maxSets [
	^ maxSets
]

{ #category : 'reporting' }
VkDescriptorPool >> poolReport [
	"The two sizes side by side, because they are the two that used to be one number: a pool
	 of one set holding three descriptors is what a three-buffer kernel allocates. The count
	 of sets handed out shows when the maxSets bound is reached, which is the error
	 VK_ERROR_OUT_OF_POOL_MEMORY the driver answers one call later."
	^ {
		  (self
			   rowNamed: self class maxSetsRowName
			   value: (maxSets
					    ifNil: [ self class notCreatedLabel ]
					    ifNotNil: [ maxSets printString ])).
		  (self
			   rowNamed: self class descriptorCountRowName
			   value: (descriptorCount
					    ifNil: [ self class notCreatedLabel ]
					    ifNotNil: [ descriptorCount printString ])).
		  (self
			   rowNamed: self class setsAllocatedRowName
			   value: self setsAllocated printString).
		  (self
			   rowNamed: self class descriptorTypeRowName
			   value: self class descriptorTypeName) }
]

{ #category : 'private' }
VkDescriptorPool >> poolSizeOutsideObjectMemory [
	"The one VkDescriptorPoolSize this pool asks for, declared field by field so uFFI computes
	 its two offsets. Its store is outside object memory because the create info holds a
	 pointer to it: a store inside the image could be moved by the garbage collector between
	 that pointer being written and the driver reading it. The caller frees it."

	^ VkDescriptorPoolSize externalInstance
		  type: self class descriptorType;
		  descriptorCount: descriptorCount;
		  yourself
]

{ #category : 'reporting' }
VkDescriptorPool >> rowNamed: aString value: aValueString [
	^ Dictionary newFrom: {
			  (#name -> aString).
			  (#value -> aValueString) }
]

{ #category : 'private' }
VkDescriptorPool >> setForAllocateInfo: anAllocateInfo layout: aSetLayout [
	"vkAllocateDescriptorSets writes the new set's handle into a block outside the image. The
	 result is checked before that block is read, because a failed call leaves it holding
	 whatever was there, and because the pool answers VK_ERROR_OUT_OF_POOL_MEMORY once maxSets
	 sets have been handed out. The allocation is counted only after the call succeeded."

	| setBuf result set |
	setBuf := ExternalAddress allocate: self class handleByteCount.
	^ [
	  result := Vk
		            allocateDescriptorSets: device handle
		            allocateInfo: anAllocateInfo getHandle
		            descriptorSets: setBuf.
	  Vk checkResult: result.
	  set := VkDescriptorSet new.
	  set handle: (VkDescriptorSet_H fromHandle: (setBuf pointerAt: 1)).
	  set pool: self.
	  set layout: aSetLayout.
	  set device: device.
	  setsAllocated := self setsAllocated + 1.
	  set ] ensure: [ setBuf free ]
]

{ #category : 'private' }
VkDescriptorPool >> setForLayoutArray: aLayoutArray layout: aSetLayout [
	"The allocate info, filled through the accessors uFFI generated, so no offset is counted
	 here. externalInstance runs initialize, so the structure type and the null chain pointer
	 are already in place and only the pool, the count and the layout array are written. Its
	 store is freed as soon as the driver has read it; the array it points at belongs to the
	 caller."

	| info |
	info := VkDescriptorSetAllocateInfo externalInstance
		        descriptorPool: handle;
		        descriptorSetCount: self class setAllocationCount;
		        pSetLayouts: aLayoutArray;
		        yourself.
	^ [ self setForAllocateInfo: info layout: aSetLayout ]
		  ensure: [ info getHandle free ]
]

{ #category : 'accessing' }
VkDescriptorPool >> setsAllocated [
	"Counted rather than collected, so the pool holds no reference to a set whose handle has
	 already been invalidated."
	^ setsAllocated ifNil: [ 0 ]
]
