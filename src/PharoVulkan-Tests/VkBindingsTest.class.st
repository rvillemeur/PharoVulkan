"
Tests for PharoVulkan-Bindings correctness.
Tests cover result codes, structure types, handle creation, and queue flags
without requiring libvulkan to be installed.
"
Class {
	#name : 'VkBindingsTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Bindings',
	#package : 'PharoVulkan-Tests',
	#tag : 'Bindings'
}

{ #category : 'private' }
VkBindingsTest >> assertHalfOf: aFloat is: anInteger [
	self
		assert: (PVFloat16 wordForFloat: aFloat) = anInteger
		description: aFloat printString , ' encodes to '
			, (PVFloat16 wordForFloat: aFloat) printStringHex , ', expected '
			, anInteger printStringHex
]

{ #category : 'measuring' }
VkBindingsTest >> offsetOf: aFieldName in: aStructureClass [
	"The offset uFFI compiled, shifted to the C offset the driver uses, so a test never hand
	 counts one."

	^ (aStructureClass classVariableNamed:
		   (aStructureClass offsetVariableNameFor: aFieldName)) value - 1
]

{ #category : 'measuring' }
VkBindingsTest >> spanBytesWrittenByDevicePropertiesOf: aPhysicalDeviceHandle [
	"The same query answered into memory outside the image, so the struct's own store can be
	 compared against it byte for byte."

	| capacity probe bytes |
	capacity := 4096.
	probe := ExternalAddress allocate: capacity.
	^ [
	  Vk getPhysicalDeviceProperties: aPhysicalDeviceHandle into: probe.
	  bytes := ByteArray new: capacity.
	  1 to: capacity do: [ :i | bytes at: i put: (probe byteAt: i) ].
	  bytes ] ensure: [ probe free ]
]

{ #category : 'measuring' }
VkBindingsTest >> spanWrittenByDevicePropertiesOf: aPhysicalDeviceHandle sentinel: aByte [
	"Answers how far vkGetPhysicalDeviceProperties writes, measured in a buffer outside object
	 memory so the measurement itself cannot corrupt anything. One sentinel could collide with
	 a byte the driver really wrote, which is why the caller measures twice."

	| capacity probe written |
	capacity := 4096.
	probe := ExternalAddress allocate: capacity.
	^ [
	  1 to: capacity do: [ :i | probe byteAt: i put: aByte ].
	  Vk getPhysicalDeviceProperties: aPhysicalDeviceHandle into: probe.
	  written := 0.
	  1 to: capacity do: [ :i |
		  (probe byteAt: i) = aByte ifFalse: [ written := i ] ].
	  written ] ensure: [ probe free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testAccessAndStageFlagsNameTheirOwnBits [
	"The barrier's view shows four masks, so the two classes that hold the bits are the classes
	 that name them. A mask Vulkan sets no bit in names nothing rather than printing a zero."

	self assert: (VkAccess2 includesBehavior: VkFlagConstants).
	self assert: (VkPipelineStage2 includesBehavior: VkFlagConstants).
	self
		assert: (VkAccess2 nameForFlags:
				 VkAccess2 transferWriteBit | VkAccess2 hostReadBit)
		equals: 'TransferWrite|HostRead'.
	self
		assert: (VkPipelineStage2 nameForFlags: VkPipelineStage2 hostBit)
		equals: 'Host'.
	self assert: (VkPipelineStage2 nameForFlags: 0) equals: ''
]

{ #category : 'tests - structures' }
VkBindingsTest >> testAttachmentAndSubpassDescriptionLayoutsMatchTheCLayout [
	"The three structures the request points at. None of them carries a chain header: these are
	 descriptions read in place rather than chained structures. The attachment description is
	 nine words, the reference two, and the subpass description five counts and flags among
	 five pointers, padded to seventy-two bytes."

	| attachmentRows referenceRows subpassRows |
	attachmentRows := VkAttachmentDescription layoutRows.
	self
		assert: (attachmentRows collect: [ :each | each first ]) asArray
		equals: #( #flags #format #samples #loadOp #storeOp #stencilLoadOp
		           #stencilStoreOp #initialLayout #finalLayout ).
	self
		assert: (attachmentRows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 12 16 20 24 28 32 ).
	self assert: VkAttachmentDescription byteSize equals: 36.
	referenceRows := VkAttachmentReference layoutRows.
	self
		assert: (referenceRows collect: [ :each | each first ]) asArray
		equals: #( #attachment #layout ).
	self
		assert: (referenceRows collect: [ :each | each second ]) asArray
		equals: #( 0 4 ).
	self assert: VkAttachmentReference byteSize equals: 8.
	subpassRows := VkSubpassDescription layoutRows.
	self
		assert: (subpassRows collect: [ :each | each first ]) asArray
		equals: #( #flags #pipelineBindPoint #inputAttachmentCount #pInputAttachments
		           #colorAttachmentCount #pColorAttachments #pResolveAttachments
		           #pDepthStencilAttachment #preserveAttachmentCount
		           #pPreserveAttachments ).
	self
		assert: (subpassRows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 16 24 32 40 48 56 64 ).
	self assert: VkSubpassDescription byteSize equals: 72
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBarrierAndDependencyInfoInitializeOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by either type. Every mask, count and pointer
	 is the recorder's, and a barrier that bars nothing — all masks zero, no barrier of any
	 kind listed — is what a fresh block of each must read as."

	{
		(VkMemoryBarrier2 -> VkStructureType memoryBarrier2).
		(VkDependencyInfo -> VkStructureType dependencyInfo) } do: [ :each |
		| info setters |
		info := each key externalInstance.
		[
			self assert: info sType equals: each value.
			self assert: info pNext isNull ] ensure: [ info getHandle free ].
		setters := (each key >> #initializeConstantFields) messages select: [
			           :selector | each key includesSelector: selector ].
		self assert: setters asArray equals: #( #sType: ) ].
	self
		assert: (VkDependencyInfo externalInstance
				 memoryBarrierCount;
				 yourself) memoryBarrierCount
		equals: 0
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBarrierRecordingWritesNoScalarFieldAtAHandCountedOffset [
	"The barrier and its dependency info are declared, so none of the four methods that build
	 or record them may poke a scalar at a counted offset. Two of them are on the class side,
	 which is where the masks and the counts the whole project waits on now live."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := {
		             (VkCommandBuffer -> #barrierForHostRead).
		             (VkCommandBuffer -> #recordBarrier:).
		             (VkCommandBuffer class -> #hostReadBarrier).
		             (VkCommandBuffer class -> #dependencyForBarrier:) } select: [
		             :each |
		             (each key includesSelector: each value) and: [
			             (each key >> each value) messages anySatisfy: [ :message |
				             banned includes: message ] ] ].
	self assertEmpty: offenders asArray.
	self assert: (VkCommandBuffer includesSelector: #recordBarrier:)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBarrierRowsNameTheMasksAndCountsTheProjectRecords [
	"The rows sample the barrier and the dependency the recorder really builds, so they cannot
	 drift from it: the four masks are named by the constants classes that own the bits, and the
	 dependency carries one memory barrier and no buffer or image barrier."

	| rows |
	rows := VkCommandBuffer new barrierRows.
	self assert: (rows at: #srcStageNames) equals: 'AllTransfer'.
	self assert: (rows at: #srcAccessNames) equals: 'TransferWrite'.
	self assert: (rows at: #dstStageNames) equals: 'Host'.
	self assert: (rows at: #dstAccessNames) equals: 'HostRead'.
	self assert: (rows at: #memoryBarrierCount) equals: 1.
	self assert: (rows at: #bufferMemoryBarrierCount) equals: 0.
	self assert: (rows at: #imageMemoryBarrierCount) equals: 0.
	self assert: (rows at: #dependencyFlags) equals: 0
]

{ #category : 'tests' }
VkBindingsTest >> testBaseOutStructureIsTheHeaderEveryChainedStructureStartsWith [
	"VkBaseOutStructure is what the specification calls the two fields every structure in a
	 pNext chain starts with, and it is what a chain walker reads when it does not know which
	 structures are on the chain. Its own layout is asserted here, and so is the fact that it
	 is a prefix of every chainable structure the image declares: sType and pNext at the same
	 offsets and the same widths, which is what makes reading one through this view correct."

	| rows chainable |
	rows := VkBaseOutStructure layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 ).
	self assert: VkBaseOutStructure byteSize equals: 16.
	chainable := VkStructure allSubclasses select: [ :each |
		             (each class includesSelector: #fieldsDesc) and: [
			             each fieldSpec fieldNames includes: #pNext ] ].
	self assert: chainable size >= 5.
	chainable do: [ :each |
		self
			assert:
				(each layoutRows first: rows size)
			equals: rows ]
]

{ #category : 'tests' }
VkBindingsTest >> testBaseOutStructureViewLeavesTheStructureItReadsAlone [
	"A chain walker reads someone else's structure through this view, so the view may not
	 declare a constant field of its own: FFIStructure class >> fromHandle: sends initialize,
	 and an initializeConstantFields here would stamp its own structure type over the type of
	 whatever structure is being read, which is the one thing the walker is there to find out."

	| features header |
	self
		deny:
			(VkBaseOutStructure includesSelector: #initializeConstantFields).
	features := VkPhysicalDeviceVulkanMemoryModelFeatures externalInstance.
	[
	header := VkBaseOutStructure fromHandle: features getHandle.
	self
		assert: header sType
		equals: VkPhysicalDeviceVulkanMemoryModelFeatures structureType.
	self assert: features sType equals: header sType.
	self assert: header pNext getHandle isNull ] ensure: [
		features getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBufferCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"A fresh buffer create info carries its structure type and nothing else: the size, the
	 usage mask, the sharing mode and the queue family list all belong to the caller, and the
	 degenerate request is an empty exclusive buffer."

	| info setters |
	info := VkBufferCreateInfo externalInstance.
	[
		self assert: info sType equals: VkStructureType bufferCreateInfo.
		self assert: info pNext isNull.
		self assert: info flags equals: 0.
		self assert: info size equals: 0.
		self assert: info usage equals: 0.
		self
			assert: info sharingMode
			equals: VkBufferCreateInfo sharingModeExclusive.
		self assert: info queueFamilyIndexCount equals: 0.
		self assert: info pQueueFamilyIndices isNull ] ensure: [
		info getHandle free ].
	setters := (VkBufferCreateInfo >> #initializeConstantFields) messages
		           select: [ :each | VkBufferCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBufferCreateInfoLayoutMatchesTheCLayout [
	"VkBufferCreateInfo is declared field by field. size is a VkDeviceSize and so eight bytes
	 wide and eight byte aligned, which puts four bytes of padding after flags; usage and
	 sharingMode fill the eight bytes after it, and the queue family count is padded again
	 before the pointer. Fifty six bytes over eight fields."

	| rows |
	rows := VkBufferCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #size #usage #sharingMode
		   #queueFamilyIndexCount #pQueueFamilyIndices ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 36 40 48 ).
	self assert: VkBufferCreateInfo byteSize equals: 56.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBufferCreateInfoRequestRowsNameTheUsageBitsAndChangeNothing [
	"The Request tab decodes the usage mask through the flag constants rather than restating
	 them, and reading it leaves the request untouched."

	| info rows before valueOf |
	info := VkBufferCreateInfo externalInstance.
	[
		info
			size: VkBuffer exampleByteSize;
			usage: VkBuffer storageBufferUsage.
		before := info fieldReport.
		rows := info requestRows.
		self assert: info fieldReport equals: before.
		valueOf := [ :attribute |
		           (rows detect: [ :each | (each at: #attribute) = attribute ])
			           at: #value ].
		self
			assert: (valueOf value: 'Usage')
			equals: (VkBufferUsage nameForFlags: VkBuffer storageBufferUsage).
		self
			assert: (valueOf value: 'Bytes')
			equals: VkBuffer exampleByteSize printString.
		self assert: (valueOf value: 'Sharing') equals: 'exclusive' ] ensure: [
		info getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBufferImageCopyFixesNoFieldByItsType [
	"The copy region carries no chain header, so no field is fixed by the type and the class
	 overrides nothing: a fresh block is a copy of nothing from the start of the buffer, which
	 is what every field reading zero means."

	| region |
	self deny: (VkBufferImageCopy includesSelector: #initializeConstantFields).
	region := VkBufferImageCopy externalInstance.
	[
		self assert: region bufferOffset equals: 0.
		self assert: region bufferRowLength equals: 0.
		self assert: region imageSubresource aspectMask equals: 0.
		self assert: region imageOffset x equals: 0.
		self assert: region imageExtent width equals: 0 ] ensure: [
		region getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testBufferImageCopyLayoutMatchesTheCLayout [
	"The copy region carries three nested structures by value rather than by pointer, so the
	 nested fields sit inside the parent's fifty-six bytes: a sixteen byte subresource at
	 sixteen, a twelve byte offset at thirty-two and a twelve byte extent at forty-four."

	| rows |
	rows := VkBufferImageCopy layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #bufferOffset #bufferRowLength #bufferImageHeight
		           #imageSubresource #imageOffset #imageExtent ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 12 16 32 44 ).
	self
		assert: (rows collect: [ :each | each third ]) asArray
		equals: #( 8 4 4 16 12 12 ).
	self assert: VkBufferImageCopy byteSize equals: 56
]

{ #category : 'tests - structures' }
VkBindingsTest >> testClearValueArrayIsReadByItsNamedStride [
	"A clear value is a union of arrays, and uFFI in this image cannot declare an array field,
	 so the clear values are a block with no field specification: the stride and the component
	 count are named and the block is read back by them. The components are written in the order
	 Vulkan reads them, which the test pins by giving each one a different value."

	| colour values |
	colour := #( 0.0 0.25 0.5 1.0 ).
	values := VkCommandBuffer clearValuesOutsideObjectMemory: colour.
	[
		self
			assert: VkCommandBuffer clearComponentCount
			  * VkCommandBuffer clearComponentByteCount
			equals: 16.
		1 to: VkCommandBuffer clearComponentCount do: [ :index |
			self
				assert: (values floatAt:
						 index - 1 * VkCommandBuffer clearComponentByteCount + 1)
				equals: (colour at: index) ] ] ensure: [ values free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testColourPassDescriptionsClearTheAttachmentAndLeaveItWhereItIsAsked [
	"What the three builders write, with no device in reach. The attachment is cleared on load
	 and kept on store, its stencil halves are not used, it comes in undefined and leaves in the
	 layout the caller names — which is where the two pass variants differ. The subpass reads it
	 as a colour attachment at the graphics bind point and names no other attachment."

	| description reference subpass |
	description := VkRenderPass
		               attachmentDescriptionForFormat: VkFormat b8g8r8a8Unorm
		               finalLayout: VkImageLayout transferSrcOptimal.
	[
		self assert: description flags equals: 0.
		self assert: description format equals: VkFormat b8g8r8a8Unorm.
		self assert: description samples equals: VkRenderConfig sampleCount1Bit.
		self assert: description loadOp equals: VkAttachmentOp loadClear.
		self assert: description storeOp equals: VkAttachmentOp storeStore.
		self
			assert: description stencilLoadOp
			equals: VkAttachmentOp loadDontCare.
		self
			assert: description stencilStoreOp
			equals: VkAttachmentOp storeDiscard.
		self assert: description initialLayout equals: VkImageLayout undefined.
		self
			assert: description finalLayout
			equals: VkImageLayout transferSrcOptimal ] ensure: [
		description getHandle free ].
	reference := VkRenderPass colorAttachmentReference.
	[
		self
			assert: reference attachment
			equals: VkRenderPass firstAttachmentIndex.
		self
			assert: reference layout
			equals: VkImageLayout colorAttachmentOptimal ] ensure: [
		reference getHandle free ].
	reference := VkRenderPass colorAttachmentReference.
	[
		subpass := VkRenderPass subpassDescriptionReading: reference.
		[
			self
				assert: subpass pipelineBindPoint
				equals: VkPipelineBindPoint graphics.
			self
				assert: subpass colorAttachmentCount
				equals: VkRenderPass colorAttachmentsPerSubpass.
			self deny: subpass pColorAttachments isNull.
			self assert: subpass inputAttachmentCount equals: 0.
			self assert: subpass pInputAttachments isNull.
			self assert: subpass pResolveAttachments isNull.
			self assert: subpass pDepthStencilAttachment isNull.
			self assert: subpass preserveAttachmentCount equals: 0.
			self assert: subpass pPreserveAttachments isNull ] ensure: [
			subpass getHandle free ] ] ensure: [ reference getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferAllocateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type. The level is not: a secondary
	 buffer is allocated from the same structure, and a zeroed block already reads as primary
	 because primary is zero in Vulkan, which is a coincidence of the enumeration rather than
	 something to rely on."

	| info setters |
	info := VkCommandBufferAllocateInfo externalInstance.
	[
		self
			assert: info sType
			equals: VkStructureType commandBufferAllocateInfo.
		self assert: info pNext isNull.
		self assert: info commandPool isNull.
		self assert: info level equals: 0.
		self assert: info commandBufferCount equals: 0 ] ensure: [
		info getHandle free ].
	setters := (VkCommandBufferAllocateInfo >> #initializeConstantFields)
		           messages select: [ :each |
		           VkCommandBufferAllocateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferAllocateInfoLayoutMatchesTheCLayout [
	"The pool the buffers come from is a handle, so it is pointer wide and eight byte aligned;
	 the level and the count are words that follow it with no padding between them, which makes
	 the structure thirty-two bytes."

	| rows |
	rows := VkCommandBufferAllocateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #commandPool #level #commandBufferCount ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 28 ).
	self assert: VkCommandBufferAllocateInfo byteSize equals: 32
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferBeginInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type. The usage flags are the recorder's
	 choice, and the inheritance pointer is read for a secondary buffer only, so a fresh block
	 leaves it null rather than carrying a request a primary buffer must not make."

	| info setters |
	info := VkCommandBufferBeginInfo externalInstance.
	[
		self
			assert: info sType
			equals: VkStructureType commandBufferBeginInfo.
		self assert: info pNext isNull.
		self assert: info flags equals: 0.
		self assert: info pInheritanceInfo isNull ] ensure: [
		info getHandle free ].
	setters := (VkCommandBufferBeginInfo >> #initializeConstantFields)
		           messages select: [ :each |
		           VkCommandBufferBeginInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferBeginInfoLayoutMatchesTheCLayout [
	"The usage flags are one word and the inheritance pointer that follows them is eight byte
	 aligned, so four bytes of padding sit between them and the structure is thirty-two bytes."

	| rows |
	rows := VkCommandBufferBeginInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #pInheritanceInfo ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 ).
	self assert: VkCommandBufferBeginInfo byteSize equals: 32
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferLevelNamesItsOwnValues [
	"The level is shown by the command buffer's view, so the class that holds the values is the
	 class that names them. The view must never carry a table of Vulkan names of its own."

	self assert: (VkCommandBufferLevel includesBehavior: VkValueConstants).
	self
		assert: (VkCommandBufferLevel nameForValue:
				 VkCommandBufferLevel primary)
		equals: 'primary'.
	self
		assert: (VkCommandBufferLevel nameForValue:
				 VkCommandBufferLevel secondary)
		equals: 'secondary'
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferRecordingWritesNoScalarFieldAtAHandCountedOffset [
	"The begin info is declared, so neither the method that opens a recording nor the one that
	 hands it to the driver may poke a scalar at a counted offset. The ban is on these two
	 methods rather than on the class: the structures the other recording methods write — the
	 barriers, the copy, the render pass begin, the viewport and the scissor — belong to the
	 later units of group three."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := #( #begin #beginRecordingWith: ) select: [ :selector |
		             (VkCommandBuffer includesSelector: selector) and: [
			             (VkCommandBuffer >> selector) messages anySatisfy: [
				             :message | banned includes: message ] ] ].
	self assertEmpty: offenders asArray.
	self assert: (VkCommandBuffer includesSelector: #beginRecordingWith:)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferRowsNameTheRecordingFlagsTheProjectAlwaysUses [
	"Every recording here is submitted once and thrown away, so the flags are a property of the
	 class rather than of an instance, and the rows name them through the constants class. The
	 rows answer on a buffer that was never allocated, which is what the example gives on a
	 machine with no device."

	| rows |
	rows := VkCommandBuffer new bufferRows.
	self
		assert: (rows at: #recordingFlags)
		equals: VkCommandBufferUsageFlag oneTimeSubmitBit.
	self
		assert: (rows at: #recordingFlagNames)
		equals: 'OneTimeSubmit'
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferUsageFlagNamesItsOwnBits [
	"The recording flags are shown by the command buffer's view, so the class that holds the
	 bits is the class that names them."

	self
		assert: (VkCommandBufferUsageFlag includesBehavior: VkFlagConstants).
	self
		assert: (VkCommandBufferUsageFlag nameForFlags:
				 VkCommandBufferUsageFlag oneTimeSubmitBit)
		equals: 'OneTimeSubmit'.
	self
		assert: (VkCommandBufferUsageFlag nameForFlags:
				 VkCommandBufferUsageFlag renderPassContinueBit
				 | VkCommandBufferUsageFlag simultaneousUseBit)
		equals: 'RenderPassContinue|SimultaneousUse'.
	self assert: (VkCommandBufferUsageFlag nameForFlags: 0) equals: ''
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandBufferWithNoPoolReportsNoQueueFamilyAndIsNotLive [
	"The example answers an unallocated buffer on a machine with no device, so the rows must
	 open on one: no pool to ask for a queue family, the level primary because that is what
	 the allocate info would have asked for, and nothing live."

	| rows |
	rows := VkCommandBuffer new bufferRows.
	self assert: (rows at: #level) equals: VkCommandBufferLevel primary.
	self assert: (rows at: #levelName) equals: 'primary'.
	self assert: (rows at: #queueFamilyIndex) isNil.
	self deny: (rows at: #live)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandPoolCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type. The reset flag every pool here
	 asks for is written by the writer, not stamped in the initializer: a pool without it is a
	 pool whose buffers can only be reset as a whole, which is a caller's choice rather than a
	 property of the structure."

	| info setters |
	info := VkCommandPoolCreateInfo externalInstance.
	[
		self
			assert: info sType
			equals: VkStructureType commandPoolCreateInfo.
		self assert: info pNext isNull.
		self assert: info flags equals: 0.
		self assert: info queueFamilyIndex equals: 0 ] ensure: [
		info getHandle free ].
	setters := (VkCommandPoolCreateInfo >> #initializeConstantFields)
		           messages select: [ :each |
		           VkCommandPoolCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandPoolCreateInfoLayoutMatchesTheCLayout [
	"The chain header, the creation flags and the queue family the pool serves: four words
	 after the chain pointer, so the structure is twenty-four bytes with no padding at the
	 end."

	| rows |
	rows := VkCommandPoolCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #queueFamilyIndex ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 ).
	self assert: VkCommandPoolCreateInfo byteSize equals: 24
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCommandPoolWritesNoScalarFieldAtAHandCountedOffset [
	"Both structures the pool hands the driver are now declared — the create info it is made
	 from and the allocate info its buffers come from — so no method of the class, on either
	 side, may poke a scalar at a counted offset. The device's delegation is held to the same
	 ban, since it used to write the create info itself. The buffer the pool answers is not
	 covered: the structures it records commands through belong to group three of the plan."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := ({
		              VkCommandPool.
		              VkCommandPool class } flatCollect: [ :each |
		              each methods ]) select: [ :each |
		             each messages anySatisfy: [ :message |
			             banned includes: message ] ].
	self
		assertEmpty: (offenders collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray.
	self
		deny: ((VkDevice >> #createCommandPool:) messages anySatisfy: [
				 :message | banned includes: message ])
]

{ #category : 'tests - structures' }
VkBindingsTest >> testComponentMappingAndSubresourceRangeLayoutsMatchTheCLayout [
	"Both are carried by value inside the image view request, so their own widths decide where
	 the request's last field sits: four swizzles make sixteen bytes, five range words make
	 twenty."

	| mappingRows rangeRows |
	mappingRows := VkComponentMapping layoutRows.
	self
		assert: (mappingRows collect: [ :each | each first ]) asArray
		equals: #( #r #g #b #a ).
	self
		assert: (mappingRows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 12 ).
	self assert: VkComponentMapping byteSize equals: 16.
	rangeRows := VkImageSubresourceRange layoutRows.
	self
		assert: (rangeRows collect: [ :each | each first ]) asArray
		equals: #( #aspectMask #baseMipLevel #levelCount #baseArrayLayer #layerCount ).
	self
		assert: (rangeRows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 12 16 ).
	self assert: VkImageSubresourceRange byteSize equals: 20
]

{ #category : 'tests - layout' }
VkBindingsTest >> testComputeSubmitCarriesOneCommandBufferAndNoSemaphore [
	"The compute path submits one command buffer and waits with vkQueueWaitIdle, so its batch
	 carries one command buffer info and no semaphore info at all. The two semaphore counts and
	 their pointers are the zeros and nulls a fresh block holds, which is what asking the
	 builder for no semaphore means."

	| info |
	info := VkQueue
		        submitInfoFor: ExternalAddress null
		        waitSemaphoreInfo: nil
		        signalSemaphoreInfo: nil.
	[
		self
			assert: info commandBufferInfoCount
			equals: VkQueue commandBufferInfosPerSubmit.
		self assert: info waitSemaphoreInfoCount equals: 0.
		self assert: info signalSemaphoreInfoCount equals: 0.
		self assert: info pWaitSemaphoreInfos isNull.
		self assert: info pSignalSemaphoreInfos isNull.
		self assert: info flags equals: 0 ] ensure: [ info getHandle free ]
]

{ #category : 'tests' }
VkBindingsTest >> testCooperativeMatrixFeaturesLayoutMatchesTheCLayout [
	"VkPhysicalDeviceCooperativeMatrixFeaturesKHR is declared field by field. The robust buffer
	 access flag is the second of two VkBool32 members and is left off by this project, which
	 is the reason it has to be declared rather than left to whatever was in the block."

	| rows |
	rows := VkPhysicalDeviceCooperativeMatrixFeaturesKHR layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #cooperativeMatrix
		   #cooperativeMatrixRobustBufferAccess ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 ).
	self
		assert: VkPhysicalDeviceCooperativeMatrixFeaturesKHR byteSize
		equals: 24.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCopyBytesIntoCopiesTheDeclaredSpanAndNothingBeyondIt [
	"A structure built in object memory is moved into an element of an external array by
	 copying the span the declared layout gives it. The copy stops at byteSize, so the element
	 after it keeps the zeroes the array was allocated with."

	| binding elements |
	binding := VkDescriptorSetLayoutBinding new.
	binding
		binding: 3;
		descriptorType: VkDescriptorType storageBuffer;
		descriptorCount: 1;
		stageFlags: VkShaderStage computeBit.
	elements := VkDescriptorSetLayoutBinding externalArrayOf: 2.
	[
		binding copyBytesInto: elements first.
		self assert: elements first binding equals: 3.
		self
			assert: elements first descriptorType
			equals: VkDescriptorType storageBuffer.
		self assert: elements first descriptorCount equals: 1.
		self
			assert: elements first stageFlags
			equals: VkShaderStage computeBit.
		self assert: elements second binding equals: 0.
		self assert: elements second descriptorCount equals: 0 ] ensure: [
		elements first getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCopyRegionWritesOnlyWhatIsNotAlreadyZero [
	"The region the recorder builds for an extent: the colour aspect, one layer, and the extent
	 itself with a depth of one because the image is two dimensional. Everything else — the
	 buffer offset, the row packing, the mip level, the array layer and the image offset — is
	 the zero a fresh block already holds, so nothing writes it. Zero row length and zero image
	 height ask the driver for tightly packed rows, which is what the host side indexes by."

	| region extent |
	extent := 3 @ 2.
	region := VkCommandBuffer regionForExtent: extent.
	[
		self
			assert: region imageSubresource aspectMask
			equals: VkImageAspect colorBit.
		self
			assert: region imageSubresource layerCount
			equals: VkCommandBuffer layersPerCopy.
		self assert: region imageExtent width equals: extent x.
		self assert: region imageExtent height equals: extent y.
		self assert: region imageExtent depth equals: VkCommandBuffer copyDepth.
		self assert: region bufferOffset equals: 0.
		self assert: region bufferRowLength equals: 0.
		self assert: region bufferImageHeight equals: 0.
		self assert: region imageSubresource mipLevel equals: 0.
		self assert: region imageSubresource baseArrayLayer equals: 0.
		self assert: region imageOffset x equals: 0.
		self assert: region imageOffset y equals: 0.
		self assert: region imageOffset z equals: 0 ] ensure: [
		region getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testCopyRowsNameTheAspectAndThePacking [
	"The Copy tab reads its rows off the region itself, so it cannot claim a packing or an
	 aspect the region stopped carrying. A row length of zero means tightly packed rows, which
	 the row says in words rather than leaving a reader to read a zero."

	| region rows |
	region := VkCommandBuffer regionForExtent: 3 @ 2.
	rows := [ region copyRows ] ensure: [ region getHandle free ].
	self assert: (rows at: #aspectNames) equals: 'Color'.
	self assert: (rows at: #tightlyPackedRows).
	self assert: (rows at: #extent) equals: 3 @ 2.
	self assert: (rows at: #depth) equals: 1.
	self assert: (rows at: #layerCount) equals: 1.
	self assert: (rows at: #imageOffset) equals: 0 @ 0
]

{ #category : 'tests' }
VkBindingsTest >> testCreateDestroyInstance [
    | info instance |
    info := VkInstanceCreateInfo new.
    instance := Vk createInstance: info.
    self assert: instance isNotNil.
    Vk destroyInstance: instance allocator: ExternalAddress null
]

{ #category : 'tests - structures' }
VkBindingsTest >> testDependencyInfoLayoutMatchesTheCLayout [
	"Three count-and-pointer pairs follow the flags, and each count is one word while each
	 pointer is eight byte aligned, so uFFI pads after the second and third counts and the
	 structure is sixty-four bytes."

	| rows |
	rows := VkDependencyInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #dependencyFlags #memoryBarrierCount
		           #pMemoryBarriers #bufferMemoryBarrierCount
		           #pBufferMemoryBarriers #imageMemoryBarrierCount
		           #pImageMemoryBarriers ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 40 48 56 ).
	self assert: VkDependencyInfo byteSize equals: 64
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorBufferInfoLayoutMatchesTheCLayout [
	"VkDescriptorBufferInfo is declared field by field. The buffer is a handle and therefore
	 pointer wide; the offset and the range are VkDeviceSize, which is uint64, so the three
	 members sit on eight byte boundaries and the struct is twenty four bytes with no hole."

	| rows |
	rows := VkDescriptorBufferInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #buffer #offset #range ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 ).
	self assert: VkDescriptorBufferInfo byteSize equals: 24.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorBufferInfoWholeSizeFillsTheRangeField [
	"VK_WHOLE_SIZE is every bit of a VkDeviceSize set, which is what tells the driver to use
	 the buffer from the given offset to its end. The constant is the value the C header gives
	 and is checked here against the declared width of the range field, so a field declared
	 narrower than uint64 fails rather than truncating the sentinel into a real length.
	 The degenerate state is the zeroed store: a range of zero is not a legal descriptor, so
	 every path that builds one for the driver has to name the range itself. initialize may not
	 do it, because a getter for a field pointing at this type writes back whatever initialize
	 sets."

	| rangeRow |
	rangeRow := VkDescriptorBufferInfo layoutRows detect: [ :each |
		            each first = #range ].
	self
		assert: VkDescriptorBufferInfo wholeSize
		equals: (2 raisedTo: rangeRow third * 8) - 1.
	self assert: VkDescriptorBufferInfo new range equals: 0.
	self
		assert: VkDescriptorBufferInfo exampleWholeStorageBuffer range
		equals: VkDescriptorBufferInfo wholeSize
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorPoolCreateInfoCarriesItsOwnStructureType [
	"Observed, not assumed: FFIStructure class >> fromHandle: sends initialize after setting
	 the store, so externalInstance answers a block of memory outside the image that already
	 names its structure type, exactly as new does inside the image. create:descriptorCount:
	 relies on that and writes only the two counts and the pointer, so this test is what stops
	 initialize from quietly dropping sType."

	| external |
	#( #new #externalInstance ) do: [ :creator |
		| info |
		info := VkDescriptorPoolCreateInfo perform: creator.
		self
			assert: info sType
			equals: VkStructureType descriptorPoolCreateInfo.
		self assert: info maxSets equals: 0.
		self assert: info poolSizeCount equals: 0.
		creator = #externalInstance ifTrue: [ info getHandle free ] ].
	external := VkDescriptorPoolSize externalInstance.
	[
	self assert: external type equals: 0.
	self assert: external descriptorCount equals: 0 ]
		ensure: [ external getHandle free ]
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorPoolCreateInfoLayoutMatchesTheCLayout [
	"VkDescriptorPoolCreateInfo is declared field by field. The offsets to pin are the ones
	 the driver reads: the two pointer members sit on eight byte boundaries, which puts a four
	 byte hole between poolSizeCount and pPoolSizes, and the struct is forty bytes. A field
	 whose offset uFFI computed differently would be written where the driver does not look."

	| rows |
	rows := VkDescriptorPoolCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #maxSets #poolSizeCount #pPoolSizes ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 ).
	self assert: VkDescriptorPoolCreateInfo byteSize equals: 40.
	rows do: [ :each |
		self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorPoolCreateInfoLayoutRowsReadTheStoreAndLeaveItAlone [
	"The Layout tab the structures inherit prints one row per declared field, read from this
	 instance's own store. The facts to state are that a row's head really is the bytes at that
	 field's offset, little end first, and that building every row leaves the store untouched:
	 a view that moved a byte of a create info would change what the driver reads. The expected
	 head is derived from the count the example sets, so it follows a change to the example."

	| info before rows maxSetsRow expected |
	info := VkDescriptorPoolCreateInfo exampleForOneSetOfThreeDescriptors.
	before := info getHandle copy.
	rows := VkDescriptorPoolCreateInfo layoutRows.
	rows do: [ :each | info headOfFieldAt: each second size: each third ].
	self assert: info getHandle equals: before.
	self assert: info maxSets equals: VkDescriptorPool exampleMaxSets.
	self assert: VkDescriptorPool exampleMaxSets < 256.
	maxSetsRow := rows detect: [ :each | each first = #maxSets ].
	expected := (VkDescriptorPool exampleMaxSets
		             printPaddedWith: $0
		             to: 2
		             base: 16) , ' 00 00 00'.
	self
		assert: (info headOfFieldAt: maxSetsRow second size: maxSetsRow third)
		equals: expected
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorPoolCreateInfoPointsAtThePoolSizeItWasGiven [
	"pPoolSizes is a pointer field: the create info must hold the address of the pool size, not
	 a copy of its bytes, because the driver follows it. Both stores are allocated outside
	 object memory, which is the arrangement create:descriptorCount: uses, and the read back
	 goes through the pointer."

	| size info |
	size := VkDescriptorPoolSize externalInstance.
	[
	size type: VkDescriptorType storageBuffer.
	size descriptorCount: VkDescriptorPool exampleDescriptorCount.
	info := VkDescriptorPoolCreateInfo externalInstance.
	[
	info maxSets: VkDescriptorPool exampleMaxSets.
	info poolSizeCount: VkDescriptorPool poolSizeCount.
	info pPoolSizes: size.
	self assert: info pPoolSizes getHandle equals: size getHandle.
	self
		assert: info pPoolSizes descriptorCount
		equals: VkDescriptorPool exampleDescriptorCount.
	self assert: info pPoolSizes type equals: VkDescriptorType storageBuffer.
	self assert: info maxSets equals: VkDescriptorPool exampleMaxSets ]
		ensure: [ info getHandle free ] ] ensure: [ size getHandle free ]
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorPoolCreateWritesThroughDeclaredFields [
	"The pool size, the pool create info and the set allocate info are filled through the
	 accessors uFFI generated from their field specifications. The fact to state is that no
	 method building one of them pokes a raw offset into a block of bytes: a reintroduced
	 unsignedLongAt:put: is a hand counted offset again, and one counted short of the struct
	 writes outside it. The methods are found by the classes they mention rather than listed,
	 so splitting a method further keeps them covered, and the count is asserted so a rename
	 cannot leave nothing tested.
	 The one array a set allocation still writes by hand is the one element list of set layout
	 handles, which is an array of pointers and not a structure; it lives in a method of its
	 own that names no structure class, so it is outside this set and this test stays about
	 structure fields."

	| structures builders pokes |
	structures := #( #VkDescriptorPoolSize #VkDescriptorPoolCreateInfo
	                 #VkDescriptorSetAllocateInfo ).
	pokes := #( #unsignedLongAt:put: #unsignedLongLongAt:put: #pointerAt:put:
	            #byteAt:put: #unsignedShortAt:put: ).
	builders := VkDescriptorPool methods select: [ :each |
		            each literals anySatisfy: [ :literal |
			            literal isVariableBinding and: [
				            structures includes: literal key ] ] ].
	self assert: builders size >= 3.
	builders do: [ :each |
		self
			assertEmpty: (each messages select: [ :message |
					 pokes includes: message ]) ]
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorPoolSizeLayoutMatchesTheCLayout [
	"VkDescriptorPoolSize is declared field by field, so the two offsets come from the
	 specification uFFI compiled rather than from bytes counted by hand in the method that
	 writes it. The C layout is two uint32 members in one eight byte struct."

	| rows |
	rows := VkDescriptorPoolSize layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #type #descriptorCount ).
	self assert: (rows collect: [ :each | each second ]) asArray equals: #( 0 4 ).
	self assert: (rows collect: [ :each | each third ]) asArray equals: #( 4 4 ).
	self assert: VkDescriptorPoolSize byteSize equals: 8
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorSetAllocateInfoCarriesItsOwnStructureType [
	"initialize names the structure type and clears the chain pointer, and FFIStructure class >>
	 fromHandle: sends it, so an allocate info from externalInstance is as ready as one from
	 new. The degenerate case is the one that matters: a count left at zero asks the driver for
	 no set at all, so it must start at zero and be written by the allocating method."

	#( #new #externalInstance ) do: [ :creator |
		| info |
		info := VkDescriptorSetAllocateInfo perform: creator.
		self
			assert: info sType
			equals: VkStructureType descriptorSetAllocateInfo.
		self assert: info descriptorSetCount equals: 0.
		creator = #externalInstance ifTrue: [ info getHandle free ] ]
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorSetAllocateInfoFieldReportNamesWhatItAsksFor [
	"The Fields tab's rows come from the compiled field specification and are read through the
	 generated accessors, so the tab follows fieldsDesc and cannot name a field the struct does
	 not have. The structure type row is checked by mapping its name back to the constant, so a
	 second constant of the same value cannot make it pass by accident, and a pointer nobody
	 has set reads as not set."

	| info rows valueOf |
	info := VkDescriptorSetAllocateInfo exampleForOneSetOfThreeBindings.
	rows := info fieldReport.
	valueOf := [ :fieldName |
	            (rows detect: [ :each | each first = fieldName ]) second ].
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: (VkDescriptorSetAllocateInfo layoutRows collect: [ :each |
				 each first asString ]) asArray.
	self
		assert: (VkStructureType perform: (valueOf value: 'sType') asSymbol)
		equals: VkStructureType descriptorSetAllocateInfo.
	self
		assert: (valueOf value: 'descriptorSetCount')
		equals: VkDescriptorPool setAllocationCount printString.
	self
		assert: (valueOf value: 'pSetLayouts')
		equals: VkDescriptorSetAllocateInfo nullLabel
]

{ #category : 'tests' }
VkBindingsTest >> testDescriptorSetAllocateInfoLayoutMatchesTheCLayout [
	"VkDescriptorSetAllocateInfo is declared field by field. The offsets to pin are the ones the
	 driver reads: three pointer sized members on eight byte boundaries, which puts a four byte
	 hole between descriptorSetCount and pSetLayouts, and forty bytes in total. descriptorPool
	 is a handle, so it is pointer wide and not a count."

	| rows |
	rows := VkDescriptorSetAllocateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #descriptorPool #descriptorSetCount #pSetLayouts ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 ).
	self assert: VkDescriptorSetAllocateInfo byteSize equals: 40.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testDescriptorSetLayoutBindingLayoutMatchesTheCLayout [
	"VkDescriptorSetLayoutBinding is four words followed by a sampler array pointer, which is
	 eight byte aligned, so the structure is twenty-four bytes. It carries no chain header: a
	 binding is an element of an array, not a structure the driver is handed on its own, so it
	 declares no constant field either."

	| rows |
	rows := VkDescriptorSetLayoutBinding layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #binding #descriptorType #descriptorCount #stageFlags
		   #pImmutableSamplers ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 12 16 ).
	self assert: VkDescriptorSetLayoutBinding byteSize equals: 24.
	self
		deny: (VkDescriptorSetLayoutBinding includesSelector:
				 #initializeConstantFields)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testDescriptorSetLayoutCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field a fresh layout request can know. The flags, the
	 binding count and the binding array pointer all describe the layout being asked for, so a
	 fresh block reads as the empty layout: no flag, no binding, no array."

	| info setters |
	info := VkDescriptorSetLayoutCreateInfo externalInstance.
	[
		self
			assert: info sType
			equals: VkStructureType descriptorSetLayoutCreateInfo.
		self assert: info pNext isNull.
		self assert: info flags equals: 0.
		self assert: info bindingCount equals: 0.
		self assert: info pBindings isNull ] ensure: [ info getHandle free ].
	setters := (VkDescriptorSetLayoutCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkDescriptorSetLayoutCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testDescriptorSetLayoutCreateInfoLayoutMatchesTheCLayout [
	"The chain header, the flags, the binding count and the pointer to the binding array: the
	 count and the pointer share the eight bytes after flags only because the count is padded
	 to the pointer's alignment, which is why the pointer is at twenty-four and not twenty."

	| rows |
	rows := VkDescriptorSetLayoutCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #bindingCount #pBindings ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 ).
	self assert: VkDescriptorSetLayoutCreateInfo byteSize equals: 32
]

{ #category : 'tests - constants' }
VkBindingsTest >> testDescriptorTypeAndShaderStageNameTheirOwnValues [
	"The descriptor set layout view shows what each binding declares, and a binding's type and
	 stage mask are numbers. Both classes therefore answer the names themselves — the value
	 class decoding one value, the flag class decoding a mask — so no view carries a table of
	 its own that could drift from the constants."

	self assert: (VkDescriptorType includesBehavior: VkValueConstants).
	self assert: (VkShaderStage includesBehavior: VkFlagConstants).
	self
		assert: (VkDescriptorType nameForValue: VkDescriptorType storageBuffer)
		equals: 'storageBuffer'.
	self
		assert: (VkShaderStage nameForFlags: VkShaderStage computeBit)
		equals: 'Compute'.
	self
		assert: (VkShaderStage nameForFlags:
				 VkShaderStage vertexBit | VkShaderStage fragmentBit)
		equals: 'Vertex|Fragment'
]

{ #category : 'tests' }
VkBindingsTest >> testDeviceCreateInfoCarriesItsOwnStructureTypeAndNoChain [
	"The structure type is the only constant field: pNext carries the feature chain, which is
	 data and differs per device, so initialization may not write it. The degenerate state is
	 what externalInstance answers — a device asked for with no queues, no layers and no
	 extensions — because a zeroed count beside a null pointer is what tells the driver there
	 are none of something, and only the caller knows how many there are."

	| info |
	info := VkDeviceCreateInfo externalInstance.
	[
	self assert: info sType equals: VkStructureType deviceCreateInfo.
	self assert: info pNext isNull.
	self assert: info queueCreateInfoCount equals: 0.
	self assert: info pQueueCreateInfos isNull.
	self assert: info enabledExtensionCount equals: 0.
	self assert: info ppEnabledExtensionNames isNull.
	self assert: (VkDeviceCreateInfo includesSelector: #initialize) not ]
		ensure: [ info getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testDeviceCreateInfoLayoutMatchesTheCLayout [
	"VkDeviceCreateInfo is declared field by field. Each count is a uint32 sitting in the four
	 bytes before a pointer, so uFFI pads four bytes after every one of them and the struct is
	 seventy two bytes over ten fields."

	| rows |
	rows := VkDeviceCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #queueCreateInfoCount #pQueueCreateInfos
		   #enabledLayerCount #ppEnabledLayerNames #enabledExtensionCount
		   #ppEnabledExtensionNames #pEnabledFeatures ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 40 48 56 64 ).
	self assert: VkDeviceCreateInfo byteSize equals: 72.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests' }
VkBindingsTest >> testDeviceCreateWritesAndReadsThroughDeclaredFields [
	"Every method of VkContext that deals with a device create info goes through the accessors
	 uFFI generated, reading included: the readers used to count offset 49 and offset 57 by
	 hand, which is the same hazard as writing them. The methods are found by the class they
	 mention rather than listed, and the count is asserted so a rename cannot leave nothing
	 tested."

	| pokes reads touchers |
	pokes := #( #unsignedLongAt:put: #unsignedLongLongAt:put: #pointerAt:put:
	            #byteAt:put: #unsignedShortAt:put: #floatAt:put: ).
	reads := #( #unsignedLongAt: #unsignedLongLongAt: #pointerAt:
	            #unsignedShortAt: ).
	touchers := VkContext methods select: [ :each |
		            each literals anySatisfy: [ :literal |
			            literal isVariableBinding and: [
				            literal key = #VkDeviceCreateInfo ] ] ].
	self assert: touchers size >= 2.
	touchers do: [ :each |
		self
			assertEmpty: (each messages select: [ :message |
					 (pokes , reads) includes: message ]) ]
]

{ #category : 'tests' }
VkBindingsTest >> testDeviceQueueCreateInfoCarriesItsOwnStructureType [
	"A zeroed store would ask the driver for queue family zero with zero queues, which is not a
	 legal request, so the type is set by initialization and the counts are left to the caller:
	 the degenerate state has to be visible rather than filled in silently."

	| info |
	info := VkDeviceQueueCreateInfo externalInstance.
	[
	self
		assert: info sType
		equals: VkStructureType deviceQueueCreateInfo.
	self assert: info pNext isNull.
	self assert: info queueFamilyIndex equals: 0.
	self assert: info queueCount equals: 0 ] ensure: [ info getHandle free ]
]

{ #category : 'tests' }
VkBindingsTest >> testDeviceQueueCreateInfoLayoutMatchesTheCLayout [
	"VkDeviceQueueCreateInfo is declared field by field. The three uint32 members fill the
	 twelve bytes after pNext, and pQueuePriorities is a pointer, so uFFI pads four bytes
	 before it to put it on an eight byte boundary and the struct is forty bytes."

	| rows |
	rows := VkDeviceQueueCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #queueFamilyIndex #queueCount
		   #pQueuePriorities ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 ).
	self assert: VkDeviceQueueCreateInfo byteSize equals: 40.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests' }
VkBindingsTest >> testDeviceQueueCreateWritesThroughDeclaredFields [
	"Every method of VkContext that deals with a queue create info fills it through the
	 accessors uFFI generated, so none of them pokes a raw offset. The methods are found by the
	 class they mention rather than listed, and the count is asserted so a rename cannot leave
	 nothing tested. The array of queue priorities is not a structure and has no field
	 specification, so the method that fills it names no structure class and is not caught here."

	| pokes builders |
	pokes := #( #unsignedLongAt:put: #unsignedLongLongAt:put: #pointerAt:put:
	            #byteAt:put: #unsignedShortAt:put: #floatAt:put: ).
	builders := VkContext methods select: [ :each |
		            each literals anySatisfy: [ :literal |
			            literal isVariableBinding and: [
				            literal key = #VkDeviceQueueCreateInfo ] ] ].
	self assert: builders size >= 1.
	builders do: [ :each |
		self
			assertEmpty: (each messages select: [ :message |
					 pokes includes: message ]) ]
]

{ #category : 'tests' }
VkBindingsTest >> testEnumeratePhysicalDevices [

	| info instance devices |
	info := VkInstanceCreateInfo new.
	instance := Vk createInstance: info.
	[
		devices := Vk enumeratePhysicalDevices: instance.
		self assert: devices isNotEmpty ] ensure: [
		Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'tests - results' }
VkBindingsTest >> testEveryDeclaredResultCodeAnswersItsName [
	"Every code VkResult declares must have a name, and the name must be the declaring
	 selector's own spelling: a hand-written lookup table had drifted from the constants and
	 reported VK_SUBOPTIMAL_KHR as VK_UNKNOWN(1000001003)."

	VkResult resultCodeSelectors do: [ :selector |
		| name |
		name := VkResult nameForCode: (VkResult perform: selector).
		self deny: (name beginsWith: 'VK_UNKNOWN').
		self assert: name equals: (VkResult nameForSelector: selector) ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testEveryFeatureStructureShowsEveryFlagItDeclares [
	"The flag rows are reflected out of the declared layout, so a field added to any feature
	 structure's fieldsDesc appears in that structure's view with nothing else touched."

	VkFeatureStructure subclasses do: [ :cls |
		| instance |
		instance := cls externalInstance.
		[
		self
			assert: (instance flagRows collect: [ :row | row at: #flag ])
			equals: (cls fieldSpec fieldNames reject: [ :name |
					 instance headerFieldNames includes: name ]).
		self deny: instance flagRows isEmpty ] ensure: [
			instance getHandle free ] ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testExternalArrayAnswersContiguousZeroedViewsOfOneBlock [
	"A Vulkan array field points at a run of structures packed at the declared stride. The
	 array answers one view per element, each on its slice of a single block, so an element is
	 written through its generated accessors and the driver still reads one contiguous run. The
	 block is zeroed, because a field the caller does not write must read as null or zero."

	| elements stride |
	elements := VkDescriptorSetLayoutBinding externalArrayOf: 3.
	[
		stride := VkDescriptorSetLayoutBinding byteSize.
		self assert: elements size equals: 3.
		self
			assert: (elements second getHandle asInteger
				 - elements first getHandle asInteger)
			equals: stride.
		self
			assert: (elements third getHandle asInteger
				 - elements first getHandle asInteger)
			equals: stride * 2.
		elements do: [ :each |
			self assert: each binding equals: 0.
			self assert: each descriptorType equals: 0.
			self assert: each descriptorCount equals: 0.
			self assert: each stageFlags equals: 0.
			self assert: each pImmutableSamplers isNull ].
		elements second binding: 7.
		self assert: elements first binding equals: 0.
		self assert: elements third binding equals: 0 ] ensure: [
		elements first getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testExternalArrayOfNoElementAllocatesNothing [
	"The degenerate array: a layout with no binding, a pool with no size. No block is
	 allocated, so there is no handle to free and no address for the caller to pass; the count
	 is zero and the pointer the caller writes stays null."

	self assertEmpty: (VkDescriptorSetLayoutBinding externalArrayOf: 0)
]

{ #category : 'tests' }
VkBindingsTest >> testFeatureChainIsWalkedThroughDeclaredFields [
	"The three methods of VkContext that walk a pNext chain — linking one on, reading the types
	 off it, freeing it — go through VkBaseOutStructure's accessors rather than reading sType
	 at offset 0 and pNext at offset 8 by hand. They are found by the class they mention rather
	 than listed, and the count is asserted so a rename cannot leave nothing tested."

	| pokes reads walkers |
	pokes := #( #unsignedLongAt:put: #unsignedLongLongAt:put: #pointerAt:put:
	            #byteAt:put: #unsignedShortAt:put: #floatAt:put: ).
	reads := #( #unsignedLongAt: #unsignedLongLongAt: #pointerAt:
	            #unsignedShortAt: ).
	walkers := VkContext methods select: [ :each |
		           each literals anySatisfy: [ :literal |
			           literal isVariableBinding and: [
				           literal key = #VkBaseOutStructure ] ] ].
	self assert: walkers size >= 3.
	walkers do: [ :each |
		self
			assertEmpty: (each messages select: [ :message |
					 (pokes , reads) includes: message ]) ]
]

{ #category : 'tests' }
VkBindingsTest >> testFeatureStructsAreBuiltThroughDeclaredFields [
	"Every method of VkContext that builds a feature structure fills it through the accessors
	 uFFI generated. The structures are found by the classes they mention rather than listed,
	 and the count is asserted so a rename cannot leave nothing tested. Each flag a structure
	 declares and this project leaves off still has to be written, because the block the
	 structure sits in arrives holding whatever was there; externalInstance zeroes it, which is
	 what makes leaving a flag unwritten the same as writing it off."

	| structures pokes builders |
	structures := #( #VkPhysicalDeviceSynchronization2Features
	                 #VkPhysicalDeviceShaderFloat16Int8Features
	                 #VkPhysicalDevice16BitStorageFeatures
	                 #VkPhysicalDeviceCooperativeMatrixFeaturesKHR
	                 #VkPhysicalDeviceVulkanMemoryModelFeatures ).
	pokes := #( #unsignedLongAt:put: #unsignedLongLongAt:put: #pointerAt:put:
	            #byteAt:put: #unsignedShortAt:put: #floatAt:put: ).
	builders := VkContext methods select: [ :each |
		            each literals anySatisfy: [ :literal |
			            literal isVariableBinding and: [
				            structures includes: literal key ] ] ].
	self assert: builders size >= 4.
	builders do: [ :each |
		self
			assertEmpty: (each messages select: [ :message |
					 pokes includes: message ]) ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFeatureStructureHierarchyViewShowsOnTheAbstractClassOnly [
	"The tab explains the hierarchy, so it belongs to the abstract class. A concrete feature
	 structure answers no subclasses, and its own flags are already on its Flags tab."

	| context |
	context := StInspectionContext new.
	VkFeatureStructure inspectorFeatureStructuresContext: context.
	self assert: context isActive.
	VkFeatureStructure subclasses do: [ :each |
		context := StInspectionContext new.
		each inspectorFeatureStructuresContext: context.
		self deny: context isActive ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFeatureStructuresShareOneFlagView [
	"Every device feature structure is a chain header followed by a set of boolean flags, so
	 the flag rows, the header field names, the flag view and the constant structure type
	 live once in VkFeatureStructure. A new feature structure declares its fields and its own
	 structure type, and inherits the rest."

	| shared |
	shared := #( #flagRows #headerFieldNames #inspectorFlags:
	             #initializeConstantFields ).
	self assert: VkFeatureStructure superclass equals: VkStructure.
	shared do: [ :each |
		self assert: (VkFeatureStructure includesSelector: each) ].
	self
		assertCollection:
			(VkFeatureStructure subclasses collect: [ :each | each name asSymbol ])
		hasSameElements: #( #VkPhysicalDeviceSynchronization2Features
			 #VkPhysicalDeviceShaderFloat16Int8Features
			 #VkPhysicalDevice16BitStorageFeatures
			 #VkPhysicalDeviceCooperativeMatrixFeaturesKHR
			 #VkPhysicalDeviceVulkanMemoryModelFeatures ).
	VkFeatureStructure subclasses do: [ :cls |
		self assert: (cls class includesSelector: #structureType).
		shared do: [ :each | self deny: (cls includesSelector: each) ] ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFenceAndSemaphoreCreateInfoLayoutsMatchTheCLayout [
	"Both synchronisation primitives are created from the same shape: a chain header and one
	 word of flags, so each structure is twenty-four bytes with four bytes of tail padding to
	 the alignment the chain pointer demands."

	{
		VkFenceCreateInfo.
		VkSemaphoreCreateInfo } do: [ :each |
		self
			assert: (each layoutRows collect: [ :row | row first ]) asArray
			equals: #( #sType #pNext #flags ).
		self
			assert: (each layoutRows collect: [ :row | row second ]) asArray
			equals: #( 0 8 16 ).
		self assert: each byteSize equals: 24 ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFenceAndSemaphoreCreateInfosInitializeOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by either type. A fence may be asked for
	 signalled, so its flags belong to the caller; a semaphore's flags are reserved by Vulkan
	 and must be zero, which a fresh block already is, so nothing writes them at all."

	{
		(VkFenceCreateInfo -> VkStructureType fenceCreateInfo).
		(VkSemaphoreCreateInfo -> VkStructureType semaphoreCreateInfo) }
		do: [ :each |
			| info setters |
			info := each key externalInstance.
			[
				self assert: info sType equals: each value.
				self assert: info pNext isNull.
				self assert: info flags equals: 0 ] ensure: [
				info getHandle free ].
			setters := (each key >> #initializeConstantFields) messages
				           select: [ :selector |
				           each key includesSelector: selector ].
			self assert: setters asArray equals: #( #sType: ) ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFenceCreateFlagNamesItsOwnBits [
	"A fence asked for signalled carries one bit, and the fence's view shows it, so the class
	 that holds the bit is the class that names it. An empty mask names nothing rather than
	 printing a zero."

	self assert: (VkFenceCreateFlag includesBehavior: VkFlagConstants).
	self
		assert: (VkFenceCreateFlag nameForFlags: VkFenceCreateFlag signaledBit)
		equals: 'Signaled'.
	self assert: (VkFenceCreateFlag nameForFlags: 0) equals: ''
]

{ #category : 'tests' }
VkBindingsTest >> testFieldReportReadsEveryDeclaredStructureAndLeavesItAlone [
	"Building a field report writes nothing. That is what lets a filled in structure be
	 inspected while a driver still holds a pointer to it, and it has to hold for every
	 structure that declares a field specification rather than for the one being worked on, so
	 the next one declared is covered too. Each report also names only fields the structure
	 really has."

	| structures |
	structures := VkStructure allSubclasses select: [ :each |
		              each class includesSelector: #fieldsDesc ].
	self assert: structures size >= 2.
	structures do: [ :each |
		| instance before rows names |
		instance := each new.
		before := (1 to: each byteSize) collect: [ :i |
			          instance getHandle byteAt: i ].
		rows := instance fieldReport.
		names := each layoutRows collect: [ :row | row first asString ].
		rows do: [ :row | self assert: (names includes: row first) ].
		self
			assert: ((1 to: each byteSize) collect: [ :i |
					 instance getHandle byteAt: i ])
			equals: before ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16ClassifiesEveryKindOfHalf [
	| expected |
	expected := {
		            (16r0000 -> #zero).
		            (16r8000 -> #zero).
		            (16r0001 -> #subnormal).
		            (16r3C00 -> #normal).
		            (16r7C00 -> #infinity).
		            (16r7E00 -> #notANumber) }.
	expected do: [ :each |
		self assert: (PVFloat16 on: each key) classification equals: each value ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16DecodeInvertsEncodeForRepresentableValues [
	| values |
	values := {
		          0.0.
		          1.0.
		          -2.5.
		          0.5.
		          65504.0.
		          1.0 timesTwoPower: -14.
		          1.0 timesTwoPower: -24.
		          1023.0 timesTwoPower: -24 }.
	values do: [ :each |
		self
			assert: (PVFloat16 floatFromWord: (PVFloat16 wordForFloat: each))
			equals: each ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16EncodesTheBoundariesOfTheFormat [
	"Zero and its sign, one, the smallest normal, both ends of the subnormal range, the
	 largest finite half, and infinity. Every one of these is a boundary a naive shift-and-
	 mask encoder gets wrong."

	self assertHalfOf: 0.0 is: 16r0000.
	self assertHalfOf: 0.0 negated is: 16r8000.
	self assertHalfOf: 1.0 is: 16r3C00.
	self assertHalfOf: -2.0 is: 16rC000.
	self assertHalfOf: (1.0 timesTwoPower: -14) is: 16r0400.
	self assertHalfOf: (1.0 timesTwoPower: -24) is: 16r0001.
	self assertHalfOf: (1023.0 timesTwoPower: -24) is: 16r03FF.
	self assertHalfOf: 65504.0 is: 16r7BFF.
	self assertHalfOf: Float infinity is: 16r7C00.
	self assertHalfOf: Float infinity negated is: 16rFC00
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16FieldReportReEncodesItsOwnWord [
	"The Half tab's last row is evidence, so assert it: decode followed by encode must
	 return the word it started from, including at the subnormal and infinite ends."

	#( 16r0000 16r8000 16r0001 16r03FF 16r0400 16r3555 16r7BFF 16r7C00 16rFC00 )
		do: [ :each |
			| half |
			half := PVFloat16 on: each.
			self
				assert: (half fieldReport last at: #value)
				equals: each printStringHex ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16KeepsInfinitiesAndNotANumberApart [
	self assert: (PVFloat16 floatFromWord: 16r7C00) equals: Float infinity.
	self assert: (PVFloat16 floatFromWord: 16rFC00) equals: Float infinity negated.
	self assert: (PVFloat16 floatFromWord: 16r7E00) isNaN.
	self assert: (PVFloat16 wordForFloat: Float nan) = 16r7E00
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16NamesTheFieldsOfOneThird [
	| half |
	half := PVFloat16 exampleHalfOfOneThird.
	self assert: half word equals: 16r3555.
	self assert: half sign equals: 0.
	self assert: half biasedExponent equals: 13.
	self assert: half mantissa equals: 16r155.
	self assert: half classification equals: #normal.
	self assert: half value equals: 0.333251953125
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16RoundsTiesToEven [
	"A value exactly between two halves must go to the one with an even mantissa, in the
	 normal range and in the subnormal range alike. Truncation and round-half-up both fail
	 the first and third of these."

	self assertHalfOf: 1.0 + (1.0 timesTwoPower: -11) is: 16r3C00.
	self
		assertHalfOf: 1.0 + (1.0 timesTwoPower: -11) + (1.0 timesTwoPower: -30)
		is: 16r3C01.
	self assertHalfOf: 1.0 + (3.0 timesTwoPower: -11) is: 16r3C02.
	self assertHalfOf: (3.0 timesTwoPower: -25) is: 16r0002
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16SaturatesOutsideItsRange [
	"Above the last finite half the format has only infinity, and the tie at 65520 goes
	 there because infinity is the even neighbour. Below half the smallest subnormal there
	 is only zero, which keeps its sign."

	self assertHalfOf: 65519.0 is: 16r7BFF.
	self assertHalfOf: 65520.0 is: 16r7C00.
	self assertHalfOf: 70000.0 is: 16r7C00.
	self assertHalfOf: (1.0 timesTwoPower: -25) is: 16r0000.
	self assertHalfOf: (1.0 timesTwoPower: -25) negated is: 16r8000.
	self assertHalfOf: (3.0 timesTwoPower: -26) is: 16r0001
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFramebufferCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is all a fresh request knows. The layer count is one for every
	 framebuffer this project creates, but it is a caller's choice rather than a property of the
	 structure, so the writer writes it; stamping it here would also make a request that names
	 no attachment claim a layer."

	| info setters |
	info := VkFramebufferCreateInfo externalInstance.
	[
		self assert: info sType equals: VkStructureType framebufferCreateInfo.
		self assert: info pNext isNull.
		self assert: info flags equals: 0.
		self assert: info renderPass isNull.
		self assert: info attachmentCount equals: 0.
		self assert: info pAttachments isNull.
		self assert: info width equals: 0.
		self assert: info height equals: 0.
		self assert: info layers equals: 0 ] ensure: [ info getHandle free ].
	setters := (VkFramebufferCreateInfo >> #initializeConstantFields) messages
		           select: [ :each |
		           VkFramebufferCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFramebufferCreateInfoLayoutMatchesTheCLayout [
	"The request vkCreateFramebuffer reads: chain header, flags, the render pass whose
	 attachments it binds, the attachment views as a count and a pointer, then the extent and
	 the layer count. The three trailing words end the request at sixty bytes, which the padding
	 to the chain pointer's alignment rounds to sixty-four."

	| rows |
	rows := VkFramebufferCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #renderPass #attachmentCount #pAttachments
		           #width #height #layers ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 40 48 52 56 ).
	self assert: VkFramebufferCreateInfo byteSize equals: 64
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFramebufferCreationWritesNoScalarFieldAtAHandCountedOffset [
	"Every field of the request is declared, so no method of VkFramebuffer, on either side, may
	 poke a scalar or a pointer at a counted offset. The attachment run is still a block, so
	 pointerAt:put: is allowed in the one method that writes it and nowhere else."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put:
	             #floatAt: #floatAt:put: ).
	offenders := (VkFramebuffer methods , VkFramebuffer class methods) select: [
		             :method |
		             method messages anySatisfy: [ :each | banned includes: each ] ].
	self assertEmpty: (offenders collect: [ :each |
			 each methodClass name , ' >> ' , each selector ]).
	offenders := (VkFramebuffer methods , VkFramebuffer class methods) select: [
		             :method |
		             method messages anySatisfy: [ :each |
			             #( #pointerAt: #pointerAt:put: ) includes: each ] ].
	self
		assert: (offenders collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals:
		#( 'VkFramebuffer class >> attachmentsOutsideObjectMemory:'
		   'VkFramebuffer class >> handleForCreateInfo:on:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFramebufferRequestBindsOneAttachmentOverOneLayer [
	"The request the builder writes, with no device in reach: the render pass it binds, one
	 attachment view, the extent it covers and one layer. The attachment pointer leads to the
	 view handles, which the request's rows read back by the named stride, because a run of
	 handles has no field specification to read an offset from."

	| views info |
	views := VkFramebuffer attachmentsOutsideObjectMemory:
		         { (VkImageView_H fromHandle: ExternalAddress null) }.
	[
		info := VkFramebuffer
			        createInfoForRenderPass:
			        (VkRenderPass_H fromHandle: ExternalAddress null)
			        attachments: views
			        extent: VkImage exampleExtent.
		[
			self assert: info sType equals: VkStructureType framebufferCreateInfo.
			self assert: info flags equals: 0.
			self
				assert: info attachmentCount
				equals: VkFramebuffer attachmentsPerFramebuffer.
			self deny: info pAttachments isNull.
			self assert: info width equals: VkImage exampleExtent x.
			self assert: info height equals: VkImage exampleExtent y.
			self assert: info layers equals: VkFramebuffer layersPerFramebuffer ]
			ensure: [ info getHandle free ] ] ensure: [ views free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testFramebufferRowsNameTheExtentTheLayersAndTheAttachments [
	"What the Framebuffer tab reads: the extent as a point, the layer count, and the attachment
	 views reported as how many the request names and whether each handle in the run is set. The
	 handles are read by the named stride, so a row cannot be read off an offset counted by
	 hand, and the render pass is reported as set or not rather than as an address."

	| views rows |
	views := VkFramebuffer attachmentsOutsideObjectMemory:
		         { (VkImageView_H fromHandle: ExternalAddress null) }.
	rows := [
	        | info |
	        info := VkFramebuffer
		                createInfoForRenderPass:
		                (VkRenderPass_H fromHandle: ExternalAddress null)
		                attachments: views
		                extent: VkImage exampleExtent.
	        [ info framebufferRows ] ensure: [ info getHandle free ] ] ensure: [
	        views free ].
	self deny: (rows at: #renderPassSet).
	self assert: (rows at: #extent) equals: VkImage exampleExtent.
	self assert: (rows at: #layers) equals: VkFramebuffer layersPerFramebuffer.
	self
		assert: (rows at: #attachmentCount)
		equals: VkFramebuffer attachmentsPerFramebuffer.
	self
		assert: (rows at: #attachmentsSet)
		equals: (Array new: VkFramebuffer attachmentsPerFramebuffer withAll: false)
]

{ #category : 'tests' }
VkBindingsTest >> testGeneratorIsIdempotent [
	"Idempotency: generating an existing enum creates no new class."

	| gen desc before after |
	gen := VkBindingGenerator new.
	desc := VkEnumDescriptor new.
	desc name: 'VkResult'.
	desc values: OrderedCollection new.
	before := Smalltalk globals allClasses size.
	gen generateEnum: desc.
	after := Smalltalk globals allClasses size.
	self assert: after - before equals: 0
]

{ #category : 'tests - layout' }
VkBindingsTest >> testGraphicsSubmitCarriesAWaitAndASignalSemaphoreAtTheColourAttachmentStage [
	"The window path waits for the image to be acquired and signals that the frame is drawn, so
	 its batch carries one semaphore info on each side and one command buffer info. Both
	 semaphore infos wait at the colour attachment output stage, which is where the frame's
	 writes happen, and both leave the timeline value and the device index at zero: these are
	 binary semaphores on a single device."

	| wait signal batch |
	wait := VkQueue semaphoreSubmitInfoFor: ExternalAddress null.
	signal := VkQueue semaphoreSubmitInfoFor: ExternalAddress null.
	batch := VkQueue
		         submitInfoFor: ExternalAddress null
		         waitSemaphoreInfo: wait
		         signalSemaphoreInfo: signal.
	[
		self
			assert: wait stageMask
			equals: VkQueue graphicsSemaphoreStageMask.
		self assert: wait value equals: 0.
		self assert: wait deviceIndex equals: 0.
		self
			assert: batch waitSemaphoreInfoCount
			equals: VkQueue semaphoreInfosPerSubmit.
		self
			assert: batch signalSemaphoreInfoCount
			equals: VkQueue semaphoreInfosPerSubmit.
		self
			assert: batch commandBufferInfoCount
			equals: VkQueue commandBufferInfosPerSubmit.
		self deny: batch pWaitSemaphoreInfos isNull.
		self deny: batch pSignalSemaphoreInfos isNull ] ensure: [
		batch getHandle free.
		signal getHandle free.
		wait getHandle free ]
]

{ #category : 'tests' }
VkBindingsTest >> testHalfPrecisionFeatureStructsLayoutMatchesTheCLayout [
	"The two structures the half precision path chains together. The float16 struct carries two
	 VkBool32 flags and is twenty four bytes; the storage struct carries four and is thirty two.
	 Both are asserted here because the pair is only ever built together, and a short write in
	 either lands in the other rather than in slack."

	| float16 storage16 |
	float16 := VkPhysicalDeviceShaderFloat16Int8Features layoutRows.
	storage16 := VkPhysicalDevice16BitStorageFeatures layoutRows.
	self
		assert: (float16 collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #shaderFloat16 #shaderInt8 ).
	self
		assert: (float16 collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 ).
	self
		assert: VkPhysicalDeviceShaderFloat16Int8Features byteSize
		equals: 24.
	self
		assert: (storage16 collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #storageBuffer16BitAccess
		   #uniformAndStorageBuffer16BitAccess #storagePushConstant16
		   #storageInputOutput16 ).
	self
		assert: (storage16 collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 28 ).
	self assert: VkPhysicalDevice16BitStorageFeatures byteSize equals: 32.
	float16 , storage16 do: [ :each |
		self assert: each second \\ each third equals: 0 ].
	float16 overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ].
	storage16 overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testImageAspectNamesItsOwnBitsAndHoldsTheOnlyColourBit [
	"The copy's view shows the aspect mask, so the bits are named by a constants class. The
	 colour bit had three senders through VkRenderConfig, which is not a value table; it now
	 delegates rather than carrying a second copy of the value."

	self assert: (VkImageAspect includesBehavior: VkFlagConstants).
	self
		assert: (VkImageAspect nameForFlags:
				 VkImageAspect colorBit | VkImageAspect depthBit)
		equals: 'Color|Depth'.
	self assert: (VkImageAspect nameForFlags: 0) equals: ''.
	self
		assert: VkRenderConfig imageAspectColorBit
		equals: VkImageAspect colorBit.
	self assert:
		((VkRenderConfig class >> #imageAspectColorBit) messages includes:
			 #colorBit)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testImageCopyWritesNoScalarFieldAtAHandCountedOffset [
	"The copy region and the three structures it nests are declared, so none of the three
	 methods that build or record the copy may poke a scalar at a counted offset."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := {
		             (VkCommandBuffer -> #copyImage:layout:toBuffer:extent:).
		             (VkCommandBuffer -> #recordCopyOf:layout:toBuffer:region:).
		             (VkCommandBuffer class -> #regionForExtent:) } select: [
		             :each |
		             (each key includesSelector: each value) and: [
			             (each key >> each value) messages anySatisfy: [ :message |
				             banned includes: message ] ] ].
	self assertEmpty: offenders asArray.
	self assert:
		(VkCommandBuffer includesSelector: #recordCopyOf:layout:toBuffer:region:)
]

{ #category : 'tests - image' }
VkBindingsTest >> testImageCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type. The dimensionality, the tiling
	 and the sample count are the same for every image this project creates, but each is a
	 caller's choice rather than a property of the structure, and the extent is nested by
	 value, so an initializer writing anything else would write through to a nested store on
	 every read."

	| info setters |
	info := VkImageCreateInfo externalInstance.
	[ self assert: info sType equals: VkStructureType imageCreateInfo ] ensure: [
		info getHandle free ].
	setters := (VkImageCreateInfo >> #initializeConstantFields) messages select: [
		           :each | VkImageCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - image' }
VkBindingsTest >> testImageCreateInfoLayoutMatchesTheCLayout [
	"The request vkCreateImage reads: chain header, flags, the dimensionality, the format, the
	 extent by value, the mip and layer counts, the sample count, the tiling, the usage, the
	 sharing mode, the queue families as a count and a pointer, and the layout the image
	 starts in. uFFI pads after the count and after the layout, which rounds the request to
	 eighty-eight bytes."

	| rows |
	rows := VkImageCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #imageType #format #extent #mipLevels
		           #arrayLayers #samples #tiling #usage #sharingMode
		           #queueFamilyIndexCount #pQueueFamilyIndices #initialLayout ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 28 40 44 48 52 56 60 64 72 80 ).
	self assert: VkImageCreateInfo byteSize equals: 88.
	self
		assert: ((rows detect: [ :each | each first = #extent ]) third)
		equals: VkExtent3D byteSize
]

{ #category : 'tests - image' }
VkBindingsTest >> testImageCreationWritesNoScalarFieldAtAHandCountedOffset [
	"Both structures VkImage hands the driver are declared — the image request and the view
	 request — so no method of the class, on either side, may poke a scalar or a pointer at a
	 counted offset. Before unit 4a the two together wrote thirty-two of them. Reading a
	 handle out of an out parameter is the one exception, and only the two methods that make
	 a handle may do it."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put:
	             #floatAt: #floatAt:put: #pointerAt:put: ).
	offenders := (VkImage methods , VkImage class methods) select: [ :method |
		             method messages anySatisfy: [ :each | banned includes: each ] ].
	self assertEmpty: (offenders collect: [ :each |
			 each methodClass name , ' >> ' , each selector ]).
	offenders := (VkImage methods , VkImage class methods) select: [ :method |
		             method messages includes: #pointerAt: ].
	self
		assert: (offenders collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkImage class >> handleForCreateInfo:on:'
			           'VkImage class >> handleForViewRequest:on:' )
]

{ #category : 'tests - image' }
VkBindingsTest >> testImageRequestAsksForATwoDimensionalOptimalAttachment [
	"What the builder writes, with no device in reach, against what it leaves as the zeros a
	 fresh block holds. Optimal tiling, the exclusive sharing mode and the undefined initial
	 layout are all zero, so none of them is written; they are asserted through their
	 constant classes, so the request is still read in Vulkan's terms. The flags, the queue
	 family count and its pointer are zero because no image here is shared between
	 families."

	| info |
	info := VkImage
		        createInfoForFormat: VkFormat b8g8r8a8Unorm
		        extent: VkImage exampleExtent
		        usage: VkImageUsage colorAttachmentBit.
	[
		self assert: info sType equals: VkStructureType imageCreateInfo.
		self assert: info flags equals: 0.
		self assert: info imageType equals: VkImageType type2D.
		self assert: info format equals: VkFormat b8g8r8a8Unorm.
		self assert: info extent width equals: VkImage exampleExtent x.
		self assert: info extent height equals: VkImage exampleExtent y.
		self assert: info extent depth equals: VkImage imageDepth.
		self assert: info mipLevels equals: VkImage mipLevelCount.
		self assert: info arrayLayers equals: VkImage arrayLayerCount.
		self assert: info samples equals: VkRenderConfig sampleCount1Bit.
		self assert: info usage equals: VkImageUsage colorAttachmentBit.
		self assert: info tiling equals: VkImageTiling optimal.
		self assert: info sharingMode equals: VkRenderConfig sharingModeExclusive.
		self assert: info initialLayout equals: VkImageLayout undefined.
		self assert: info queueFamilyIndexCount equals: 0.
		self assert: info pQueueFamilyIndices isNull ] ensure: [ info getHandle free ]
]

{ #category : 'tests - image' }
VkBindingsTest >> testImageRequestRowsNameTheTypeTheTilingAndTheLayout [
	"What the Image tab reads. Every value is named through its constant class rather than
	 restated, which is why VkImageTiling and VkImageType were reparented onto
	 VkValueConstants by this unit. The extent is reported as a point and a depth, because a
	 reader cares that the image is flat. Read only, so the tab leaves the store alone."

	| info rows |
	info := VkImage
		        createInfoForFormat: VkFormat b8g8r8a8Unorm
		        extent: VkImage exampleExtent
		        usage: VkImageUsage colorAttachmentBit.
	rows := [ info imageRows ] ensure: [ info getHandle free ].
	self assert: (rows at: #imageTypeName) equals: 'type2D'.
	self assert: (rows at: #formatName) equals: 'b8g8r8a8Unorm'.
	self assert: (rows at: #tilingName) equals: 'optimal'.
	self assert: (rows at: #initialLayoutName) equals: 'undefined'.
	self assert: (rows at: #extent) equals: VkImage exampleExtent.
	self assert: (rows at: #depth) equals: VkImage imageDepth.
	self assert: (rows at: #mipLevels) equals: VkImage mipLevelCount.
	self assert: (rows at: #arrayLayers) equals: VkImage arrayLayerCount.
	self
		assert: (rows at: #usageNames)
		equals: (VkImageUsage nameForFlags: VkImageUsage colorAttachmentBit).
	self assert: (rows at: #sharedBetweenQueueFamilies) equals: false
]

{ #category : 'tests - structures' }
VkBindingsTest >> testImageViewCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is all a fresh request knows. The identity swizzle is constant for
	 every view this project asks for, but it is zero, so stamping it would write what the
	 zeroed block already holds; the nested structures must stay untouched by the initializer,
	 because a getter for a nested field runs initialize over the parent's store."

	| info setters |
	info := VkImageViewCreateInfo externalInstance.
	[
		self assert: info sType equals: VkStructureType imageViewCreateInfo.
		self assert: info pNext isNull.
		self assert: info flags equals: 0.
		self assert: info image isNull.
		self assert: info viewType equals: 0.
		self assert: info format equals: 0 ] ensure: [ info getHandle free ].
	setters := (VkImageViewCreateInfo >> #initializeConstantFields) messages
		           select: [ :each | VkImageViewCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: ).
	self deny: (VkComponentMapping includesSelector: #initializeConstantFields).
	self deny:
		(VkImageSubresourceRange includesSelector: #initializeConstantFields)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testImageViewCreateInfoLayoutMatchesTheCLayout [
	"The request vkCreateImageView reads: chain header, flags, the image the view looks at,
	 the view type and the format it reads the image as, then the swizzle by value and the
	 subresource range by value. The two nested structures end the request at seventy-six
	 bytes, which the trailing padding to the eight byte alignment of the chain pointer rounds
	 to eighty."

	| rows |
	rows := VkImageViewCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #image #viewType #format #components
		           #subresourceRange ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 36 40 56 ).
	self assert: VkImageViewCreateInfo byteSize equals: 80
]

{ #category : 'tests - structures' }
VkBindingsTest >> testImageViewCreationWritesNoScalarFieldAtAHandCountedOffset [
	"Both view paths go through the declared request, so neither the image's createView nor the
	 swapchain's createImageViews may poke a scalar or a pointer at a counted offset. The image
	 create info and the swapchain create info are still written as blocks and belong to later
	 units, so the ban names these two methods rather than their whole classes."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put:
	             #floatAt: #floatAt:put: #pointerAt: #pointerAt:put: ).
	offenders := {
		             (VkImage >> #createView).
		             (VkSwapchain >> #createImageViews) } select: [ :method |
		             method messages anySatisfy: [ :each | banned includes: each ] ].
	self assertEmpty: (offenders collect: [ :each |
			 each methodClass name , ' >> ' , each selector ])
]

{ #category : 'tests - structures' }
VkBindingsTest >> testImageViewRequestNamesTheColourAspectAndTheIdentitySwizzle [
	"The request the builder writes, with no device in reach: the view reads the image it is
	 given as a two dimensional image of the given format, over the colour aspect of one mip
	 level and one array layer. The swizzle is the identity on all four channels, which the
	 zeroed block already says, so the test asks the structure rather than the writer."

	| info |
	info := VkImage
		        viewRequestFor: (VkImage_H fromHandle: ExternalAddress null)
		        format: VkFormat b8g8r8a8Unorm.
	[
		self assert: info sType equals: VkStructureType imageViewCreateInfo.
		self assert: info viewType equals: VkRenderConfig imageViewType2D.
		self assert: info format equals: VkFormat b8g8r8a8Unorm.
		self assert: info flags equals: 0.
		self
			assert: {
					info components r.
					info components g.
					info components b.
					info components a }
			equals: (Array new: 4 withAll: VkComponentSwizzle identity).
		self
			assert: info subresourceRange aspectMask
			equals: VkImageAspect colorBit.
		self assert: info subresourceRange baseMipLevel equals: 0.
		self
			assert: info subresourceRange levelCount
			equals: VkImage mipLevelCount.
		self assert: info subresourceRange baseArrayLayer equals: 0.
		self
			assert: info subresourceRange layerCount
			equals: VkImage arrayLayerCount ] ensure: [ info getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testInstanceCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"Only sType is constant for an instance create info: the counts and the name arrays are
	 whatever the caller asks for. A field written in initialization is written again on every
	 fromHandle: read of the structure, which would clear a count the driver was meant to see.
	 The degenerate state needs no writing at all, because a fresh store is zeroed."

	| info setters |
	info := VkInstanceCreateInfo new.
	self assert: info sType equals: VkStructureType instanceCreateInfo.
	self assert: info flags equals: 0.
	self assert: info enabledLayerCount equals: 0.
	self assert: info ppEnabledLayerNames getHandle isNull.
	self assert: info enabledExtensionCount equals: 0.
	self assert: info ppEnabledExtensionNames getHandle isNull.
	setters := (VkInstanceCreateInfo >> #initializeConstantFields) messages
		           select: [ :each |
		           VkInstanceCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests' }
VkBindingsTest >> testLayoutRowsReportEveryPointerFieldAsOnePointerWide [
	"A pointer field occupies a pointer, not the thing it points at. FFIExternalStructureType
	 answers the pointed to structure's size for externalTypeSize, so layoutRows has to ask
	 isPointer first; before it did, VkWriteDescriptorSet reported pBufferInfo as twenty four
	 bytes wide and running over pTexelBufferView. Stated over every structure in the image
	 that declares a field specification, so the next one declared is covered too: no field may
	 run past the end of its struct, and no field may run into the next one."

	| structures |
	structures := VkStructure allSubclasses select: [ :each |
		              each class includesSelector: #fieldsDesc ].
	self assert: structures size >= 2.
	structures do: [ :each |
		| rows |
		rows := each layoutRows.
		rows do: [ :row |
			self assert: row second + row third <= each byteSize ].
		rows overlappingPairsDo: [ :a :b |
			self assert: a second + a third <= b second ] ]
]

{ #category : 'tests' }
VkBindingsTest >> testLibraryLoads [
    | lib |
    lib := VkLibrary uniqueInstance.
    self assert: lib isNotNil
]

{ #category : 'tests - structures' }
VkBindingsTest >> testMemoryAllocateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field a fresh allocation request can know: the size and the
	 memory type index come from the requirements the driver answers."

	| info setters |
	info := VkMemoryAllocateInfo externalInstance.
	[
		self assert: info sType equals: VkStructureType memoryAllocateInfo.
		self assert: info pNext isNull.
		self assert: info allocationSize equals: 0.
		self assert: info memoryTypeIndex equals: 0 ] ensure: [
		info getHandle free ].
	setters := (VkMemoryAllocateInfo >> #initializeConstantFields) messages
		           select: [ :each | VkMemoryAllocateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testMemoryAllocateInfoLayoutMatchesTheCLayout [
	"VkMemoryAllocateInfo is declared field by field. allocationSize is a VkDeviceSize, eight
	 bytes wide and eight byte aligned, so the memory type index sits at twenty four and the
	 structure is padded out to thirty two bytes."

	| rows |
	rows := VkMemoryAllocateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #allocationSize #memoryTypeIndex ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 ).
	self assert: VkMemoryAllocateInfo byteSize equals: 32.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testMemoryAllocateInfoWriterRowsNameItsOneWriterAndTheFieldsItFills [
	"The Writers tab reflects over the system for the methods that fill this structure, rather
	 than naming them in a list that could go stale, and reports which declared fields each one
	 sets. One writer, both fields."

	| rows |
	rows := VkMemoryAllocateInfo writerRows.
	self
		assert: (rows collect: [ :each | each at: #method ]) asArray
		equals: #( 'VkDevice >> allocateMemoryFor:properties:' ).
	self
		assert: (rows first at: #fields)
		equals: 'allocationSize, memoryTypeIndex'
]

{ #category : 'tests - structures' }
VkBindingsTest >> testMemoryBarrier2LayoutMatchesTheCLayout [
	"Synchronization2 widened the stage and access masks to sixty-four bits, so the four masks
	 are eight bytes each and follow the chain header with no padding: forty-eight bytes."

	| rows |
	rows := VkMemoryBarrier2 layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #srcStageMask #srcAccessMask #dstStageMask
		           #dstAccessMask ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 40 ).
	self assert: VkMemoryBarrier2 byteSize equals: 48
]

{ #category : 'tests - structures' }
VkBindingsTest >> testMemoryRequirementsLayoutMatchesTheCLayout [
	"VkMemoryRequirements has no chain header: the driver writes all three fields. Two
	 VkDeviceSize values then a bitmask, padded out to twenty four bytes."

	| rows |
	rows := VkMemoryRequirements layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #size #alignment #memoryTypeBits ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 ).
	self assert: VkMemoryRequirements byteSize equals: 24
]

{ #category : 'tests - structures' }
VkBindingsTest >> testMemoryRequirementsWritesNothingOfItsOwn [
	"The driver fills a memory requirements block and this project only reads it, so the class
	 must declare no constant field: an initializer would write over the driver's answer every
	 time the block is read through fromHandle:."

	self deny: (VkMemoryRequirements includesSelector: #initializeConstantFields).
	self
		assert: (VkMemoryRequirements lookupSelector: #initializeConstantFields) methodClass
		equals: VkStructure
]

{ #category : 'tests - structures' }
VkBindingsTest >> testNestedCopyStructureLayoutsMatchTheCLayout [
	"The three structures the copy region nests are plain value structures: no chain header, no
	 padding, four words for the subresource and three for each of the offset and the extent."

	{
		(VkImageSubresourceLayers
		 -> #( #aspectMask #mipLevel #baseArrayLayer #layerCount )).
		(VkOffset3D -> #( #x #y #z )).
		(VkExtent3D -> #( #width #height #depth )) } do: [ :each |
		| rows |
		rows := each key layoutRows.
		self
			assert: (rows collect: [ :row | row first ]) asArray
			equals: each value.
		self
			assert: (rows collect: [ :row | row second ]) asArray
			equals: ((1 to: each value size) collect: [ :i | (i - 1) * 4 ]) asArray.
		self assert: each key byteSize equals: each value size * 4 ]
]

{ #category : 'tests' }
VkBindingsTest >> testNestedPropertiesNameReadsThroughTheOuterStore [
	"deviceNameString read the store directly, which only works where the structure owns it.
	 Nested in a query structure the handle is a reference into the outer store, so the name has
	 to be read through the generated accessor instead. The bytes are written where the driver
	 would write them, at the offsets uFFI compiled. The zero byte ends the name, and a name
	 filling the whole field, which carries no terminator, must still read back whole."

	| query base name fieldSize |
	query := VkPhysicalDeviceProperties2 new.
	base := (self offsetOf: #properties in: VkPhysicalDeviceProperties2)
	        + (self offsetOf: #deviceName in: VkPhysicalDeviceProperties).
	name := 'Probe'.
	1 to: name size do: [ :i |
		query getHandle at: base + i put: (name at: i) asciiValue ].
	self assert: query properties deviceNameString equals: name.
	fieldSize := query properties deviceName size.
	1 to: fieldSize do: [ :i |
		query getHandle at: base + i put: $A asciiValue ].
	self
		assert: query properties deviceNameString
		equals: (String new: fieldSize withAll: $A)
]

{ #category : 'tests' }
VkBindingsTest >> testNumberHalfConversionsAnswerWhatTheDeviceWouldAnswer [
	"The kernel DSL sends asF16 and asF32. The host answers must be the rounding the device
	 performs, so that running a half kernel's body on the host is a check on the kernel and
	 not a different calculation."

	{
		0.0.
		1.0.
		-2.5.
		65504.0.
		(1 / 3).
		(1.0 timesTwoPower: -24) } do: [ :each |
		self
			assert: each asF16
			equals: (PVFloat16 floatFromWord: (PVFloat16 wordForFloat: each)).
		self assert: each asF32 equals: each asFloat ].
	self assert: 3 asF32 equals: 3.0.
	self assert: Float infinity asF16 equals: Float infinity
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodAllocatesCommandBuffers [
	"Every command buffer in the project comes from a pool, so the allocate info has one writer.
	 The senders are asked of the system, and the tests are rejected: a test naming the call is
	 itself a sender."

	| writers |
	writers := (SystemNavigation default allSendersOf:
		            #allocateCommandBuffers:allocateInfo:commandBuffers:)
		           reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (writers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkCommandPool >> handleForAllocateInfo:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodAllocatesDeviceMemory [
	"Buffers and images need the same four steps to get memory: ask the driver what the
	 resource demands, pick a memory type that satisfies it and has the properties wanted, call
	 vkAllocateMemory, bind. The allocation step is written once, on the device that owns the
	 memory, so the allocate info has one writer and cannot drift between the two resources.
	 Test classes are dropped from the senders: this test names the selector itself, as the
	 literal it asks about."

	| senders |
	senders := ((SystemNavigation default allSendersOf:
		             #allocateMemory:allocateInfo:allocator:memory:) reject: [ :each |
		            each methodClass includesBehavior: TestCase ]) collect: [ :each |
		           each methodClass name , ' >> ' , each selector ].
	self
		assert: senders asArray
		equals: #( 'VkDevice >> allocateMemoryFor:properties:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodBeginsACommandBuffer [
	"Every recording in the project opens through the one method that writes the begin info.
	 The senders are asked of the system, and the tests are rejected: a test naming the call is
	 itself a sender."

	| writers |
	writers := (SystemNavigation default allSendersOf:
		            #beginCommandBuffer:beginInfo:) reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (writers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkCommandBuffer >> beginRecordingWith:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodBeginsARenderPass [
	"Every pass in the project opens through the one method that hands the begin info to the
	 driver. The senders are asked of the system, and the tests are rejected: a test naming the
	 call is itself a sender."

	| writers |
	writers := (SystemNavigation default allSendersOf:
		            #cmdBeginRenderPass:pRenderPassBegin:contents:) reject: [
		           :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (writers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkCommandBuffer >> recordRenderPassBeginWith:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodCopiesAnImageToABuffer [
	"Every image readback in the project records through the one method that hands the region to
	 the driver. The senders are asked of the system, and the tests are rejected: a test naming
	 the call is itself a sender."

	| writers |
	writers := (SystemNavigation default allSendersOf:
		            #cmdCopyImageToBuffer:srcImage:srcImageLayout:dstBuffer:regionCount:pRegions:)
		           reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (writers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkCommandBuffer >> recordCopyOf:layout:toBuffer:region:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodCreatesACommandPool [
	"The create info used to be written twice, once by the pool class and once by the device,
	 with the same four offsets and the same flag counted out by hand in both. The device now
	 delegates, so the call has one sender outside the tests. The senders are asked of the
	 system, and the tests are rejected: a test naming the call is itself a sender."

	| writers |
	writers := (SystemNavigation default allSendersOf:
		            #createCommandPool:createInfo:allocator:poolOut:) reject: [
		           :each | each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (writers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkCommandPool class >> handleForCreateInfo:on:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodCreatesAFenceAndOneASemaphore [
	"Each create info has one writer: the wrapper of the primitive it creates. The senders are
	 asked of the system, and the tests are rejected: a test naming the call is itself a
	 sender."

	{
		(#createFence:createInfo:allocator:pFence:
		 -> 'VkFenceWrapper >> handleForCreateInfo:').
		(#createSemaphore:createInfo:allocator:pSemaphore:
		 -> 'VkSemaphoreWrapper >> handleForCreateInfo:') } do: [ :each |
		| writers |
		writers := (SystemNavigation default allSendersOf: each key) reject: [
			           :sender |
			           sender methodClass instanceSide includesBehavior:
				           TestCase ].
		self
			assert: (writers collect: [ :sender |
					 sender methodClass name , ' >> ' , sender selector ]) asArray
			equals: { each value } ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodCreatesAFramebuffer [
	"One writer of the request and one caller of the creation, as for the image view. The tests
	 are rejected from the senders: a test naming the call is itself a sender."

	| callers writers |
	callers := (SystemNavigation default allSendersOf:
		            #createFramebuffer:createInfo:allocator:pFramebuffer:) reject: [
		           :each | each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (callers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkFramebuffer class >> handleForCreateInfo:on:' ).
	writers := VkFramebufferCreateInfo writerRows collect: [ :each |
		           each at: #method ].
	self
		assert: writers asArray
		equals:
		#( 'VkFramebuffer class >> createInfoForRenderPass:attachments:extent:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodCreatesARenderPassAndWritesEachOfItsStructures [
	"Four structures, one writer each, and one caller of the creation. Both pass variants share
	 the same builders: the final layout is the only thing that differs between them. The tests
	 are rejected from the senders: a test naming the call is itself a sender."

	| callers writerOf |
	callers := (SystemNavigation default allSendersOf:
		            #createRenderPass:createInfo:allocator:pRenderPass:) reject: [
		           :each | each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (callers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkRenderPass class >> handleForCreateInfo:on:' ).
	writerOf := [ :structureClass |
	            (structureClass writerRows collect: [ :each | each at: #method ])
		            asArray ].
	self
		assert: (writerOf value: VkAttachmentDescription)
		equals:
		#( 'VkRenderPass class >> attachmentDescriptionForFormat:finalLayout:' ).
	self
		assert: (writerOf value: VkAttachmentReference)
		equals: #( 'VkRenderPass class >> colorAttachmentReference' ).
	self
		assert: (writerOf value: VkSubpassDescription)
		equals: #( 'VkRenderPass class >> subpassDescriptionReading:' ).
	self
		assert: (writerOf value: VkRenderPassCreateInfo)
		equals: #( 'VkRenderPass class >> createInfoForAttachment:subpass:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodCreatesAShaderModule [
	"Two places ask for a shader module — a device and a compute kernel — and both go through
	 VkShaderModule, so the create info has exactly one writer. The senders are asked of the
	 system rather than listed, and the tests are rejected: a test naming the call is itself a
	 sender of the selector."

	| writers |
	writers := (SystemNavigation default allSendersOf:
		            #createShaderModule:createInfo:allocator:shaderModuleOut:)
		           reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (writers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkShaderModule >> handleForCreateInfo:' )
]

{ #category : 'tests - image' }
VkBindingsTest >> testOnlyOneMethodCreatesAnImage [
	"One builder, one caller of the creation, and the request is written nowhere else. The
	 tests are rejected from the senders: a test naming the call is itself a sender."

	| callers |
	callers := (SystemNavigation default allSendersOf:
		            #createImage:createInfo:allocator:pImage:) reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (callers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkImage class >> handleForCreateInfo:on:' ).
	self
		assert: (VkImageCreateInfo writerRows collect: [ :each | each at: #method ])
				asArray
		equals: #( 'VkImage class >> createInfoForFormat:extent:usage:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodCreatesAnImageView [
	"The offscreen image and every swapchain image are viewed through the same request, so one
	 method writes it and one method hands it to the driver. Before this unit the request was
	 written out twice, once here and once in the swapchain, and the two copies had to be kept
	 in step by hand. The tests are rejected from the senders: a test naming the call is itself
	 a sender."

	| callers writers |
	callers := (SystemNavigation default allSendersOf:
		            #createImageView:createInfo:allocator:pView:) reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (callers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkImage class >> handleForViewRequest:on:' ).
	writers := VkImageViewCreateInfo writerRows collect: [ :each |
		           each at: #method ].
	self
		assert: writers asArray
		equals: #( 'VkImage class >> viewRequestFor:format:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testOnlyOneMethodRecordsAPipelineBarrier [
	"Every barrier the project records goes through the one method that writes the dependency
	 info. The senders are asked of the system, and the tests are rejected: a test naming the
	 call is itself a sender."

	| writers |
	writers := (SystemNavigation default allSendersOf:
		            #cmdPipelineBarrier2:pDependencyInfo:) reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (writers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkCommandBuffer >> recordBarrier:' )
]

{ #category : 'tests - layout' }
VkBindingsTest >> testOnlyOneMethodSetsTheViewportAndOneSetsTheScissor [
	"Both dynamic state commands are recorded in one place each, so the structure each hands
	 the driver has one writer. The senders are asked of the system, and the tests are
	 rejected: a test naming the call is itself a sender."

	| expected |
	expected := {
		            (#cmdSetViewport:firstViewport:viewportCount:pViewports:
		             -> 'VkCommandBuffer >> recordViewport:').
		            (#cmdSetScissor:firstScissor:scissorCount:pScissors:
		             -> 'VkCommandBuffer >> recordScissor:') }.
	expected do: [ :each |
		| writers |
		writers := (SystemNavigation default allSendersOf: each key) reject: [
			           :sender |
			           sender methodClass instanceSide includesBehavior: TestCase ].
		self
			assert: (writers collect: [ :sender |
					 sender methodClass name , ' >> ' , sender selector ]) asArray
			equals: { each value } ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testOnlyOneMethodSubmitsToAQueue [
	"Both submit paths hand their batch to the driver through one method, so the batch has one
	 writer and one reader. The senders are asked of the system, and the tests are rejected: a
	 test naming the call is itself a sender."

	| submitters |
	submitters := (SystemNavigation default allSendersOf:
		               #queueSubmit2:submitCount:submits:fence:) reject: [ :each |
		              each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (submitters collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
		equals: #( 'VkQueue >> submitBatch:fence:' )
]

{ #category : 'tests - result codes' }
VkBindingsTest >> testOutOfPoolMemoryIsADeclaredResultCode [
	"Observed on this device: allocating a set out of a pool built for zero sets answers
	 -1000069000, which printed as VK_UNKNOWN because the code was never declared. A code the
	 driver here really returns must name itself."
	self
		assert: (VkResult nameForCode: VkResult vkErrorOutOfPoolMemory)
		equals: (VkResult nameForSelector: #vkErrorOutOfPoolMemory).
	self assert: (VkResult withCode: VkResult vkErrorOutOfPoolMemory) isError
]

{ #category : 'tests - render pass' }
VkBindingsTest >> testPassRequestRowsNameTheLoadStoreAndLayoutsOfTheAttachment [
	"What the two tabs read. The attachment's rows name its format, its load and store
	 operations and the layouts it enters and leaves through their constant classes, so a tab
	 cannot restate a value the structure does not hold. The request's rows count the
	 attachments, the subpasses and the dependencies, and report each pointer as set or not
	 rather than following it, which is why a request pointing at nothing can be asked at
	 all."

	| description reference subpass rows |
	description := VkRenderPass
		               attachmentDescriptionForFormat: VkFormat b8g8r8a8Unorm
		               finalLayout: VkImageLayout transferSrcOptimal.
	rows := [ description attachmentRows ] ensure: [
	        description getHandle free ].
	self assert: (rows at: #formatName) equals: 'b8g8r8a8Unorm'.
	self assert: (rows at: #loadOpName) equals: 'loadClear'.
	self assert: (rows at: #storeOpName) equals: 'storeStore'.
	self assert: (rows at: #initialLayoutName) equals: 'undefined'.
	self assert: (rows at: #finalLayoutName) equals: 'transferSrcOptimal'.
	self deny: (rows at: #usesStencil).
	reference := VkRenderPass colorAttachmentReference.
	rows := [
	        subpass := VkRenderPass subpassDescriptionReading: reference.
	        [ | info |
	        info := VkRenderPass
		                createInfoForAttachment:
		                (VkAttachmentDescription fromHandle: ExternalAddress null)
		                subpass: subpass.
	        [ info passRequestRows ] ensure: [ info getHandle free ] ] ensure: [
		        subpass getHandle free ] ] ensure: [ reference getHandle free ].
	self assert: (rows at: #attachmentCount) equals: VkRenderPass attachmentsPerPass.
	self deny: (rows at: #attachmentsSet).
	self assert: (rows at: #subpassCount) equals: VkRenderPass subpassesPerPass.
	self assert: (rows at: #subpassesSet).
	self assert: (rows at: #dependencyCount) equals: 0.
	self deny: (rows at: #dependenciesSet)
]

{ #category : 'tests - layout' }
VkBindingsTest >> testPassRowsNameTheClearColourTheAreaAndTheContents [
	"The Pass tab reads its rows off the begin info itself, including the clear colour behind the
	 pointer, read by the named stride the writer used. The subpass contents are not a field of
	 the structure, so the row asks the class that names the choice."

	| values rows |
	values := VkCommandBuffer clearValuesOutsideObjectMemory:
		          #( 0.0 0.25 0.5 1.0 ).
	rows := [
	        | info |
	        info := VkCommandBuffer
		                renderPassBeginInfoFor:
		                (VkRenderPass_H fromHandle: ExternalAddress null)
		                framebuffer:
		                (VkFramebuffer_H fromHandle: ExternalAddress null)
		                extent: 3 @ 2
		                clearValues: values.
	        [ info passRows ] ensure: [ info getHandle free ] ] ensure: [
		        values free ].
	self assert: (rows at: #renderArea) equals: 3 @ 2.
	self assert: (rows at: #renderAreaOffset) equals: 0 @ 0.
	self assert: (rows at: #clearValueCount) equals: 1.
	self assert: (rows at: #clearColor) equals: #( 0.0 0.25 0.5 1.0 ).
	self assert: (rows at: #subpassContentsName) equals: 'inline'.
	self deny: (rows at: #renderPassSet).
	self deny: (rows at: #framebufferSet)
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDeviceLimitsFillsTheLimitsFieldExactly [
	"The limits block is read through its own structure rather than as a byte blob, so every
	 limit's offset comes from the compiled field specification instead of a hand counted byte
	 count. The facts to state are that the structure is exactly as long as the field holding
	 it, and that the field starts on an eight byte boundary: limits holds VkDeviceSize members,
	 so a missing pad moves it and moves every limit inside it."

	| limitsRow |
	limitsRow := VkPhysicalDeviceProperties layoutRows detect: [ :each |
		             each first = #limits ].
	self assert: limitsRow third equals: VkPhysicalDeviceLimits byteSize.
	self assert: limitsRow second \\ 8 equals: 0
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDeviceLimitsRowsReadTheirOwnAccessors [
	"The Limits view prints one row per member by performing the generated accessor, so a row
	 cannot show a value the structure does not hold. An array member must read as its elements
	 rather than as an opaque FFIArray, which is the degenerate case of the same rule."

	| limits |
	limits := VkPhysicalDeviceLimits new.
	limits maxComputeSharedMemorySize: 48 * 1024.
	self
		assert: (limits printableValueOf: #maxComputeSharedMemorySize)
		equals: (48 * 1024) printString.
	self
		assert: (limits printableValueOf: #maxComputeWorkGroupSize)
		equals: #( 0 0 0 ) printString
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDeviceProperties [
    | info instance devices props name |
    info := VkInstanceCreateInfo new.
    instance := Vk createInstance: info.
    [ devices := Vk enumeratePhysicalDevices: instance.
      props := VkPhysicalDeviceProperties new.
      Vk getPhysicalDeviceProperties: (devices at: 1) into: props.
      name := props deviceNameString.
      self assert: (name isKindOf: String).
      self assert: name isNotEmpty ]
    ensure: [ Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDevicePropertiesFieldHeadReadsTheStore [
	"The layout view prints the first bytes of each field. It must read them from the store the
	 instance really holds, and it must mark a field whose bytes it had to cut, otherwise a row
	 could read as if the field were as short as the text shown."

	| props store |
	props := VkPhysicalDeviceProperties new.
	store := props getHandle.
	1 to: store size do: [ :i | store at: i put: i \\ 256 ].
	self assert: (props headOfFieldAt: 0 size: 4) equals: '01 02 03 04'.
	self
		assert: (props headOfFieldAt: 0 size: VkPhysicalDeviceProperties byteSize)
		equals: '01 02 03 04 05 06 07 08 ...'
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDevicePropertiesHoldsEverythingTheDriverWrites [
	"The struct keeps its bytes in a ByteArray inside object memory, so a declaration shorter
	 than what the driver writes overruns that object and corrupts whatever follows it in the
	 heap. The span is measured from the driver rather than taken from the specification, and
	 the byte comparison pins the field offsets as well as the size: the C layout aligns limits
	 to eight bytes, so a missing pad shifts everything from limits onward."

	| info instance devices device written props |
	info := VkInstanceCreateInfo new.
	instance := Vk createInstance: info.
	[
	devices := Vk enumeratePhysicalDevices: instance.
	device := devices at: 1.
	written := (self spanWrittenByDevicePropertiesOf: device sentinel: 16rAB)
		           max: (self spanWrittenByDevicePropertiesOf: device sentinel: 16r5C).
	self assert: written > 0.
	self assert: VkPhysicalDeviceProperties byteSize >= written.
	props := VkPhysicalDeviceProperties new.
	Vk getPhysicalDeviceProperties: device into: props.
	self
		assert: ((props getHandle first: written) collect: [ :each | each ]) asArray
		equals: (((self spanBytesWrittenByDevicePropertiesOf: device) first: written) collect: [ :each | each ]) asArray ]
		ensure: [ Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDevicePropertiesLayoutTilesItsWholeStore [
	"The layout the inspector shows is read back from the field specification the class really
	 compiled. The fact to state is that the fields tile the store with no hole and no overlap:
	 the first starts at zero, each one begins where the previous ends, and the last ends at the
	 declared size. An alignment pad removed or put in the wrong place breaks one of the three."

	| rows |
	rows := VkPhysicalDeviceProperties layoutRows.
	self assert: rows first second equals: 0.
	rows overlappingPairsDo: [ :a :b | self assert: b second equals: a second + a third ].
	self
		assert: rows last second + rows last third
		equals: VkPhysicalDeviceProperties byteSize
]

{ #category : 'tests' }
VkBindingsTest >> testQueueFlagsConstants [
    "VkQueueFlags must expose named bit constants."
    self assert: VkQueueFlags graphicsBit equals: 1.
    self assert: VkQueueFlags computeBit equals: 2.
    self assert: VkQueueFlags transferBit equals: 4
]

{ #category : 'tests - layout' }
VkBindingsTest >> testQueueSubmitWritesNoScalarFieldAtAHandCountedOffset [
	"All three submit structures are declared, so none of the methods that build a batch or
	 hand it to the driver may poke a scalar at a counted offset. The pointer pokes are banned
	 here as well: a count-and-pointer pair written by hand is what this unit replaced."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #pointerAt: #pointerAt:put:
	             #signedLongAt: #signedLongAt:put: ).
	offenders := {
		             (VkQueue -> #submit:andWait:).
		             (VkQueue
		              -> #submitGraphics:waitSemaphore:signalSemaphore:fence:).
		             (VkQueue -> #submitBatch:fence:).
		             (VkQueue class -> #commandBufferSubmitInfoFor:).
		             (VkQueue class -> #semaphoreSubmitInfoFor:).
		             (VkQueue class
		              -> #submitInfoFor:waitSemaphoreInfo:signalSemaphoreInfo:) }
			            select: [ :each |
			            (each key includesSelector: each value) and: [
				            (each key >> each value) messages anySatisfy: [ :message |
					            banned includes: message ] ] ].
	self assertEmpty: offenders asArray.
	self assert: (VkQueue includesSelector: #submitBatch:fence:)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRect2DLayoutsMatchTheCLayout [
	"A rectangle is an offset and an extent carried by value, two words each, so sixteen bytes
	 with nothing padded. The same three classes serve the scissor rectangle."

	self
		assert: (VkRect2D layoutRows collect: [ :each |
				 each first -> each second ]) asArray
		equals: {
				(#offset -> 0).
				(#extent -> 8) }.
	self assert: VkRect2D byteSize equals: 16.
	{
		(VkOffset2D -> #( #x #y )).
		(VkExtent2D -> #( #width #height )) } do: [ :each |
		| rows |
		rows := each key layoutRows.
		self
			assert: (rows collect: [ :row | row first ]) asArray
			equals: each value.
		self
			assert: (rows collect: [ :row | row second ]) asArray
			equals: #( 0 4 ).
		self assert: each key byteSize equals: 8 ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testRectRowsReportTheOffsetAndTheExtentOfAnyRectangle [
	"A rectangle serves both the scissor and the render pass's render area, so its rows belong
	 to the rectangle and say nothing about which of the two it is. A rectangle covering a
	 target from its origin clips nothing, which the rows state as a fact about the offset
	 rather than as a claim about the caller."

	| scissor rows |
	scissor := VkCommandBuffer scissorForExtent: 3 @ 2.
	rows := [ scissor rectRows ] ensure: [ scissor getHandle free ].
	self assert: (rows at: #extent) equals: 3 @ 2.
	self assert: (rows at: #offset) equals: 0 @ 0.
	self assert: (rows at: #atTheOrigin)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassBeginInfoCarriesTheExtentAndOneClearValue [
	"The begin info the recorder builds: the render area starts at the image's corner and covers
	 the whole extent, and one clear value is listed. The builder takes handles rather than
	 wrappers, so the degenerate case — a null render pass and a null framebuffer — is one the
	 test can build, and it still has to carry the area and the count."

	| values info extent |
	extent := 3 @ 2.
	values := VkCommandBuffer clearValuesOutsideObjectMemory:
		          VkRenderConfig clearColorBlackOpaque.
	[
		info := VkCommandBuffer
			        renderPassBeginInfoFor: (VkRenderPass_H fromHandle: ExternalAddress null)
			        framebuffer: (VkFramebuffer_H fromHandle: ExternalAddress null)
			        extent: extent
			        clearValues: values.
		[
		self assert: info renderArea offset x equals: 0.
		self assert: info renderArea offset y equals: 0.
		self assert: info renderArea extent width equals: extent x.
		self assert: info renderArea extent height equals: extent y.
		self
			assert: info clearValueCount
			equals: VkCommandBuffer clearValuesPerPass.
		self deny: info pClearValues isNull ] ensure: [ info getHandle free ] ]
		ensure: [ values free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassBeginInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type: both handles, the render area, the
	 clear value count and the pointer to the values are the recorder's."

	| info setters |
	info := VkRenderPassBeginInfo externalInstance.
	[
		self
			assert: info sType
			equals: VkStructureType renderPassBeginInfo.
		self assert: info pNext isNull.
		self assert: info clearValueCount equals: 0.
		self assert: info pClearValues isNull ] ensure: [
		info getHandle free ].
	setters := (VkRenderPassBeginInfo >> #initializeConstantFields) messages
		           select: [ :selector |
		           VkRenderPassBeginInfo includesSelector: selector ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassBeginInfoLayoutMatchesTheCLayout [
	"Two handles follow the chain header, then the render area by value — sixteen bytes of it —
	 then the clear value count and the pointer to the values, which is eight byte aligned, so
	 four bytes of padding sit after the count."

	| rows |
	rows := VkRenderPassBeginInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #renderPass #framebuffer #renderArea
		           #clearValueCount #pClearValues ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 48 56 ).
	self
		assert: (rows collect: [ :each | each third ]) asArray
		equals: #( 4 8 8 8 16 4 8 ).
	self assert: VkRenderPassBeginInfo byteSize equals: 64
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassBeginWritesNoScalarFieldAtAHandCountedOffset [
	"The begin info and its render area are declared, so none of the four methods that build or
	 record a pass may poke a scalar at a counted offset. The clear values are not a structure
	 and are written by a named stride, which is why floatAt:put: is not banned here."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := {
		             (VkCommandBuffer
		              -> #beginRenderPass:framebuffer:extent:clearColor:).
		             (VkCommandBuffer -> #recordRenderPassBeginWith:).
		             (VkCommandBuffer class
		              -> #renderPassBeginInfoFor:framebuffer:extent:clearValues:).
		             (VkCommandBuffer class
		              -> #clearValuesOutsideObjectMemory:) } select: [ :each |
		             (each key includesSelector: each value) and: [
			             (each key >> each value) messages anySatisfy: [ :message |
				             banned includes: message ] ] ].
	self assertEmpty: offenders asArray.
	self assert:
		(VkCommandBuffer includesSelector: #recordRenderPassBeginWith:)
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassCreateInfoLayoutMatchesTheCLayout [
	"The request vkCreateRenderPass reads: chain header, flags, then a count and a pointer for
	 the attachments, the subpasses and the subpass dependencies. uFFI pads after the flags and
	 after each count, so the request is sixty-four bytes."

	| rows |
	rows := VkRenderPassCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #attachmentCount #pAttachments #subpassCount
		           #pSubpasses #dependencyCount #pDependencies ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 40 48 56 ).
	self assert: VkRenderPassCreateInfo byteSize equals: 64
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassCreationWritesNoScalarFieldAtAHandCountedOffset [
	"All four structures the render pass hands the driver are declared, so no method of the
	 class, on either side, may poke a scalar or a pointer at a counted offset. Before this unit
	 one method wrote thirty-one of them."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put:
	             #floatAt: #floatAt:put: #pointerAt:put: ).
	offenders := (VkRenderPass methods , VkRenderPass class methods) select: [
		             :method |
		             method messages anySatisfy: [ :each | banned includes: each ] ].
	self assertEmpty: (offenders collect: [ :each |
			 each methodClass name , ' >> ' , each selector ]).
	offenders := (VkRenderPass methods , VkRenderPass class methods) select: [
		             :method | method messages includes: #pointerAt: ].
	self
		assert: (offenders collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkRenderPass class >> handleForCreateInfo:on:' )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassRequestNamesOneAttachmentOneSubpassAndNoDependency [
	"The request itself: one attachment, one subpass, no dependency. The dependency count and
	 pointer are the zeros a fresh block holds, which is what a pass with a single subpass
	 needs: there is nothing for a dependency to order."

	| description reference subpass info |
	description := VkRenderPass
		               attachmentDescriptionForFormat: VkFormat b8g8r8a8Unorm
		               finalLayout: VkImageLayout presentSrcKHR.
	[
		reference := VkRenderPass colorAttachmentReference.
		[
			subpass := VkRenderPass subpassDescriptionReading: reference.
			[
				info := VkRenderPass
					        createInfoForAttachment: description
					        subpass: subpass.
				[
					self
						assert: info sType
						equals: VkStructureType renderPassCreateInfo.
					self assert: info flags equals: 0.
					self
						assert: info attachmentCount
						equals: VkRenderPass attachmentsPerPass.
					self deny: info pAttachments isNull.
					self assert: info subpassCount equals: VkRenderPass subpassesPerPass.
					self deny: info pSubpasses isNull.
					self assert: info dependencyCount equals: 0.
					self assert: info pDependencies isNull ] ensure: [
					info getHandle free ] ] ensure: [ subpass getHandle free ] ]
			ensure: [ reference getHandle free ] ] ensure: [
		description getHandle free ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testRenderPassStructuresInitializeOnlyWhatIsConstantForTheirType [
	"Only the request has a structure type to stamp. The three descriptions carry no chain
	 header at all — the driver reads them in place — so none of them may have an initializer:
	 each is pointed at from a structure whose getter would otherwise write through the
	 pointer."

	| info setters |
	info := VkRenderPassCreateInfo externalInstance.
	[ self assert: info sType equals: VkStructureType renderPassCreateInfo ]
		ensure: [ info getHandle free ].
	setters := (VkRenderPassCreateInfo >> #initializeConstantFields) messages
		           select: [ :each |
		           VkRenderPassCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: ).
	#( #VkAttachmentDescription #VkAttachmentReference #VkSubpassDescription )
		do: [ :name |
			self deny:
				((Smalltalk at: name) includesSelector: #initializeConstantFields).
			self deny: ((Smalltalk at: name) includesSelector: #sType:) ]
]

{ #category : 'tests - results' }
VkBindingsTest >> testResultCodesViewMarksTheInspectedCodeAndNothingElse [
	"The view has to carry every declared code, mark exactly the one being inspected, and leave
	 that code untouched."

	| result view marked |
	result := VkResult exampleSuboptimalPresentResult.
	view := result inspectorResultCodes: SpPresenter new.
	self assert: view items size equals: VkResult resultCodeSelectors size.
	marked := view items select: [ :each | each code = result code ].
	self assert: marked size equals: 1.
	self assert: marked first name equals: 'VK_SUBOPTIMAL_KHR'.
	self deny: result isError.
	self assert: result code equals: VkResult vkSuboptimalKHR
]

{ #category : 'tests - layout' }
VkBindingsTest >> testScissorCoversTheWholeTarget [
	"The scissor the recorder builds clips nothing: it is the whole target from its origin, so
	 only the extent is written and the offset is the zero a fresh block holds. The rectangle
	 is the same declared class the render pass uses for its render area."

	| scissor extent |
	extent := 3 @ 2.
	scissor := VkCommandBuffer scissorForExtent: extent.
	[
		self assert: scissor extent width equals: extent x.
		self assert: scissor extent height equals: extent y.
		self assert: scissor offset x equals: 0.
		self assert: scissor offset y equals: 0 ] ensure: [
		scissor getHandle free ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSemaphoreAndCommandBufferSubmitInfoLayoutsMatchTheCLayout [
	"A semaphore submit info is forty-eight bytes at 0, 8, 16, 24, 32 and 40: synchronization2
	 widened the stage mask to sixty-four bits and the timeline value beside it is sixty-four
	 bits as well, so both are quad words and the device index at the end is padded to the
	 structure's alignment. A command buffer submit info is thirty-two bytes at 0, 8, 16 and
	 24, padded the same way after its device mask."

	self
		assert: (VkSemaphoreSubmitInfo layoutRows collect: [ :each |
				 each first -> each second ]) asArray
		equals: {
				(#sType -> 0).
				(#pNext -> 8).
				(#semaphore -> 16).
				(#value -> 24).
				(#stageMask -> 32).
				(#deviceIndex -> 40) }.
	self assert: VkSemaphoreSubmitInfo byteSize equals: 48.
	self
		assert: (VkCommandBufferSubmitInfo layoutRows collect: [ :each |
				 each first -> each second ]) asArray
		equals: {
				(#sType -> 0).
				(#pNext -> 8).
				(#commandBuffer -> 16).
				(#deviceMask -> 24) }.
	self assert: VkCommandBufferSubmitInfo byteSize equals: 32
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSemaphoreSubmitRowsNameTheStageAndTheSubmitFlagsNameTheirOwnBit [
	"The Semaphore tab names the stage mask through the class that owns the stage bits, so the
	 row cannot drift from the mask the builder writes. The submit flags have one bit in
	 Vulkan, the protected submit, which this project never asks for: a zero mask decodes to
	 the empty name and the bit itself still decodes to its name."

	| info rows |
	info := VkQueue semaphoreSubmitInfoFor: ExternalAddress null.
	rows := [ info semaphoreSubmitRows ] ensure: [ info getHandle free ].
	self assert: (rows at: #stageNames) equals: 'ColorAttachmentOutput'.
	self assert: (rows at: #value) equals: 0.
	self assert: (rows at: #deviceIndex) equals: 0.
	self deny: (rows at: #semaphoreSet).
	self assert: (VkSubmitFlag nameForFlags: 0) equals: ''.
	self
		assert: (VkSubmitFlag nameForFlags: VkSubmitFlag protectedBit)
		equals: 'Protected'
]

{ #category : 'tests - structures' }
VkBindingsTest >> testShaderModuleCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type: the byte count and the pointer
	 describe one module's code, so a fresh block reads as no code at all."

	| info setters |
	info := VkShaderModuleCreateInfo externalInstance.
	[
		self
			assert: info sType
			equals: VkStructureType shaderModuleCreateInfo.
		self assert: info pNext isNull.
		self assert: info flags equals: 0.
		self assert: info codeSize equals: 0.
		self assert: info pCode isNull ] ensure: [ info getHandle free ].
	setters := (VkShaderModuleCreateInfo >> #initializeConstantFields)
		           messages select: [ :each |
		           VkShaderModuleCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - structures' }
VkBindingsTest >> testShaderModuleCreateInfoLayoutMatchesTheCLayout [
	"The chain header, the flags, then a size_t byte count and a pointer to the words. The
	 count is eight bytes and eight byte aligned, so four bytes of padding follow flags and
	 the structure is forty bytes."

	| rows |
	rows := VkShaderModuleCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #codeSize #pCode ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 ).
	self assert: VkShaderModuleCreateInfo byteSize equals: 40
]

{ #category : 'tests - structures' }
VkBindingsTest >> testShaderModuleWithNoCodeReportsZeroBytes [
	"The degenerate module, which is what the example answers on a machine with no device: no
	 code, no handle. The Module tab is opened on it, so the byte count reads as zero rather
	 than as nil, and zero bytes is a whole number of words."

	| rows |
	rows := VkShaderModule new moduleRows.
	self assert: (rows at: #bytes) equals: 0.
	self assert: (rows at: #words) equals: 0.
	self assert: (rows at: #wholeWords).
	self deny: (rows at: #live)
]

{ #category : 'tests' }
VkBindingsTest >> testStorageBufferUpdateWritesThroughDeclaredFields [
	"The buffer info and the write are filled through the accessors uFFI generated from their
	 field specifications, so no method of VkDescriptorSet pokes a raw offset into a block of
	 bytes. The methods are found by the classes they mention rather than listed, so splitting
	 one further keeps the rule enforced, and the count is asserted so a rename cannot leave
	 nothing tested."

	| structures builders pokes |
	structures := #( #VkDescriptorBufferInfo #VkWriteDescriptorSet ).
	pokes := #( #unsignedLongAt:put: #unsignedLongLongAt:put: #pointerAt:put:
	            #byteAt:put: #unsignedShortAt:put: ).
	builders := VkDescriptorSet methods select: [ :each |
		            each literals anySatisfy: [ :literal |
			            literal isVariableBinding and: [
				            structures includes: literal key ] ] ].
	self assert: builders size >= 2.
	builders do: [ :each |
		self
			assertEmpty: (each messages select: [ :message |
					 pokes includes: message ]) ]
]

{ #category : 'tests' }
VkBindingsTest >> testStructPointerFieldReadLeavesThePointeeAlone [
	"Reading a field that points at another structure must not write through that pointer.
	 uFFI's generated getter answers the pointed to structure through fromHandle:, and
	 FFIStructure class >> fromHandle: sends initialize, so a structure whose initialize writes
	 a data field rewrote the pointee on every read — a buffer info holding a real range came
	 back holding VK_WHOLE_SIZE — and the same read over a null pointer failed in the FFI
	 primitive. Both are stated here: the pointee keeps its own range, and a pointer nobody has
	 set reads as null rather than raising."

	| info write someRange |
	someRange := VkDescriptorPool exampleElementCount * 4.
	info := VkDescriptorBufferInfo externalInstance
		        range: someRange;
		        yourself.
	write := VkWriteDescriptorSet externalInstance
		         pBufferInfo: info;
		         yourself.
	[
	self assert: write pBufferInfo getHandle equals: info getHandle.
	self assert: info range equals: someRange.
	self assert: VkWriteDescriptorSet new pBufferInfo isNull ] ensure: [
		write getHandle free.
		info getHandle free ]
]

{ #category : 'tests' }
VkBindingsTest >> testStructureCopyIntoObjectMemoryDetachesFromItsSource [
	"A structure the driver filled in memory outside the image has to be copied before that
	 memory is freed. The copy must hold the same bytes, keep a store of its own so a later
	 write to the source cannot reach it, and drop a pNext that would otherwise point into
	 memory already given back."

	| address source copy |
	address := ExternalAddress allocate: VkPhysicalDeviceSubgroupProperties byteSize.
	[
	source := VkPhysicalDeviceSubgroupProperties fromHandle: address.
	1 to: VkPhysicalDeviceSubgroupProperties byteSize do: [ :i |
		address byteAt: i put: 0 ].
	source subgroupSize: 32.
	source pNext: address.
	copy := source copyIntoObjectMemory.
	self assert: copy subgroupSize equals: 32.
	self assert: copy pNext isNull.
	source subgroupSize: 64.
	self assert: copy subgroupSize equals: 32 ] ensure: [ address free ]
]

{ #category : 'tests' }
VkBindingsTest >> testStructureTypeConstants [
    "VkStructureType must expose named constants — no magic numbers."
    self assert: VkStructureType applicationInfo equals: 0.
    self assert: VkStructureType instanceCreateInfo equals: 1
]

{ #category : 'tests - structures' }
VkBindingsTest >> testStructureWritersTabShowsOnlyWhereFieldsAreDeclared [
	"The Writers tab answers a question about declared fields, so it shows on a structure that
	 declares some and stays away from the abstract classes, which declare none."

	| activeFor |
	activeFor := [ :cls |
	              | context |
	              context := StInspectionContext new.
	              (VkStructure class >> #inspectorWritersContext:)
		              valueWithReceiver: cls
		              arguments: { context }.
	              context isActive ].
	self assert: (activeFor value: VkMemoryAllocateInfo).
	self assert: (activeFor value: VkMemoryRequirements).
	self deny: (activeFor value: VkStructure).
	self deny: (activeFor value: VkFeatureStructure)
]

{ #category : 'tests' }
VkBindingsTest >> testSubgroupFeaturePredicateMatchesTheOperationBits [
	"VkPhysicalDevice and the Features view read supportedOperations through one predicate. The
	 device only ever reports the mask it has, so the two degenerate masks are stated here: an
	 empty one supports nothing, and one carrying every named bit supports all of them."

	| block everyBit supported |
	block := VkPhysicalDeviceSubgroupProperties new.
	everyBit := VkSubgroupFeature featureSelectors
		            inject: 0
		            into: [ :mask :each |
			            mask bitOr: (VkSubgroupFeature perform: each) ].
	supported := [ VkSubgroupFeature featureSelectors select: [ :each |
		           block supportsFeature: (VkSubgroupFeature perform: each) ] ].
	self assert: supported value isEmpty.
	block supportedOperations: everyBit.
	self assert: supported value equals: VkSubgroupFeature featureSelectors
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSubmitInfo2LayoutMatchesTheCLayout [
	"The submit batch is sixty-four bytes at 0, 8, 16, 20, 24, 32, 40, 48 and 56: three
	 count-and-pointer pairs, one per kind of info it carries, after the chain header and the
	 flags. Each count is one word and each pointer is eight byte aligned, so uFFI pads after
	 the second and the third count."

	| rows |
	rows := VkSubmitInfo2 layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #waitSemaphoreInfoCount
		           #pWaitSemaphoreInfos #commandBufferInfoCount
		           #pCommandBufferInfos #signalSemaphoreInfoCount
		           #pSignalSemaphoreInfos ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 40 48 56 ).
	self assert: VkSubmitInfo2 byteSize equals: 64
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSubmitRowsCountTheInfosAndSayWhichPointersAreSet [
	"The Batch tab reads its rows off the submit info itself: the three counts and, for each
	 kind of info, whether the pointer beside the count is set. The rows report the pointers as
	 set or not rather than following them, because a batch is freed as soon as the driver has
	 read it and a row that followed a freed pointer would be reading freed memory."

	| wait batch rows |
	wait := VkQueue semaphoreSubmitInfoFor: ExternalAddress null.
	batch := VkQueue
		         submitInfoFor: ExternalAddress null
		         waitSemaphoreInfo: wait
		         signalSemaphoreInfo: nil.
	rows := [ batch submitRows ] ensure: [
		        batch getHandle free.
		        wait getHandle free ].
	self assert: (rows at: #commandBufferInfoCount) equals: 1.
	self assert: (rows at: #waitSemaphoreInfoCount) equals: 1.
	self assert: (rows at: #signalSemaphoreInfoCount) equals: 0.
	self assert: (rows at: #waitSemaphoreInfosSet).
	self deny: (rows at: #signalSemaphoreInfosSet).
	self assert: (rows at: #flagNames) equals: ''
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSubmitStructuresInitializeOnlyWhatIsConstantForTheirType [
	"Each of the three submit structures carries a chain header, so each fixes its own
	 structure type and nothing else: every count, every pointer and every mask is the zero a
	 fresh block already holds."

	{
		(VkSubmitInfo2 -> VkStructureType submitInfo2).
		(VkSemaphoreSubmitInfo -> VkStructureType semaphoreSubmitInfo).
		(VkCommandBufferSubmitInfo
		 -> VkStructureType commandBufferSubmitInfo) } do: [ :each |
		| info |
		info := each key externalInstance.
		[
			self assert: info sType equals: each value.
			self assert: info pNext isNull ] ensure: [ info getHandle free ] ].
	{
		(VkSubmitInfo2 -> #( #flags #waitSemaphoreInfoCount
		    #commandBufferInfoCount #signalSemaphoreInfoCount )).
		(VkSemaphoreSubmitInfo -> #( #value #stageMask #deviceIndex )).
		(VkCommandBufferSubmitInfo -> #( #deviceMask )) } do: [ :each |
		| info |
		info := each key externalInstance.
		[
		each value do: [ :field |
			self assert: (info perform: field) equals: 0 ] ] ensure: [
			info getHandle free ] ]
]

{ #category : 'tests - results' }
VkBindingsTest >> testSuboptimalPresentIsNotTreatedAsAFailure [
	"VK_SUBOPTIMAL_KHR says the swapchain still works but no longer matches the surface
	 perfectly, which the specification lists among the success codes: an acquire or a present
	 that answers it has done its job. Raising there turned a compositor resize into a test
	 error during G-6."

	| suboptimal |
	suboptimal := VkResult withCode: VkResult vkSuboptimalKHR.
	self deny: suboptimal isError.
	self
		shouldnt: [
			Vk
				checkResult: VkResult vkSuboptimalKHR
				acceptable: { VkResult vkSuboptimalKHR } ]
		raise: VkError.
	self
		should: [
			Vk
				checkResult: VkResult vkErrorDeviceLost
				acceptable: { VkResult vkSuboptimalKHR } ]
		raise: VkError
]

{ #category : 'tests - structures' }
VkBindingsTest >> testSubpassContentsNamesItsOwnValues [
	"The pass view shows which kind of contents the subpass is recorded with, so the values are
	 named by a constants class rather than by a literal zero at the call."

	self assert: (VkSubpassContents includesBehavior: VkValueConstants).
	self
		assert: (VkSubpassContents nameForValue: VkSubpassContents inline)
		equals: 'inline'.
	self
		assert: (VkSubpassContents nameForValue:
				 VkSubpassContents secondaryCommandBuffers)
		equals: 'secondaryCommandBuffers'.
	self
		assert: VkCommandBuffer subpassContents
		equals: VkSubpassContents inline
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSurfaceCapabilitiesRowsNameTheTransformsTheAlphaAndTheUsage [
	"What the Surface tab reads. The masks are decoded through their constant classes rather
	 than restated, and the image count the project would ask for is asked of VkSwapchain
	 itself, so the tab cannot disagree with what creation does. A maximum of zero is reported
	 as unlimited rather than as no images allowed. Read only, so the tab leaves the store
	 alone."

	| capabilities rows |
	capabilities := VkSurfaceCapabilitiesKHR
		                exampleCapabilitiesAWindowSurfaceMightReport.
	rows := capabilities surfaceRows.
	self
		assert: (rows at: #minImageCount)
		equals: VkSurfaceCapabilitiesKHR exampleMinImageCount.
	self assert: (rows at: #maxImageCountIsUnlimited).
	self
		assert: (rows at: #swapchainImageCount)
		equals: (VkSwapchain imageCountFor: capabilities).
	self assert: (rows at: #currentExtent) equals: VkImage exampleExtent.
	self assert: (rows at: #maxImageArrayLayers) equals: VkImage arrayLayerCount.
	self assert: (rows at: #currentTransformName) equals: 'Identity'.
	self assert: (rows at: #supportedTransformNames) equals: 'Identity'.
	self assert: (rows at: #supportedCompositeAlphaNames) equals: 'Opaque'.
	self
		assert: (rows at: #supportedUsageNames)
		equals: (VkImageUsage nameForFlags: VkImageUsage colorAttachmentBit).
	capabilities maxImageCount: capabilities minImageCount.
	self deny: (capabilities surfaceRows at: #maxImageCountIsUnlimited)
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSurfaceFormatChoicePrefersTheFormatTheProjectRendersIn [
	"The choice is a function of what the surface offered, so it is tested without a surface.
	 The format the shaders and the render pass are written for is taken when the surface
	 offers it, whatever position it is in; otherwise the first format offered is taken,
	 because a surface always offers at least one and refusing to present is worse than
	 presenting in another format. A surface that offered nothing has nothing to choose."

	| offered other |
	offered := VkSurfaceFormatKHR exampleFormatAWindowSurfaceMightReport.
	other := VkSurfaceFormatKHR new.
	other
		format: VkFormat r32g32b32Sfloat;
		colorSpace: VkColorSpace srgbNonlinearKHR.
	self
		assert: (VkSurface formatPreferredFrom: { other. offered }) format
		equals: VkSurface formatRenderedIn.
	self
		assert: (VkSurface formatPreferredFrom: { other }) format
		equals: other format.
	self assert: (VkSurface formatPreferredFrom: #(  )) isNil
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSurfaceFormatRowsNameTheFormatAndTheColourSpace [
	"What the Format tab reads. Whether this is the pair the project renders in is asked of
	 VkSurface, which is what the choice itself asks, so the tab cannot name a preference the
	 choice stopped making. A format no constant names is shown as its number rather than
	 dropped."

	| surfaceFormat rows |
	surfaceFormat := VkSurfaceFormatKHR exampleFormatAWindowSurfaceMightReport.
	rows := surfaceFormat formatRows.
	self assert: (rows at: #formatName) equals: 'b8g8r8a8Unorm'.
	self assert: (rows at: #colorSpaceName) equals: 'srgbNonlinearKHR'.
	self assert: (rows at: #rendersThisProject).
	surfaceFormat format: VkFormat r32g32Sfloat.
	rows := surfaceFormat formatRows.
	self deny: (rows at: #rendersThisProject).
	surfaceFormat format: 0 - 1.
	self assert: (surfaceFormat formatRows at: #formatName) equals: '-1'
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSurfaceQueriesReadNoFieldAtAHandCountedOffset [
	"Both structures the surface queries answer are declared, so no method of VkSurface, on
	 either side, may read a field at a counted offset. The two scalar out parameters are the
	 exception and are named: a count and a boolean the driver writes into a four byte block
	 are not structure fields and carry no field specification to read a width from. The
	 swapchain still writes its own request by hand; that is the next unit."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put:
	             #floatAt: #floatAt:put: #pointerAt: #pointerAt:put: ).
	offenders := (VkSurface methods , VkSurface class methods) select: [
		             :method |
		             method messages anySatisfy: [ :each |
			             banned includes: each ] ].
	self
		assert: (offenders collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkSurface >> formatCountInto:' 'VkSurface >> supportsPresentation:' )
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSurfaceQueryLayoutsMatchTheCLayout [
	"The two structures the surface queries answer. The capabilities carry three VkExtent2D by
	 value, so a layout that reported a pointer width for them would put every field after the
	 first extent in the wrong place. Neither structure has a chain header: the driver fills
	 them, so there is nothing for an application to extend."

	| rows |
	rows := VkSurfaceCapabilitiesKHR layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #minImageCount #maxImageCount #currentExtent #minImageExtent
		           #maxImageExtent #maxImageArrayLayers #supportedTransforms
		           #currentTransform #supportedCompositeAlpha #supportedUsageFlags ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 16 24 32 36 40 44 48 ).
	self assert: VkSurfaceCapabilitiesKHR byteSize equals: 52.
	(rows select: [ :each | each first endsWith: 'Extent' ]) do: [ :each |
		self assert: each third equals: VkExtent2D byteSize ].
	rows := VkSurfaceFormatKHR layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #format #colorSpace ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 4 ).
	self assert: VkSurfaceFormatKHR byteSize equals: 8
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSurfaceQueryStructuresInitializeNothing [
	"A structure the driver fills carries no chain header, so it has nothing that is constant
	 for its type and must not declare an initializer at all: VkStructure runs
	 initializeConstantFields on every read of a nested field, and both of these are read as
	 copies of a block the driver wrote."

	self deny: (VkSurfaceCapabilitiesKHR includesSelector: #initializeConstantFields).
	self deny: (VkSurfaceFormatKHR includesSelector: #initializeConstantFields).
	self deny: (VkSurfaceCapabilitiesKHR canUnderstand: #sType).
	self deny: (VkSurfaceFormatKHR canUnderstand: #sType)
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSwapchainImageCountAsksForOneMoreThanTheSurfaceDemands [
	"One image more than the surface demands, so a frame can be drawn while another is
	 presented, and never more than the surface allows. A maximum of zero means the surface
	 sets no maximum, and the degenerate reading of that — clamping to zero images — would
	 ask for a swapchain with nothing in it."

	| capabilities |
	capabilities := VkSurfaceCapabilitiesKHR
		                exampleCapabilitiesAWindowSurfaceMightReport.
	self
		assert: (VkSwapchain imageCountFor: capabilities)
		equals:
		VkSurfaceCapabilitiesKHR exampleMinImageCount
		+ VkSwapchain imagesBeyondMinimum.
	capabilities maxImageCount: capabilities minImageCount.
	self
		assert: (VkSwapchain imageCountFor: capabilities)
		equals: capabilities minImageCount.
	capabilities maxImageCount: VkSwapchain unlimitedImageCount.
	capabilities minImageCount: 1.
	self
		assert: (VkSwapchain imageCountFor: capabilities)
		equals: 1 + VkSwapchain imagesBeyondMinimum
]

{ #category : 'tests - structures' }
VkBindingsTest >> testSynchronisationPrimitivesWriteNoScalarFieldAtAHandCountedOffset [
	"Both create infos are declared, so no method of either wrapper, on either side, may poke a
	 scalar at a counted offset. The handle arrays the wait and reset calls pass are written
	 with pointerAt:put:, which is not a structure write and is not banned."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := ({
		              VkFenceWrapper.
		              VkFenceWrapper class.
		              VkSemaphoreWrapper.
		              VkSemaphoreWrapper class } flatCollect: [ :each |
		              each methods ]) select: [ :each |
		             each messages anySatisfy: [ :message |
			             banned includes: message ] ].
	self
		assertEmpty: (offenders collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asArray
]

{ #category : 'tests' }
VkBindingsTest >> testSynchronization2FeaturesLayoutMatchesTheCLayout [
	"VkPhysicalDeviceSynchronization2Features is declared field by field. Its one feature flag
	 is a VkBool32 in the four bytes after pNext, and the struct is padded to twenty four so an
	 array of them would keep its pointer alignment."

	| rows |
	rows := VkPhysicalDeviceSynchronization2Features layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #synchronization2 ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 ).
	self
		assert: VkPhysicalDeviceSynchronization2Features byteSize
		equals: 24.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testUncreatedFenceAndSemaphoreReportThemselvesNotLive [
	"The examples answer an uncreated primitive on a machine with no device, so the rows must
	 open on one: an unsignalled fence with no flags, a semaphore with the reserved flags the
	 structure declares, and nothing live."

	| fenceRows semaphoreRows |
	fenceRows := VkFenceWrapper new fenceRows.
	self assert: (fenceRows at: #flags) equals: 0.
	self assert: (fenceRows at: #flagNames) equals: ''.
	self deny: (fenceRows at: #signalledAtCreation).
	self deny: (fenceRows at: #live).
	semaphoreRows := VkSemaphoreWrapper new semaphoreRows.
	self assert: (semaphoreRows at: #reservedFlags) equals: 0.
	self deny: (semaphoreRows at: #live)
]

{ #category : 'tests - constants' }
VkBindingsTest >> testValueConstantsNameEveryConstantTheyDeclare [
	"The reverse lookup is reflective and shared, so for every class that inherits it, and
	 for every constant that class declares, it must answer a name carrying that same value,
	 and nothing for a value no constant carries. Reflecting over the subclasses rather than
	 naming them keeps a class added later covered without editing this test."

	| classes |
	classes := VkValueConstants subclasses.
	self deny: classes isEmpty.
	classes do: [ :each |
		| names |
		names := each constantSelectors.
		self deny: names isEmpty.
		names do: [ :selector |
			| value |
			value := each perform: selector.
			self
				assert: (each perform: (each nameForValue: value))
				equals: value ].
		self assert: (each nameForValue: -1) isNil ]
]

{ #category : 'tests - structures' }
VkBindingsTest >> testViewRowsNameTheFormatTheAspectAndTheSwizzle [
	"What the View tab reads: the format and the swizzle under the names their constant classes
	 carry, the aspect bits decoded, the mip and layer runs as intervals, and the image
	 reported as set or not rather than as an address. The request the tab is built for has no
	 image, so the row says so."

	| rows |
	rows := (VkImage
		         viewRequestFor: (VkImage_H fromHandle: ExternalAddress null)
		         format: VkFormat b8g8r8a8Unorm) ifNotNil: [ :info |
		        [ info viewRows ] ensure: [ info getHandle free ] ].
	self deny: (rows at: #imageSet).
	self assert: (rows at: #formatName) equals: 'b8g8r8a8Unorm'.
	self assert: (rows at: #aspectNames) equals: 'Color'.
	self assert: (rows at: #mipLevels) equals: (0 to: VkImage mipLevelCount - 1).
	self
		assert: (rows at: #arrayLayers)
		equals: (0 to: VkImage arrayLayerCount - 1).
	self assert: (rows at: #swizzleNames) equals: 'identity, identity, identity, identity'.
	self assert: (rows at: #identitySwizzle)
]

{ #category : 'tests - layout' }
VkBindingsTest >> testViewportAndScissorWriteNoScalarFieldAtAHandCountedOffset [
	"The viewport and the rectangle are declared, so none of the methods that build or record
	 either dynamic state may poke a scalar or a float at a counted offset. The float pokes are
	 banned here as well, because a viewport is six floats and counting them out was exactly
	 what this unit replaced."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #floatAt: #floatAt:put:
	             #signedLongAt: #signedLongAt:put: ).
	offenders := {
		             (VkCommandBuffer -> #setViewport:).
		             (VkCommandBuffer -> #setScissor:).
		             (VkCommandBuffer -> #recordViewport:).
		             (VkCommandBuffer -> #recordScissor:).
		             (VkCommandBuffer class -> #viewportForExtent:).
		             (VkCommandBuffer class -> #scissorForExtent:) } select: [
		             :each |
		             (each key includesSelector: each value) and: [
			             (each key >> each value) messages anySatisfy: [ :message |
				             banned includes: message ] ] ].
	self assertEmpty: offenders asArray.
	self assert: (VkCommandBuffer includesSelector: #recordViewport:).
	self assert: (VkCommandBuffer includesSelector: #recordScissor:)
]

{ #category : 'tests - layout' }
VkBindingsTest >> testViewportCoversTheTargetAtTheFullDepthRange [
	"The viewport the recorder builds for an extent covers the whole target from its origin and
	 maps the whole depth range. The origin and the near plane are the zeros a fresh block
	 already holds, so only the size and the far plane are written."

	| viewport extent |
	extent := 3 @ 2.
	viewport := VkCommandBuffer viewportForExtent: extent.
	[
		self assert: viewport width equals: extent x.
		self assert: viewport height equals: extent y.
		self
			assert: viewport maxDepth
			equals: VkCommandBuffer viewportMaxDepth.
		self assert: viewport x equals: 0.0.
		self assert: viewport y equals: 0.0.
		self assert: viewport minDepth equals: 0.0 ] ensure: [
		viewport getHandle free ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testViewportFixesNoFieldByItsType [
	"A viewport carries no chain header, so no field is fixed by the type and the class
	 overrides nothing. A fresh block is a viewport of no size at a depth range of zero to
	 zero, which draws nothing: every field a caller means is written."

	| viewport |
	self deny: (VkViewport includesSelector: #initializeConstantFields).
	viewport := VkViewport externalInstance.
	[
		self assert: viewport x equals: 0.0.
		self assert: viewport width equals: 0.0.
		self assert: viewport maxDepth equals: 0.0 ] ensure: [
		viewport getHandle free ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testViewportLayoutMatchesTheCLayout [
	"A viewport is six floats at four byte stride with no padding anywhere: the origin, the
	 size and the depth range the rasteriser maps z into."

	| rows |
	rows := VkViewport layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #x #y #width #height #minDepth #maxDepth ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 12 16 20 ).
	self
		assert: (rows collect: [ :each | each third ]) asArray
		equals: #( 4 4 4 4 4 4 ).
	self assert: VkViewport byteSize equals: 24
]

{ #category : 'tests - layout' }
VkBindingsTest >> testViewportRowsNameTheDepthRangeAndTheExtent [
	"The Viewport tab reads its rows off the viewport itself, so it cannot claim an origin, a
	 size or a depth range the structure stopped carrying. The depth range is reported as the
	 pair the rasteriser maps z into, and a viewport that covers its target from the origin
	 says so in words rather than leaving a reader two zeros to interpret."

	| viewport rows |
	viewport := VkCommandBuffer viewportForExtent: 3 @ 2.
	rows := [ viewport viewportRows ] ensure: [ viewport getHandle free ].
	self assert: (rows at: #extent) equals: 3 @ 2.
	self assert: (rows at: #origin) equals: 0 @ 0.
	self assert: (rows at: #atTheOrigin).
	self assert: (rows at: #depthRange) equals: 0.0 -> 1.0
]

{ #category : 'tests' }
VkBindingsTest >> testVkApplicationInfoSType [
    "VkApplicationInfo initialize must set sType to applicationInfo."
    | info |
    info := VkApplicationInfo new.
    self assert: info sType equals: VkStructureType applicationInfo
]

{ #category : 'tests - structures' }
VkBindingsTest >> testVkBufferWritesNoScalarFieldAtAHandCountedOffset [
	"Every structure VkBuffer builds or reads is declared, so no method of the class may poke a
	 scalar at a counted offset. The pointer and byte accessors stay allowed: mapping a buffer
	 and copying bytes through it is what they are for."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := (VkBuffer methods select: [ :method |
		              method messages anySatisfy: [ :each |
			              banned includes: each ] ]) collect: [ :method |
		             method selector ].
	self assertEmpty: offenders
]

{ #category : 'tests - structures' }
VkBindingsTest >> testVkContextWritesNoScalarFieldAtAHandCountedOffset [
	"Every scalar a Vulkan structure carries is a declared field, so a method that writes one
	 at an offset it counted itself is writing outside a declaration. The pointer, float and
	 byte accessors stay allowed: an array of C strings, of priorities or of handles has no
	 field specification and is walked by a named stride."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := (VkContext methods select: [ :method |
		              method messages anySatisfy: [ :each |
			              banned includes: each ] ]) collect: [ :method |
		             method selector ].
	self assertEmpty: offenders
]

{ #category : 'tests - structures' }
VkBindingsTest >> testVkDescriptorSetLayoutWritesNoScalarFieldAtAHandCountedOffset [
	"Every structure this class hands the driver — the binding array and the layout create
	 info — is declared, so no method of the class may poke a scalar at a counted offset. The
	 ban covers the whole class, not a chosen few methods: nothing here writes an undeclared
	 structure any more."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := VkDescriptorSetLayout methods select: [ :each |
		             each messages anySatisfy: [ :message |
			             banned includes: message ] ].
	self
		assertEmpty: (offenders collect: [ :each | each selector ]) asArray
]

{ #category : 'tests' }
VkBindingsTest >> testVkHandleIsNull [
    "A freshly created VkHandle with no backing pointer must report isNull."
    | h |
    h := VkHandle new.
    self assert: h isNull
]

{ #category : 'tests - structures' }
VkBindingsTest >> testVkImageAllocatesMemoryWithNoScalarFieldAtAHandCountedOffset [
	"The memory half of VkImage goes through declared structures, so neither allocate nor the
	 methods it sends on the image may poke a scalar at a counted offset. The ban is on these
	 methods rather than on the whole class: VkImage >> create still writes the image create
	 info as a block, and that structure belongs to a later unit. The view request is declared,
	 and testImageViewCreationWritesNoScalarFieldAtAHandCountedOffset holds createView to the
	 same ban."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := (#( #allocate #memoryRequirements ) select: [ :selector |
		              (VkImage includesSelector: selector) and: [
			              (VkImage >> selector) messages anySatisfy: [ :each |
				              banned includes: each ] ] ]).
	self assertEmpty: offenders.
	self assert: (VkImage includesSelector: #memoryRequirements)
]

{ #category : 'tests' }
VkBindingsTest >> testVkInstanceCreateInfoSType [
    "VkInstanceCreateInfo initialize must set sType to instanceCreateInfo."
    | info |
    info := VkInstanceCreateInfo new.
    self assert: info sType equals: VkStructureType instanceCreateInfo
]

{ #category : 'tests' }
VkBindingsTest >> testVkQueueFamilyNotCompute [
    "supportsCompute must return false when only graphicsBit is set."
    | props |
    props := VkQueueFamilyProperties new.
    props queueFlags: VkQueueFlags graphicsBit.
    self deny: props supportsCompute
]

{ #category : 'tests' }
VkBindingsTest >> testVkQueueFamilySupportsCompute [
    "supportsCompute must return true when computeBit is set."
    | props |
    props := VkQueueFamilyProperties new.
    props queueFlags: VkQueueFlags computeBit.
    self assert: props supportsCompute
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultError [
    "Negative VkResult codes must be errors."
    | r |
    r := VkResult withCode: -1.
    self deny: r isSuccess.
    self assert: r isError.
    self assert: r name equals: 'VK_ERROR_OUT_OF_HOST_MEMORY'
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultNameForUnknownCode [
    "Unknown codes get a fallback name that includes the code value."
    | r |
    r := VkResult withCode: 99999.
    self assert: (r name beginsWith: 'VK_UNKNOWN')
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultSignals [
    "VkResult signal must raise VkError for error codes."
    | r |
    r := VkResult withCode: -1.
    self should: [ r signal ] raise: VkError
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultSuccess [
    "VkResult withCode: 0 must be a success result."
    | r |
    r := VkResult withCode: 0.
    self assert: r isSuccess.
    self deny: r isError.
    self assert: r name equals: 'VK_SUCCESS'
]

{ #category : 'tests - structures' }
VkBindingsTest >> testVkShaderModuleWritesNoScalarFieldAtAHandCountedOffset [
	"The one structure this class hands the driver is declared, so no method of the class may
	 poke a scalar at a counted offset. Copying the code into memory outside the image is not
	 a structure write and goes through byteAt:put:, which is not banned."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put: ).
	offenders := VkShaderModule methods select: [ :each |
		             each messages anySatisfy: [ :message |
			             banned includes: message ] ].
	self
		assertEmpty: (offenders collect: [ :each | each selector ]) asArray
]

{ #category : 'tests' }
VkBindingsTest >> testWriteDescriptorSetCarriesItsOwnStructureType [
	"initialize names the structure type and clears the chain pointer, and fromHandle: sends
	 it, so an instance from externalInstance is as ready as one from new. The degenerate state
	 is the one that matters: descriptorCount left at zero updates no descriptor at all, and
	 dstBinding left at zero is binding zero, a real binding, so the writing method must set
	 both."

	#( #new #externalInstance ) do: [ :creator |
		| write |
		write := VkWriteDescriptorSet perform: creator.
		self assert: write sType equals: VkStructureType writeDescriptorSet.
		self assert: write descriptorCount equals: 0.
		self assert: write dstBinding equals: 0.
		self assert: write dstArrayElement equals: 0.
		creator = #externalInstance ifTrue: [ write getHandle free ] ]
]

{ #category : 'tests' }
VkBindingsTest >> testWriteDescriptorSetLayoutMatchesTheCLayout [
	"VkWriteDescriptorSet is declared field by field. dstSet is a handle and therefore pointer
	 wide; the three counts and the type are uint32 and pack into the sixteen bytes between
	 dstSet and the three pointer members, which are eight byte aligned. The struct is sixty
	 four bytes, with no hole: the four uint32 members fill the gap exactly."

	| rows |
	rows := VkWriteDescriptorSet layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #dstSet #dstBinding #dstArrayElement
		           #descriptorCount #descriptorType #pImageInfo #pBufferInfo
		           #pTexelBufferView ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 28 32 36 40 48 56 ).
	self assert: VkWriteDescriptorSet byteSize equals: 64.
	rows do: [ :each | self assert: each second \\ each third equals: 0 ].
	rows overlappingPairsDo: [ :a :b |
		self assert: a second + a third <= b second ]
]

{ #category : 'path' }
VkBindingsTest >> vkXmlPath [
    ^ FileLocator image parent parent parent parent / 'sources' / 'PharoVulkan' / 'vk.xml'
]
