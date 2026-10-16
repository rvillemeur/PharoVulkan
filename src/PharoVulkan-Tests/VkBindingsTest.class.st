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

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendAttachmentLayoutMatchesTheCLayout [
	"What becomes of one colour attachment's fragments: a flag, three colour factors and an
	 operation, then the same for alpha, then the channel mask. Eight four-byte fields, so
	 thirty-two bytes and no chain header — an attachment state is not a create info."

	| rows |
	rows := VkPipelineColorBlendAttachmentState layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #blendEnable #srcColorBlendFactor #dstColorBlendFactor
		   #colorBlendOp #srcAlphaBlendFactor #dstAlphaBlendFactor
		   #alphaBlendOp #colorWriteMask ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 12 16 20 24 28 ).
	self assert: VkPipelineColorBlendAttachmentState byteSize equals: 32
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendAttachmentRowsNameTheChannelsWritten [
	"The rows the Blending tab reads: whether blending is on, and which colour channels the
	 fragment is written to, named through VkColorComponent rather than shown as a mask."

	| state rows |
	state := VkGraphicsPipeline colorBlendState.
	rows := [		
	         (VkPipelineColorBlendAttachmentState fromHandle:
		          state pAttachments getHandle) blendAttachmentRows ] ensure: [
		        VkGraphicsPipeline freeColorBlendState: state ].
	self deny: (rows at: #blending).
	self
		assert: (rows at: #colorWriteMaskNames)
		equals: (VkColorComponent nameForFlags: VkColorComponent allChannels)
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendExamplesAndTabsAgree [
	"Both examples are what the project blends with, kept in object memory so they read after
	 the external store has gone, and each tab carries one row per entry its report answers.
	 The state's example has given its run back, so its report is the three rows it can still
	 answer and its tab shows those three."

	| attachment state rows table shown |
	attachment := VkPipelineColorBlendAttachmentState
		              exampleAttachmentThisProjectWritesEveryChannelOf.
	rows := attachment blendAttachmentRows.
	table := attachment inspectorBlendAttachment: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ].
	self
		assert: attachment colorWriteMask
		equals: VkColorComponent allChannels.
	state := VkPipelineColorBlendStateCreateInfo
		         exampleStateOfTheOneAttachmentThisProjectWritesTo.
	self
		assert: state attachmentCount
		equals: VkGraphicsPipeline colorAttachmentsPerPipeline.
	self deny: (state colorBlendRows at: #attachmentRunGiven).
	table := state inspectorColorBlend: SpPresenter new.
	self assert: table items size equals: state colorBlendRows size
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendRowsCountTheAttachmentsAndNestTheirReport [
	"The rows the Colour blend tab reads: how many attachments the run holds, whether the run
	 is given, whether a logic operation replaces blending, and the attachment's own report
	 nested inside — the attachment decodes its own fields rather than this state restating
	 them."

	| state rows |
	state := VkGraphicsPipeline colorBlendState.
	rows := [ state colorBlendRows ] ensure: [
		        VkGraphicsPipeline freeColorBlendState: state ].
	self
		assert: (rows at: #attachmentCount)
		equals: VkGraphicsPipeline colorAttachmentsPerPipeline.
	self assert: (rows at: #attachmentRunGiven).
	self deny: (rows at: #logicOperation).
	self deny: (rows at: #blending).
	self
		assert: (rows at: #colorWriteMaskNames)
		equals: (VkColorComponent nameForFlags: VkColorComponent allChannels)
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendStateGivesBackTheAttachmentRunItAllocated [
	"The state owns the run it points at, so giving the run back nulls the field as it goes:
	 the state is the record of where that run is, and a freed address left in it could be read
	 or freed twice. The state's own store is freed after the field is read, never before — a
	 field read over a freed store reads memory that is no longer ours."

	| state |
	state := VkGraphicsPipeline colorBlendState.
	[
	VkGraphicsPipeline freeColorBlendAttachmentsOf: state.
	self assert: state pAttachments isNull ] ensure: [ state getHandle free ]
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendStateInitializesOnlyWhatIsConstantForTheType [
	"The structure type is fixed by the type; everything else is a caller's choice. The
	 attachment state has no field fixed by its type at all, so it declares no initializer."

	| state setters |
	state := VkPipelineColorBlendStateCreateInfo externalInstance.
	[	self
		assert: state sType
		equals: VkStructureType pipelineColorBlendStateCreateInfo ] ensure: [
		state getHandle free ].
	setters := (VkPipelineColorBlendStateCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkPipelineColorBlendStateCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: ).
	self deny:
		(VkPipelineColorBlendAttachmentState includesSelector:
			 #initializeConstantFields)
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendStateLayoutMatchesTheCLayout [
	"The state over the attachment run: the logic operation, the run itself, and the four blend
	 constants. C declares the constants as one array of four floats; uFFI here cannot declare
	 an array field, so they are declared one component at a time and land at the same four
	 offsets, which makes the same fifty-six bytes."

	| rows |
	rows := VkPipelineColorBlendStateCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #logicOpEnable #logicOp
		   #attachmentCount #pAttachments #blendConstantRed
		   #blendConstantGreen #blendConstantBlue #blendConstantAlpha ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 28 32 40 44 48 52 ).
	self assert: VkPipelineColorBlendStateCreateInfo byteSize equals: 56
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColorBlendStateWritesEveryChannelWithoutBlending [
	"The one way this project writes colour: the fragment replaces what is there, on all four
	 channels. Blending is off, so the six factors and the two operations stay as the zeroed
	 block left them, and no logic operation is asked for."

	| state attachment |
	state := VkGraphicsPipeline colorBlendState.
	[		
		self
			assert: state attachmentCount
			equals: VkGraphicsPipeline colorAttachmentsPerPipeline.
		self deny: state pAttachments isNull.
		self assert: state logicOpEnable equals: 0.
		attachment := VkPipelineColorBlendAttachmentState fromHandle:
			              state pAttachments getHandle.
		self
			assert: attachment colorWriteMask
			equals: VkColorComponent allChannels.
		self assert: attachment blendEnable equals: 0.
		self assert: attachment srcColorBlendFactor equals: 0.
		self assert: attachment alphaBlendOp equals: 0 ] ensure: [
		VkGraphicsPipeline freeColorBlendState: state ]
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

{ #category : 'tests - colour blend' }
VkBindingsTest >> testColourWriteMaskHasOneHomeTheRenderConfigDelegatesTo [
	"The channel bits live in VkColorComponent; VkRenderConfig keeps its senders by
	 delegating, so the mask is declared in one place only."

	self
		assert: VkRenderConfig colorWriteMaskRGBA
		equals: VkColorComponent allChannels.
	self assert:
		((VkRenderConfig class >> #colorWriteMaskRGBA) messages includes:
			 #allChannels)
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

{ #category : 'tests - compute pipeline' }
VkBindingsTest >> testComputePipelineCreationWritesNoFieldAtAHandCountedOffset [
	"Both structures a compute pipeline creation writes are declared, so no method of
	 VkComputePipeline may write either at a counted offset. What is left is the out parameter
	 the creation answers through, which is one handle rather than a structure."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put:
	             #floatAt: #floatAt:put: #pointerAt: #pointerAt:put: #byteAt:
	             #byteAt:put: ).
	offenders := (VkComputePipeline methods , VkComputePipeline class methods)
		             select: [ :method |
			             method messages anySatisfy: [ :each |
				             banned includes: each ] ].
	self
		assert: (offenders collect: [ :each |
				 each methodClass name asString , ' >> ' , each selector ])
				asSortedCollection asArray
		equals: #( 'VkComputePipeline class >> handleForCreateInfo:on:' )
]

{ #category : 'tests - compute pipeline' }
VkBindingsTest >> testComputePipelineRequestExampleIsTheRequestTheProjectMakes [
	"The example is the request this project creates every compute pipeline from, kept in object
	 memory so a click leaks nothing. The entry point string it pointed at is freed with the
	 external store, so the kept copy must say so rather than point at freed memory, and
	 everything a caller does not choose stays as it was."

	| request |
	request := VkComputePipelineCreateInfo
		           exampleRequestForAComputeShader.
	self
		assert: request sType
		equals: VkStructureType computePipelineCreateInfo.
	self
		assert: request stage sType
		equals: VkStructureType pipelineShaderStageCreateInfo.
	self assert: request stage stage equals: VkShaderStage computeBit.
	self assert: request stage pName isNull.
	self assert: request pNext isNull.
	self
		assert: request basePipelineIndex
		equals: VkComputePipeline noBasePipelineIndex
]

{ #category : 'tests - compute pipeline' }
VkBindingsTest >> testComputePipelineRequestInitializesOnlyWhatIsConstantForTheType [
	"The request's own structure type is fixed by its type, so it is written once over a real
	 store. The nested stage's type is just as fixed, but it may not be written in an
	 initializer: the generated getter for a nested field answers the stage through fromHandle:,
	 so initialize runs on every read of the field, and a stage that initialized itself would
	 write into the request's store each time the field is read. Its builder writes it instead."

	| request setters |
	request := VkComputePipelineCreateInfo externalInstance.
	[
	self
		assert: request sType
		equals: VkStructureType computePipelineCreateInfo.
	self assert: request stage sType equals: 0 ] ensure: [
		request getHandle free ].
	setters := (VkComputePipelineCreateInfo >> #initializeConstantFields)
		           messages select: [ :each |
		           VkComputePipelineCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: ).
	self deny:
		(VkPipelineShaderStageCreateInfo includesSelector:
			 #initializeConstantFields)
]

{ #category : 'tests - layout' }
VkBindingsTest >> testComputePipelineRequestLayoutsMatchTheCLayout [
	"Two structures, one inside the other. A shader stage is the chain header, the flags, which
	 stage it is, the module it comes from, the entry point in that module and an optional
	 specialization: forty-eight bytes, with uFFI padding after the flags and the stage field
	 pair so the module lands pointer aligned. A compute pipeline request carries one of those
	 by value at byte twenty-four, then the layout, the pipeline it derives from and the index
	 of that pipeline, which rounds it to ninety-six bytes."

	| stageRows requestRows |
	stageRows := VkPipelineShaderStageCreateInfo layoutRows.
	self
		assert: (stageRows collect: [ :each | each first ]) asArray
		equals:
			#( #sType #pNext #flags #stage #module #pName
			   #pSpecializationInfo ).
	self
		assert: (stageRows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 40 ).
	self assert: VkPipelineShaderStageCreateInfo byteSize equals: 48.
	requestRows := VkComputePipelineCreateInfo layoutRows.
	self
		assert: (requestRows collect: [ :each | each first ]) asArray
		equals:
			#( #sType #pNext #flags #stage #layout #basePipelineHandle
			   #basePipelineIndex ).
	self
		assert: (requestRows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 72 80 88 ).
	self assert: VkComputePipelineCreateInfo byteSize equals: 96.
	self
		assert: (requestRows detect: [ :each | each first = #stage ]) third
		equals: VkPipelineShaderStageCreateInfo byteSize
]

{ #category : 'tests - compute pipeline' }
VkBindingsTest >> testComputePipelineRequestNamesTheComputeStageAndNoBasePipeline [
	"What the one builder writes, read back through the declared fields. A builder is a function
	 of its arguments, so no device is needed: null handles stand for the module and the layout.
	 The entry point arrives as a Pharo string and leaves as a NUL terminated C string the
	 request points at, and the pipeline derives from nothing, which in a signed field is minus
	 one."

	| request |
	request := VkComputePipeline
		           createInfoForModule:
		           (VkShaderModule_H fromHandle: ExternalAddress null)
		           entryPoint: VkShaderModule defaultEntryPoint
		           layout: (VkPipelineLayout_H fromHandle: ExternalAddress null).
	[
	self
		assert: request stage sType
		equals: VkStructureType pipelineShaderStageCreateInfo.
	self assert: request stage stage equals: VkShaderStage computeBit.
	self
		assert: request stage pName getHandle readString asString
		equals: VkShaderModule defaultEntryPoint.
	self assert: request stage pSpecializationInfo isNull.
	self assert: request basePipelineHandle isNull.
	self
		assert: request basePipelineIndex
		equals: VkComputePipeline noBasePipelineIndex ] ensure: [
		VkComputePipeline freeCreateInfo: request ]
]

{ #category : 'tests - compute pipeline' }
VkBindingsTest >> testComputePipelineRequestTabShowsEveryRowTheRequestReports [
	"The Pipeline tab is the report laid out, so it must carry one row per entry
	 computePipelineRows answers: a value added to the report cannot then stay invisible.
	 Building the table only reads, which is why the report is compared with itself afterwards."

	| example rows table shown |
	example := VkComputePipelineCreateInfo exampleRequestForAComputeShader.
	rows := example computePipelineRows.
	table := example inspectorComputePipeline: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :each | self assert: (shown includes: each) ].
	self assert: example computePipelineRows equals: rows
]

{ #category : 'tests - compute pipeline' }
VkBindingsTest >> testComputePipelineRowsNameTheStageAndTheEntryPoint [
	"The rows the Pipeline tab reads: which stage the shader is, whether a module and a layout
	 are given, the entry point in that module, and whether the pipeline derives from another.
	 The stage is named through VkShaderStage rather than shown as a bitmask, and the entry
	 point is read back out of the C string the request points at."

	| request rows |
	request := VkComputePipeline
		           createInfoForModule:
		           (VkShaderModule_H fromHandle: ExternalAddress null)
		           entryPoint: VkShaderModule defaultEntryPoint
		           layout: (VkPipelineLayout_H fromHandle: ExternalAddress null).
	rows := [ request computePipelineRows ] ensure: [
		        VkComputePipeline freeCreateInfo: request ].
	self
		assert: (rows at: #stageName)
		equals: (VkShaderStage nameForFlags: VkShaderStage computeBit).
	self assert: (rows at: #entryPoint) equals: VkShaderModule defaultEntryPoint.
	self deny: (rows at: #moduleGiven).
	self deny: (rows at: #layoutGiven).
	self deny: (rows at: #specializationGiven).
	self deny: (rows at: #derivesFromAPipeline)
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

{ #category : 'tests - rasterization' }
VkBindingsTest >> testCullModeNamesNoCullingRatherThanAnEmptyString [
	"Culling nothing is a mode of its own in Vulkan rather than an absence of bits, so the
	 decoder names it. The inherited decoder joins bit names and would answer nothing at all
	 for a word of no bits."

	self assert: (VkCullMode nameForFlags: VkCullMode none) equals: 'none'.
	self
		assert: (VkCullMode nameForFlags: VkCullMode backBit)
		equals: 'backBit'.
	self
		assert:
		(VkCullMode nameForFlags: VkCullMode frontBit + VkCullMode backBit)
		equals: 'frontBit|backBit'
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

{ #category : 'tests - dynamic state' }
VkBindingsTest >> testDynamicStateAsksForTheViewportAndTheScissor [
	"The two states this project sets while recording, in the order the builder names them.
	 The run is read back through the structure, by the stride it declares, rather than by a
	 counted offset here."

	| state |
	state := VkGraphicsPipeline dynamicState.
	[		
		self
			assert: state dynamicStateCount
			equals: VkGraphicsPipeline dynamicStatesSetWhileRecording size.
		self deny: state pDynamicStates isNull.
		self
			assert: state dynamicStateValues
			equals: {
					VkDynamicState viewport.
					VkDynamicState scissor } ] ensure: [
		VkGraphicsPipeline freeDynamicState: state ]
]

{ #category : 'tests - dynamic state' }
VkBindingsTest >> testDynamicStateExampleAndTabAgree [
	"The example is the state the project records with, kept in object memory so it reads after
	 the external store has gone. The run is given back before the copy is taken, so the report
	 is the rows the copy can still answer and the tab shows those."

	| state rows table shown |
	state := VkPipelineDynamicStateCreateInfo
		         exampleStateOfTheRectanglesThisProjectSetsWhileRecording.
	rows := state dynamicStateRows.
	self
		assert: (rows at: #dynamicStateCount)
		equals: VkGraphicsPipeline dynamicStatesSetWhileRecording size.
	self deny: (rows at: #stateRunGiven).
	table := state inspectorDynamicState: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ]
]

{ #category : 'tests - dynamic state' }
VkBindingsTest >> testDynamicStateGivesBackTheRunItAllocated [
	"The state owns the run it points at, so giving the run back nulls the field as it goes:
	 the state is the record of where that run is, and a freed address left in it could be
	 read or freed twice. The state's own store is freed after the field is read, never
	 before."

	| state |
	state := VkGraphicsPipeline dynamicState.
	[
	VkGraphicsPipeline freeDynamicStatesOf: state.
	self assert: state pDynamicStates isNull.
	self assert: state dynamicStateValues isEmpty ] ensure: [
		state getHandle free ]
]

{ #category : 'tests - dynamic state' }
VkBindingsTest >> testDynamicStateInitializesOnlyWhatIsConstantForTheType [
	"The structure type is fixed by the type; which states are dynamic is a caller's choice,
	 so the initializer stamps the type alone."

	| state setters |
	state := VkPipelineDynamicStateCreateInfo externalInstance.
	[	self
		assert: state sType
		equals: VkStructureType pipelineDynamicStateCreateInfo ] ensure: [
		state getHandle free ].
	setters := (VkPipelineDynamicStateCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkPipelineDynamicStateCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - dynamic state' }
VkBindingsTest >> testDynamicStateLayoutMatchesTheCLayout [
	"Which parts of the pipeline are set while recording rather than when it is built: a count
	 at twenty and the run of state values at twenty-four, which the pointer pads out to
	 thirty-two bytes."

	| rows |
	rows := VkPipelineDynamicStateCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #dynamicStateCount #pDynamicStates ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 ).
	self assert: VkPipelineDynamicStateCreateInfo byteSize equals: 32
]

{ #category : 'tests - dynamic state' }
VkBindingsTest >> testDynamicStateRowsNameEveryStateSetWhileRecording [
	"The rows the Dynamic state tab reads: how many states are dynamic, whether the run is
	 given, and each state named through VkDynamicState rather than shown as a number."

	| state rows |
	state := VkGraphicsPipeline dynamicState.
	rows := [ state dynamicStateRows ] ensure: [
		        VkGraphicsPipeline freeDynamicState: state ].
	self
		assert: (rows at: #dynamicStateCount)
		equals: VkGraphicsPipeline dynamicStatesSetWhileRecording size.
	self assert: (rows at: #stateRunGiven).
	self assert: (rows at: #dynamicStateNames) equals: 'viewport, scissor'
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

{ #category : 'tests - graphics pipeline' }
VkBindingsTest >> testEveryPipelineAsksForTheEntryPointTheModulesDeclare [
	"The name of the entered function belongs to the compiled module, not to a kind of pipeline,
	 so one constant answers it and both pipelines ask that constant. A second copy of the name
	 would let a pipeline ask for a function the emitted SPIR-V does not declare, which is why
	 no pipeline class may hold the name as a literal of its own."

	| offenders |
	self deny: (VkComputePipeline class includesSelector: #defaultEntryPoint).
	self assert:
		((VkComputePipeline class >> #on:layout:device:) messages includes:
			 #defaultEntryPoint).
	self assert:
		((VkGraphicsPipeline class
		  >> #shaderStagesForVertexModule:fragmentModule:) messages includes:
			 #defaultEntryPoint).
	offenders := OrderedCollection new.
	{ VkComputePipeline. VkGraphicsPipeline. VkPipelineShaderStageCreateInfo }
		do: [ :each |
			{ each. each class } do: [ :behavior |
				behavior methodsDo: [ :method |
					(method literals includes: VkShaderModule defaultEntryPoint)
						ifTrue: [
							offenders add:
								behavior name asString , ' >> ' , method selector ] ] ] ].
	self assert: offenders asArray equals: #(  )
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

{ #category : 'tests - graphics request' }
VkBindingsTest >> testGraphicsRequestGivesBackEveryStateItOwns [
	"The request owns the six states it built, and giving them back nulls every field as it
	 goes: the request is the record of where those states are, so a freed address left in one
	 could be read or freed twice. The states the caller passed in are not touched, and the
	 request's own store is still readable here — it is freed afterwards."

	| stages vertInput request |
	stages := VkGraphicsPipeline
		          shaderStagesForVertexModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null)
		          fragmentModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null).
	vertInput := VkGraphicsPipeline
		             vertexInputStateForBindings:
		             VkGraphicsPipeline vertexBindingDescriptions
		             attributes: VkGraphicsPipeline vertexAttributeDescriptions.
	request := VkGraphicsPipeline
		           requestForStages: stages
		           vertexInput: vertInput
		           layout: (VkPipelineLayout_H fromHandle: ExternalAddress null)
		           renderPass: (VkRenderPass_H fromHandle: ExternalAddress null).
	[
	VkGraphicsPipeline freeNestedStatesOf: request.
	self
		assert: request statesGiven asArray
		equals: #( #pVertexInputState ).
	self deny: request pVertexInputState isNull ] ensure: [
		request getHandle free.
		VkGraphicsPipeline freeVertexInputState: vertInput.
		VkGraphicsPipeline freeShaderStages: stages ]
]

{ #category : 'tests - graphics request' }
VkBindingsTest >> testGraphicsRequestInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type. Every state pointer, the layout,
	 the render pass and the subpass belong to the caller, and a zeroed request reads as a
	 pipeline with no stages that derives from no other — basePipelineIndex zero is a real index
	 rather than the sentinel, which is why the builder writes it."

	| request setters |
	request := VkGraphicsPipelineCreateInfo externalInstance.
	[
	self
		assert: request sType
		equals: VkStructureType graphicsPipelineCreateInfo.
	self assert: request pNext isNull.
	self assert: request flags equals: 0.
	self assert: request stageCount equals: 0.
	self assert: request pStages isNull.
	self assert: request statesGiven isEmpty.
	self assert: request layout isNull.
	self assert: request renderPass isNull.
	self assert: request subpass equals: 0.
	self assert: request basePipelineHandle isNull.
	self assert: request basePipelineIndex equals: 0 ] ensure: [
		request getHandle free ].
	setters := (VkGraphicsPipelineCreateInfo >> #initializeConstantFields)
		           messages select: [ :each |
		           VkGraphicsPipelineCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - graphics request' }
VkBindingsTest >> testGraphicsRequestLayoutMatchesTheCLayout [
	"Every nested state is pointed at rather than nested by value, so each field is one pointer
	 wide and eight byte aligned; flags and stageCount are a uint32 pair at sixteen and twenty,
	 and subpass is a word at one hundred and twenty which uFFI pads to one hundred and
	 twenty-eight for the handle after it. That makes the request one hundred and forty-four
	 bytes, which is the size the previous counted write allocated."

	| rows |
	rows := VkGraphicsPipelineCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals:
			#( #sType #pNext #flags #stageCount #pStages #pVertexInputState
			   #pInputAssemblyState #pTessellationState #pViewportState
			   #pRasterizationState #pMultisampleState #pDepthStencilState
			   #pColorBlendState #pDynamicState #layout #renderPass #subpass
			   #basePipelineHandle #basePipelineIndex ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals:
			#( 0 8 16 20 24 32 40 48 56 64 72 80 88 96 104 112 120 128 136 ).
	self assert: VkGraphicsPipelineCreateInfo byteSize equals: 144
]

{ #category : 'tests - graphics request' }
VkBindingsTest >> testGraphicsRequestPointsAtEveryStateThePipelineNeeds [
	"The request a graphics pipeline is created from, built with null handles so no device is
	 needed: the two stages and the vertex input state the caller passed in, and the six states
	 the request builds itself. Tessellation and depth stencil are not asked for and stay null,
	 and the request derives from no other pipeline."

	| stages vertInput request |
	stages := VkGraphicsPipeline
		          shaderStagesForVertexModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null)
		          fragmentModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null).
	vertInput := VkGraphicsPipeline
		             vertexInputStateForBindings:
		             VkGraphicsPipeline vertexBindingDescriptions
		             attributes: VkGraphicsPipeline vertexAttributeDescriptions.
	request := VkGraphicsPipeline
		           requestForStages: stages
		           vertexInput: vertInput
		           layout: (VkPipelineLayout_H fromHandle: ExternalAddress null)
		           renderPass: (VkRenderPass_H fromHandle: ExternalAddress null).
	[
	self assert: request stageCount equals: stages size.
	self
		assert: request pStages getHandle
		equals: stages first getHandle.
	self
		assert: request pVertexInputState getHandle
		equals: vertInput getHandle.
	self
		assert: request statesGiven asArray
		equals:
			#( #pVertexInputState #pInputAssemblyState #pViewportState
			   #pRasterizationState #pMultisampleState #pColorBlendState
			   #pDynamicState ).
	self assert: request pTessellationState isNull.
	self assert: request pDepthStencilState isNull.
	self
		assert: request subpass
		equals: VkGraphicsPipeline subpassThisPipelineDrawsIn.
	self assert: request basePipelineHandle isNull.
	self
		assert: request basePipelineIndex
		equals: VkPipelineCreation noBasePipelineIndex ] ensure: [
		VkGraphicsPipeline freeRequest: request.
		VkGraphicsPipeline freeVertexInputState: vertInput.
		VkGraphicsPipeline freeShaderStages: stages ]
]

{ #category : 'tests - graphics request' }
VkBindingsTest >> testGraphicsRequestRowsNameWhatItAsksFor [
	"The rows the Request tab reads, taken from the example: how many stages, which nested
	 states are given, whether the layout and the render pass are there, the subpass and the
	 base pipeline. The state names come from the declared layout, so a state added to the
	 structure is reported without the report being touched. A row never follows a pointer — the
	 example has already given its states back — so the rows say a state is there rather than
	 what it holds."

	| request rows |
	request := VkGraphicsPipelineCreateInfo
		           exampleRequestOfTheTriangleThisProjectDraws.
	rows := request graphicsRequestRows.
	self
		assert: (rows at: #stageCount)
		equals: VkGraphicsPipeline shaderStagesPerPipeline.
	self deny: (rows at: #stagesGiven).
	self assert: (rows at: #statesGiven) equals: ''.
	self deny: (rows at: #layoutGiven).
	self deny: (rows at: #renderPassGiven).
	self
		assert: (rows at: #subpass)
		equals: VkGraphicsPipeline subpassThisPipelineDrawsIn.
	self deny: (rows at: #derivesFromAPipeline).
	self
		assert: (rows at: #basePipelineIndex)
		equals: VkPipelineCreation noBasePipelineIndex.
	self
		assert: (VkGraphicsPipelineCreateInfo stateFieldNames includes:
				 #pColorBlendState)
]

{ #category : 'tests - graphics request' }
VkBindingsTest >> testGraphicsRequestTabShowsEveryRowItsReportAnswers [
	"The Request tab is the report laid out, so it carries one row per entry the report answers:
	 a value added to the report cannot then stay invisible. Building a table only reads, which
	 is why the report is compared with itself afterwards."

	| request rows table shown |
	request := VkGraphicsPipelineCreateInfo
		           exampleRequestOfTheTriangleThisProjectDraws.
	rows := request graphicsRequestRows.
	table := request inspectorGraphicsRequest: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ].
	self assert: request graphicsRequestRows equals: rows
]

{ #category : 'tests - graphics pipeline' }
VkBindingsTest >> testGraphicsShaderStagesNameAVertexAndAFragmentStage [
	"The two stages a graphics pipeline is created from live in one external run, so the request
	 can name them by the first element's address. Each stage carries its own structure type,
	 its own module handle and its own copy of the entry point name; neither asks for a
	 specialization. The names are separate allocations, so freeing one stage cannot leave a
	 freed address in the other."

	| stages |
	stages := VkGraphicsPipeline
		          shaderStagesForVertexModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null)
		          fragmentModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null).
	[
		self assert: stages size equals: 2.
		stages do: [ :each |
			self
				assert: each sType
				equals: VkStructureType pipelineShaderStageCreateInfo.
			self
				assert: each pName getHandle readString asString
				equals: VkShaderModule defaultEntryPoint.
			self assert: each pSpecializationInfo isNull ].
		self assert: stages first stage equals: VkShaderStage vertexBit.
		self assert: stages second stage equals: VkShaderStage fragmentBit.
		self
			deny: stages first pName getHandle asInteger
			equals: stages second pName getHandle asInteger ] ensure: [
		VkGraphicsPipeline freeShaderStages: stages ]
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

{ #category : 'tests - input assembly' }
VkBindingsTest >> testInputAssemblyExampleAndTabAgree [
	"The example is the state the project draws with, kept in object memory so it reads after
	 the external store has gone, and the tab carries one row per entry the report answers."

	| state rows table shown |
	state := VkPipelineInputAssemblyStateCreateInfo
		         exampleStateOfTheTriangleListThisProjectDraws.
	rows := state inputAssemblyRows.
	self assert: state topology equals: VkPrimitiveTopology triangleList.
	table := state inspectorInputAssembly: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ].
	self assert: state inputAssemblyRows equals: rows
]

{ #category : 'tests - input assembly' }
VkBindingsTest >> testInputAssemblyInitializesOnlyWhatIsConstantForTheType [
	"The structure type is fixed by the type; the topology and the restart flag are a caller's
	 choice, so the initializer stamps the type alone."

	| state setters |
	state := VkPipelineInputAssemblyStateCreateInfo externalInstance.
	[	self
		assert: state sType
		equals: VkStructureType pipelineInputAssemblyStateCreateInfo ] ensure: [
		state getHandle free ].
	setters := (VkPipelineInputAssemblyStateCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkPipelineInputAssemblyStateCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - input assembly' }
VkBindingsTest >> testInputAssemblyLayoutMatchesTheCLayout [
	"How the primitives are assembled from the vertex run: a topology and a restart flag after
	 the chain header. The two uint32 fields after the flags land at twenty and twenty-four and
	 the structure pads to thirty-two, because a create info is pointer aligned."

	| rows |
	rows := VkPipelineInputAssemblyStateCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #topology #primitiveRestartEnable ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 ).
	self assert: VkPipelineInputAssemblyStateCreateInfo byteSize equals: 32
]

{ #category : 'tests - input assembly' }
VkBindingsTest >> testInputAssemblyRowsNameTheTopology [
	"The rows the Input assembly tab reads: the topology named through VkPrimitiveTopology
	 rather than shown as a number, and whether primitive restart is asked for."

	| state rows |
	state := VkGraphicsPipeline inputAssemblyState.
	rows := [ state inputAssemblyRows ] ensure: [ state getHandle free ].
	self
		assert: (rows at: #topologyName)
		equals: (VkPrimitiveTopology nameForValue:
				 VkPrimitiveTopology triangleList) asString.
	self deny: (rows at: #primitiveRestart)
]

{ #category : 'tests - input assembly' }
VkBindingsTest >> testInputAssemblyStateDrawsATriangleListWithoutPrimitiveRestart [
	"The one shape this project draws: separate triangles, three vertices each, with no restart
	 index. Primitive restart applies to indexed draws, and nothing here draws indexed."

	| state |
	state := VkGraphicsPipeline inputAssemblyState.
	[		
		self assert: state topology equals: VkPrimitiveTopology triangleList.
		self
			assert: state primitiveRestartEnable
			equals: VkGraphicsPipeline primitiveRestartDisabled ] ensure: [
		state getHandle free ]
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

{ #category : 'tests - multisample' }
VkBindingsTest >> testMultisampleRowsNameTheSampleCount [
	"The rows the Multisample tab reads: the sample count named through VkSampleCount rather
	 than shown as a bit, whether a mask is given, and one entry per feature that can be
	 switched on."

	| state rows |
	state := VkGraphicsPipeline multisampleState.
	rows := [ state multisampleRows ] ensure: [ state getHandle free ].
	self
		assert: (rows at: #sampleCountNames)
		equals: (VkSampleCount nameForFlags: VkSampleCount count1Bit).
	self
		assert: (rows at: #minSampleShading)
		equals: VkGraphicsPipeline everySampleShaded.
	self deny: (rows at: #sampleMaskGiven).
	self deny: (rows at: #sampleShading).
	self deny: (rows at: #alphaToCoverage).
	self deny: (rows at: #alphaToOne)
]

{ #category : 'tests - multisample' }
VkBindingsTest >> testMultisampleStateExampleAndTabAgree [
	"The example is the state the project samples with, kept in object memory so it reads
	 after the external store has gone, and the tab carries one row per entry the report
	 answers."

	| state rows table shown |
	state := VkPipelineMultisampleStateCreateInfo
		         exampleStateOfTheOneSamplePerPixelThisProjectTakes.
	rows := state multisampleRows.
	self
		assert: state rasterizationSamples
		equals: VkSampleCount count1Bit.
	table := state inspectorMultisample: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ].
	self assert: state multisampleRows equals: rows
]

{ #category : 'tests - multisample' }
VkBindingsTest >> testMultisampleStateInitializesOnlyWhatIsConstantForTheType [
	"The structure type is fixed by the type; the sample count and everything after it are a
	 caller's choice, so the initializer stamps the type alone."

	| state setters |
	state := VkPipelineMultisampleStateCreateInfo externalInstance.
	[	self
		assert: state sType
		equals: VkStructureType pipelineMultisampleStateCreateInfo ] ensure: [
		state getHandle free ].
	setters := (VkPipelineMultisampleStateCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkPipelineMultisampleStateCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - multisample' }
VkBindingsTest >> testMultisampleStateLayoutMatchesTheCLayout [
	"How many samples a pixel is made of: a sample count, a shading flag and a shading fraction
	 after the chain header, then the sample mask pointer, which re-aligns to thirty-two, and
	 the two alpha flags after it. Forty-eight bytes in all."

	| rows |
	rows := VkPipelineMultisampleStateCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #rasterizationSamples
		   #sampleShadingEnable #minSampleShading #pSampleMask
		   #alphaToCoverageEnable #alphaToOneEnable ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 28 32 40 44 ).
	self assert: VkPipelineMultisampleStateCreateInfo byteSize equals: 48
]

{ #category : 'tests - multisample' }
VkBindingsTest >> testMultisampleStateTakesOneSamplePerPixel [
	"The one way this project samples: one sample per pixel, so there is nothing to average
	 and no mask to hand over. The alpha flags and sample shading read as zero because nothing
	 wrote them."

	| state |
	state := VkGraphicsPipeline multisampleState.
	[		
		self assert: state rasterizationSamples equals: VkSampleCount count1Bit.
		self
			assert: state minSampleShading
			equals: VkGraphicsPipeline everySampleShaded.
		self assert: state pSampleMask isNull.
		self assert: state sampleShadingEnable equals: 0.
		self assert: state alphaToCoverageEnable equals: 0.
		self assert: state alphaToOneEnable equals: 0 ] ensure: [
		state getHandle free ]
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

{ #category : 'tests - graphics request' }
VkBindingsTest >> testNoOffsetIsCountedInTheGraphicsPipelineAnyMore [
	"Every structure the graphics pipeline builds is declared, so no method of it reaches into a
	 block at a counted offset to write a field. Two reads of a block are left and neither is a
	 structure field: the run of dynamic state enumerations, which holds plain words rather than
	 structures and so has a named stride instead of a layout, and the out parameter the driver
	 answers the new handle through."

	| counting |
	counting := (VkGraphicsPipeline methods , VkGraphicsPipeline class methods)
		            select: [ :each |
		            each messages anySatisfy: [ :message |
			            #( #unsignedLongAt: #unsignedLongAt:put: #pointerAt:
			               #pointerAt:put: ) includes: message ] ].
	self
		assert:
		((counting collect: [ :each |
			  each methodClass name , ' >> ' , each selector ]) asSortedCollection:
			 [ :a :b | a <= b ]) asArray
		equals: #( 'VkGraphicsPipeline class >> dynamicState'
			   'VkGraphicsPipeline class >> handleForRequest:on:' )
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

{ #category : 'tests - compute pipeline' }
VkBindingsTest >> testOnlyOneMethodCreatesAComputePipeline [
	"One builder of the request and one caller of the creation, so one place owns the out
	 parameter the creation answers through. The tests are rejected from the senders: a test
	 naming the call is itself a sender."

	| callers |
	callers := (SystemNavigation default allSendersOf:
		            #createComputePipelines:pipelineCache:createInfoCount:createInfos:allocator:pipelines:)
		           reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (callers collect: [ :each |
				 each methodClass name asString , ' >> ' , each selector ])
				asSortedCollection asArray
		equals: #( 'VkComputePipeline class >> handleForCreateInfo:on:' ).
	self
		assert: (VkComputePipelineCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkComputePipeline class >> createInfoForModule:entryPoint:layout:' )
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

{ #category : 'tests - layout' }
VkBindingsTest >> testOnlyOneMethodCreatesASwapchain [
	"One builder, one caller of the creation, and the request is written nowhere else. The
	 tests are rejected from the senders: a test naming the call is itself a sender."

	| callers |
	callers := (SystemNavigation default allSendersOf:
		            #createSwapchainKHR:createInfo:allocator:swapchain:) reject: [
		           :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (callers collect: [ :each |
				 each methodClass name , ' >> ' , each selector ]) asSortedCollection asArray
		equals: #( 'VkSwapchain class >> handleForCreateInfo:on:' ).
	self
		assert: (VkSwapchainCreateInfoKHR writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals:
		#( 'VkSwapchain class >> createInfoForSurface:format:capabilities:extent:' )
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

{ #category : 'tests - layout' }
VkBindingsTest >> testOnlyOneMethodPresentsASwapchain [
	"One builder of the request and one caller of the presentation, so there is one place where
	 a frame reaches the screen. The tests are rejected from the senders: a test naming the call
	 is itself a sender."

	| callers |
	callers := (SystemNavigation default allSendersOf:
		            #queuePresentKHR:pPresentInfo:) reject: [ :each |
		           each methodClass instanceSide includesBehavior: TestCase ].
	self
		assert: (callers collect: [ :each |
				 each methodClass name asString , ' >> ' , each selector ])
				asSortedCollection asArray
		equals: #( 'VkSwapchain >> present:queue:waitSemaphore:' ).
	self
		assert: (VkPresentInfoKHR writerRows collect: [ :each | each at: #method ])
				asArray
		equals:
		#( 'VkSwapchain class >> presentInfoForSwapchain:imageIndex:waitSemaphore:' )
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

{ #category : 'tests - graphics pipeline' }
VkBindingsTest >> testOnlyOneMethodWritesAGraphicsShaderStageRun [
	"One builder of the stage run, so one place allocates the entry point strings and one place
	 gives them back. The reflected writer list is what the Writers tab shows, so a second
	 writer would show there as well as here. The compute pipeline writes the stage nested
	 inside its request and names the request class rather than this one, which is why it is not
	 listed: a writer counts only where it also names the structure it fills."

	self
		assert: (VkPipelineShaderStageCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals:
		#( 'VkGraphicsPipeline class >> shaderStagesForVertexModule:fragmentModule:' )
]

{ #category : 'tests - colour blend' }
VkBindingsTest >> testOnlyOneMethodWritesTheColourBlendState [
	"One builder for the state and the attachment it points at, so one place decides how this
	 project writes colour. The reflected writer lists are what the Writers tabs show, so a
	 second writer would show there too."

	self
		assert: (VkPipelineColorBlendStateCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkGraphicsPipeline class >> colorBlendState' ).
	self
		assert: (VkPipelineColorBlendAttachmentState writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkGraphicsPipeline class >> colorBlendState' )
]

{ #category : 'tests - dynamic state' }
VkBindingsTest >> testOnlyOneMethodWritesTheDynamicState [
	"One builder, so one place decides which states are set while recording. The reflected
	 writer list is what the Writers tab shows, so a second writer would show there too."

	self
		assert: (VkPipelineDynamicStateCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkGraphicsPipeline class >> dynamicState' )
]

{ #category : 'tests - graphics request' }
VkBindingsTest >> testOnlyOneMethodWritesTheGraphicsRequest [
	"One builder of the request, so one place owns the states nested under it and one place
	 gives them back. The reflected writer list is what the Writers tab shows, so a second
	 writer would show there as well as here."

	self
		assert: (VkGraphicsPipelineCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals:
		#( 'VkGraphicsPipeline class >> requestForStages:vertexInput:layout:renderPass:' )
]

{ #category : 'tests - input assembly' }
VkBindingsTest >> testOnlyOneMethodWritesTheInputAssemblyState [
	"One builder, so one place decides how the project assembles primitives. The reflected
	 writer list is what the Writers tab shows, so a second writer would show there too."

	self
		assert: (VkPipelineInputAssemblyStateCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkGraphicsPipeline class >> inputAssemblyState' )
]

{ #category : 'tests - multisample' }
VkBindingsTest >> testOnlyOneMethodWritesTheMultisampleState [
	"One builder, so one place decides how many samples a pixel is made of. The reflected
	 writer list is what the Writers tab shows, so a second writer would show there too."

	self
		assert: (VkPipelineMultisampleStateCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkGraphicsPipeline class >> multisampleState' )
]

{ #category : 'tests - rasterization' }
VkBindingsTest >> testOnlyOneMethodWritesTheRasterizationState [
	"One builder, so one place decides how this project rasterizes. The reflected writer list
	 is what the Writers tab shows, so a second writer would show there too."

	self
		assert: (VkPipelineRasterizationStateCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkGraphicsPipeline class >> rasterizationState' )
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testOnlyOneMethodWritesTheVertexInputState [
	"One builder of the vertex input state, so one place owns the two runs it points at and one
	 place frees them. The reflected writer list is what the Writers tab shows, so a second
	 writer would show there as well as here."

	self
		assert: (VkPipelineVertexInputStateCreateInfo writerRows collect: [
				 :each | each at: #method ]) asArray
		equals:
		#( 'VkGraphicsPipeline class >> vertexInputStateForBindings:attributes:' )
]

{ #category : 'tests - viewport' }
VkBindingsTest >> testOnlyOneMethodWritesTheViewportState [
	"One builder, so one place decides how many rectangles the pipeline draws into. The
	 reflected writer list is what the Writers tab shows, so a second writer would show there
	 too."

	self
		assert: (VkPipelineViewportStateCreateInfo writerRows collect: [ :each |
				 each at: #method ]) asArray
		equals: #( 'VkGraphicsPipeline class >> viewportState' )
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

{ #category : 'tests - graphics request' }
VkBindingsTest >> testPipelineCreationConstantsHaveOneHomeBothKindsOfPipelineAsk [
	"Two values belong to pipeline creation itself rather than to a kind of pipeline: the number
	 of requests one create call takes, and the index that means the pipeline derives from no
	 other. VkPipelineCreation is where they live, and the compute pipeline's own methods
	 delegate to it, so neither value is written in two places."

	self assert: VkPipelineCreation pipelinesPerCreate equals: 1.
	self assert: VkPipelineCreation noBasePipelineIndex equals: -1.
	#( #pipelinesPerCreate #noBasePipelineIndex ) do: [ :each |
		self
			assert: (VkComputePipeline perform: each)
			equals: (VkPipelineCreation perform: each).
		self assert:
			((VkComputePipeline class >> each) messages includes: each) ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testPresentInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type. Both counts are one for every
	 present this project makes, but one swapchain and one semaphore are a caller's choice
	 rather than a property of the structure, and a pointer written in an initializer would be
	 written again on every read of the field."

	| info setters |
	info := VkPresentInfoKHR externalInstance.
	[ self assert: info sType equals: VkStructureType presentInfoKHR ] ensure: [
		info getHandle free ].
	setters := (VkPresentInfoKHR >> #initializeConstantFields) messages select: [
		           :each | VkPresentInfoKHR includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - layout' }
VkBindingsTest >> testPresentInfoLayoutMatchesTheCLayout [
	"What vkQueuePresentKHR reads: the chain header, a count and a run of semaphores to wait
	 on, a count and a run of swapchains, one image index per swapchain, and an optional run
	 of per-swapchain results. uFFI pads after each of the two counts, which rounds the
	 request to sixty-four bytes. Every run is pointed at, so each pointer field is one
	 pointer wide however many elements sit behind it."

	| rows |
	rows := VkPresentInfoKHR layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #waitSemaphoreCount #pWaitSemaphores
		           #swapchainCount #pSwapchains #pImageIndices #pResults ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 40 48 56 ).
	self assert: VkPresentInfoKHR byteSize equals: 64
]

{ #category : 'tests - layout' }
VkBindingsTest >> testPresentRequestExampleKeepsTheCountsAndNoFreedRun [
	"The example is built by the one writer the present path uses, so its counts are the ones a
	 real present asks for. Its runs are given back before the copy is kept, so every run field
	 reads as null rather than as an address that has been freed, and the copy lives in object
	 memory, so a click frees nothing."

	| example rows |
	example := VkPresentInfoKHR examplePresentRequestForOneSwapchain.
	rows := example presentRows.
	self
		assert: (rows at: #waitSemaphoreCount)
		equals: VkSwapchain semaphoresPerPresent.
	self
		assert: (rows at: #swapchainCount)
		equals: VkSwapchain swapchainsPerPresent.
	self deny: (rows at: #waitsOnASemaphore).
	self deny: (rows at: #swapchainGiven).
	self deny: (rows at: #imageIndexGiven).
	self deny: (rows at: #resultsRequested).
	self assert: example sType equals: VkStructureType presentInfoKHR.
	self deny: example getHandle isExternalAddress
]

{ #category : 'tests - layout' }
VkBindingsTest >> testPresentRequestNamesOneSwapchainAndOneSemaphore [
	"What the builder writes, with no queue in reach: one semaphore to wait on, one swapchain,
	 one image index, and no run of per-swapchain results, because a present of one swapchain
	 learns everything from the code the call answers. Each run carries what it was given,
	 read back through the pointer the request holds. The handles are null here; what matters
	 is that the runs carry what they were handed."

	| info |
	info := VkSwapchain
		        presentInfoForSwapchain: ExternalAddress null
		        imageIndex: VkSwapchain exampleImageIndex
		        waitSemaphore: ExternalAddress null.
	[
	self assert: info sType equals: VkStructureType presentInfoKHR.
	self
		assert: info waitSemaphoreCount
		equals: VkSwapchain semaphoresPerPresent.
	self assert: info swapchainCount equals: VkSwapchain swapchainsPerPresent.
	self deny: info pWaitSemaphores isNull.
	self deny: info pSwapchains isNull.
	self deny: info pImageIndices isNull.
	self assert: info pResults isNull.
	self
		assert: (info pImageIndices getHandle unsignedLongAt: 1)
		equals: VkSwapchain exampleImageIndex ] ensure: [
		VkSwapchain freePresentInfo: info ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testPresentRequestTabShowsEveryRowTheRequestReports [
	"The Present tab is the report laid out, so it must carry one row per entry presentRows
	 answers: a value added to the report cannot then stay invisible. Building the table only
	 reads, which is why the report is compared with itself afterwards."

	| example rows table shown |
	example := VkPresentInfoKHR examplePresentRequestForOneSwapchain.
	rows := example presentRows.
	table := example inspectorPresent: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :each | self assert: (shown includes: each) ].
	self assert: example presentRows equals: rows
]

{ #category : 'tests - layout' }
VkBindingsTest >> testPresentRowsNameTheCountsAndSayWhichRunsAreThere [
	"What the Present tab reads. The counts come from the request itself and the three runs are
	 reported as there or not, because their addresses say nothing to a reader. The results run
	 is never asked for. Read only, so the tab leaves the store alone."

	| info rows |
	info := VkSwapchain
		        presentInfoForSwapchain: ExternalAddress null
		        imageIndex: VkSwapchain exampleImageIndex
		        waitSemaphore: ExternalAddress null.
	rows := [ info presentRows ] ensure: [ VkSwapchain freePresentInfo: info ].
	self
		assert: (rows at: #waitSemaphoreCount)
		equals: VkSwapchain semaphoresPerPresent.
	self
		assert: (rows at: #swapchainCount)
		equals: VkSwapchain swapchainsPerPresent.
	self assert: (rows at: #waitsOnASemaphore).
	self assert: (rows at: #swapchainGiven).
	self assert: (rows at: #imageIndexGiven).
	self deny: (rows at: #resultsRequested)
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

{ #category : 'tests - rasterization' }
VkBindingsTest >> testRasterizationRowsNameThePolygonModeAndTheCulling [
	"The rows the Rasterization tab reads: each enumeration named by the constants class that
	 owns it rather than shown as a number, and one row per feature that can be switched on."

	| state rows |
	state := VkGraphicsPipeline rasterizationState.
	rows := [ state rasterizationRows ] ensure: [ state getHandle free ].
	self
		assert: (rows at: #polygonModeName)
		equals: (VkPolygonMode nameForValue: VkPolygonMode fill) asString.
	self
		assert: (rows at: #cullModeNames)
		equals: (VkCullMode nameForFlags: VkCullMode none).
	self
		assert: (rows at: #frontFaceName)
		equals:
		(VkFrontFace nameForValue: VkFrontFace counterClockwise) asString.
	self
		assert: (rows at: #lineWidth)
		equals: VkGraphicsPipeline lineWidthEveryDeviceAccepts.
	self deny: (rows at: #depthClamp).
	self deny: (rows at: #rasterizationDiscarded).
	self deny: (rows at: #depthBias)
]

{ #category : 'tests - rasterization' }
VkBindingsTest >> testRasterizationStateExampleAndTabAgree [
	"The example is the state the project rasterizes with, kept in object memory so it reads
	 after the external store has gone, and the tab carries one row per entry the report
	 answers."

	| state rows table shown |
	state := VkPipelineRasterizationStateCreateInfo
		         exampleStateOfTheFilledTrianglesThisProjectDraws.
	rows := state rasterizationRows.
	self assert: state polygonMode equals: VkPolygonMode fill.
	table := state inspectorRasterization: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ].
	self assert: state rasterizationRows equals: rows
]

{ #category : 'tests - rasterization' }
VkBindingsTest >> testRasterizationStateFillsTrianglesWithoutCullingOrDepthBias [
	"The one way this project rasterizes: filled triangles, no face discarded, front faces
	 wound counter clockwise, and a line width every device accepts. The three disabled
	 features read as zero because nothing wrote them."

	| state |
	state := VkGraphicsPipeline rasterizationState.
	[		
		self assert: state polygonMode equals: VkPolygonMode fill.
		self assert: state cullMode equals: VkCullMode none.
		self assert: state frontFace equals: VkFrontFace counterClockwise.
		self
			assert: state lineWidth
			equals: VkGraphicsPipeline lineWidthEveryDeviceAccepts.
		self assert: state depthClampEnable equals: 0.
		self assert: state rasterizerDiscardEnable equals: 0.
		self assert: state depthBiasEnable equals: 0 ] ensure: [
		state getHandle free ]
]

{ #category : 'tests - rasterization' }
VkBindingsTest >> testRasterizationStateInitializesOnlyWhatIsConstantForTheType [
	"The structure type is fixed by the type; every other field is a caller's choice, so the
	 initializer stamps the type alone."

	| state setters |
	state := VkPipelineRasterizationStateCreateInfo externalInstance.
	[	self
		assert: state sType
		equals: VkStructureType pipelineRasterizationStateCreateInfo ] ensure: [
		state getHandle free ].
	setters := (VkPipelineRasterizationStateCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkPipelineRasterizationStateCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - rasterization' }
VkBindingsTest >> testRasterizationStateLayoutMatchesTheCLayout [
	"How triangles become fragments: three flags, three enumerations and four floats after the
	 chain header. Every field from twenty on is four bytes wide and tightly packed, so the
	 structure runs to sixty-four bytes with no padding but the pointer's own."

	| rows |
	rows := VkPipelineRasterizationStateCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #depthClampEnable
		   #rasterizerDiscardEnable #polygonMode #cullMode #frontFace
		   #depthBiasEnable #depthBiasConstantFactor #depthBiasClamp
		   #depthBiasSlopeFactor #lineWidth ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 28 32 36 40 44 48 52 56 ).
	self assert: VkPipelineRasterizationStateCreateInfo byteSize equals: 64
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

{ #category : 'tests - multisample' }
VkBindingsTest >> testSampleCountHasOneHomeTheRenderConfigDelegatesTo [
	"The sample count bits live in VkSampleCount; VkRenderConfig keeps its senders by
	 delegating, so the value is declared in one place only."

	self
		assert: VkRenderConfig sampleCount1Bit
		equals: VkSampleCount count1Bit.
	self assert:
		((VkRenderConfig class >> #sampleCount1Bit) messages includes:
			 #count1Bit)
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

{ #category : 'tests - graphics pipeline' }
VkBindingsTest >> testShaderStageExampleIsTheStagesTheProjectDraws [
	"The example is the pair of stages the triangle is drawn with, kept in object memory so it
	 can be inspected after the run has gone. Its entry point strings are given back before the
	 copies are taken, so each row says the name is gone rather than naming a freed address."

	| stages |
	stages := VkPipelineShaderStageCreateInfo
		          exampleStagesOfTheTriangleThisProjectDraws.
	self
		assert: stages size
		equals: VkGraphicsPipeline shaderStagesPerPipeline.
	self
		assert: (stages collect: [ :each | each stage ]) asArray
		equals: {
				VkShaderStage vertexBit.
				VkShaderStage fragmentBit }.
	stages do: [ :each |
		self
			assert: each sType
			equals: VkStructureType pipelineShaderStageCreateInfo.
		self
			assert: (each stageRows at: #entryPoint)
			equals: VkPipelineShaderStageCreateInfo nullLabel ]
]

{ #category : 'tests - graphics pipeline' }
VkBindingsTest >> testShaderStageRowsNameTheStageAndTheEntryPoint [
	"The rows a stage reports: which stage it is, whether a module and a specialization are
	 there, and the entry point read back out of the C string the stage points at. The compute
	 request answers the same rows for the stage nested inside it, so one place decodes a stage
	 and the two tabs cannot drift apart."

	| stages rows |
	stages := VkGraphicsPipeline
		          shaderStagesForVertexModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null)
		          fragmentModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null).
	rows := [ stages collect: [ :each | each stageRows ] ] ensure: [
		        VkGraphicsPipeline freeShaderStages: stages ].
	self
		assert: (rows first at: #stageName)
		equals: (VkShaderStage nameForFlags: VkShaderStage vertexBit).
	self
		assert: (rows second at: #stageName)
		equals: (VkShaderStage nameForFlags: VkShaderStage fragmentBit).
	rows do: [ :each |
		self deny: (each at: #moduleGiven).
		self deny: (each at: #specializationGiven).
		self
			assert: (each at: #entryPoint)
			equals: VkShaderModule defaultEntryPoint ]
]

{ #category : 'tests - graphics pipeline' }
VkBindingsTest >> testShaderStageRunGivesBackEveryEntryPointItAllocated [
	"Each stage is the record of where its entry point string is, so giving the strings back
	 nulls the fields as it goes: a freed address left in a stage could be read or freed twice.
	 The run itself is freed afterwards, through its first element."

	| stages |
	stages := VkGraphicsPipeline
		          shaderStagesForVertexModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null)
		          fragmentModule:
		          (VkShaderModule_H fromHandle: ExternalAddress null).
	[
		stages do: [ :each | self deny: each pName isNull ].
		VkGraphicsPipeline freeShaderStageEntryPointsOf: stages.
		stages do: [ :each | self assert: each pName isNull ] ] ensure: [
		VkGraphicsPipeline freeShaderStages: stages ]
]

{ #category : 'tests - graphics pipeline' }
VkBindingsTest >> testShaderStageTabShowsEveryRowTheStageReports [
	"The Stage tab is the stage's report laid out, so it must carry one row per entry the report
	 answers: a value added to the report cannot then stay invisible. Building a table only
	 reads, which is why the report is compared with itself afterwards."

	| stage rows table shown |
	stage := VkPipelineShaderStageCreateInfo
		         exampleStagesOfTheTriangleThisProjectDraws first.
	rows := stage stageRows.
	table := stage inspectorStage: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ].
	self assert: stage stageRows equals: rows
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
VkBindingsTest >> testSwapchainCreateInfoInitializesOnlyWhatIsConstantForTheType [
	"The structure type is the only field fixed by the type. The present mode, the composite
	 alpha and the layer count are the same for every swapchain this project creates, but each
	 is a caller's choice rather than a property of the structure, and the extent is nested by
	 value, so an initializer writing anything else would write through to a nested store on
	 every read."

	| info setters |
	info := VkSwapchainCreateInfoKHR externalInstance.
	[
	self assert: info sType equals: VkStructureType swapchainCreateInfoKHR ]
		ensure: [ info getHandle free ].
	setters := (VkSwapchainCreateInfoKHR >> #initializeConstantFields) messages
		           select: [ :each |
		           VkSwapchainCreateInfoKHR includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSwapchainCreateInfoLayoutMatchesTheCLayout [
	"The request vkCreateSwapchainKHR reads: the chain header, the flags, the surface, how many
	 images and in which format and colour space, the extent by value, the layers, the usage,
	 the sharing mode and queue families, the transform and composite alpha to present with,
	 the present mode, whether obscured pixels may be discarded, and the swapchain this one
	 replaces. Both handles are pointer wide, and uFFI pads after the queue family count and
	 after the clipped flag, which rounds the request to a hundred and four bytes."

	| rows |
	rows := VkSwapchainCreateInfoKHR layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #surface #minImageCount #imageFormat
		           #imageColorSpace #imageExtent #imageArrayLayers #imageUsage
		           #imageSharingMode #queueFamilyIndexCount
		           #pQueueFamilyIndices #preTransform #compositeAlpha
		           #presentMode #clipped #oldSwapchain ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 24 32 36 40 44 52 56 60 64 72 80 84 88 92 96 ).
	self assert: VkSwapchainCreateInfoKHR byteSize equals: 104.
	self
		assert: (rows detect: [ :each | each first = #imageExtent ]) third
		equals: VkExtent2D byteSize
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSwapchainCreationWritesNoScalarFieldAtAHandCountedOffset [
	"Both structures a swapchain writes are declared, so no method may write either at a
	 counted offset. What is left is named, and none of it is a structure: the out parameter a
	 creation answers through, the image index an acquire is given, the count and the run of
	 image handles the driver fills, and the two runs of one entry a present request points
	 at."

	| banned offenders |
	banned := #( #unsignedLongAt: #unsignedLongAt:put: #unsignedShortAt:
	             #unsignedShortAt:put: #unsignedLongLongAt:
	             #unsignedLongLongAt:put: #signedLongAt: #signedLongAt:put:
	             #floatAt: #floatAt:put: #pointerAt: #pointerAt:put: ).
	offenders := (VkSwapchain methods , VkSwapchain class methods) select: [
		             :method |
		             method messages anySatisfy: [ :each |
			             banned includes: each ] ].
	self
		assert: (offenders collect: [ :each |
				 each methodClass name asString , ' >> ' , each selector ])
				asSortedCollection asArray
		equals: #( 'VkSwapchain >> acquireNextImage:fence:'
			           'VkSwapchain >> imagesFromDriver'
			           'VkSwapchain class >> handleForCreateInfo:on:'
			           'VkSwapchain class >> runOfOneHandle:'
			           'VkSwapchain class >> runOfOneImageIndex:' )
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

{ #category : 'tests - layout' }
VkBindingsTest >> testSwapchainRequestAsksForWhatTheSurfaceReported [
	"What the builder writes, with no device in reach: the surface's own transform, the pair it
	 offered, the image count the rule asks for, and the extent given. The exclusive sharing
	 mode, the flags, both queue family fields and the old swapchain are the zeros a fresh
	 block holds, so none is written and each is asserted through its constant class or as a
	 null. The surface handle is null here because a surface needs a display; what matters is
	 that the request carries the handle it was given."

	| capabilities surfaceFormat info |
	capabilities := VkSurfaceCapabilitiesKHR
		                exampleCapabilitiesAWindowSurfaceMightReport.
	surfaceFormat := VkSurfaceFormatKHR exampleFormatAWindowSurfaceMightReport.
	info := VkSwapchain
		        createInfoForSurface: VkSwapchainCreateInfoKHR exampleSurfaceHandle
		        format: surfaceFormat
		        capabilities: capabilities
		        extent: VkImage exampleExtent.
	[
		self assert: info sType equals: VkStructureType swapchainCreateInfoKHR.
		self assert: info flags equals: 0.
		self
			assert: info minImageCount
			equals: (VkSwapchain imageCountFor: capabilities).
		self assert: info imageFormat equals: surfaceFormat format.
		self assert: info imageColorSpace equals: surfaceFormat colorSpace.
		self assert: info imageExtent width equals: VkImage exampleExtent x.
		self assert: info imageExtent height equals: VkImage exampleExtent y.
		self assert: info imageArrayLayers equals: VkImage arrayLayerCount.
		self assert: info imageUsage equals: VkImageUsage colorAttachmentBit.
		self
			assert: info imageSharingMode
			equals: VkRenderConfig sharingModeExclusive.
		self assert: info queueFamilyIndexCount equals: 0.
		self assert: info pQueueFamilyIndices isNull.
		self assert: info preTransform equals: capabilities currentTransform.
		self assert: info compositeAlpha equals: VkCompositeAlpha opaqueBit.
		self assert: info presentMode equals: VkRenderConfig presentModeFifo.
		self assert: info clipped equals: VkSwapchain clipObscuredPixels.
		self assert: info oldSwapchain isNull ] ensure: [ info getHandle free ]
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSwapchainRequestExampleIsTheRequestTheProjectMakes [
	"The example is built by the one builder the creation path uses, so it reports exactly what
	 a real creation would ask of a surface with these capabilities. It lives in object memory,
	 so reading it frees nothing and a click in the browser leaks nothing."

	| example built rows |
	example := VkSwapchainCreateInfoKHR exampleRequestForAWindowSurface.
	built := VkSwapchain
		         createInfoForSurface: VkSwapchainCreateInfoKHR exampleSurfaceHandle
		         format: VkSurfaceFormatKHR exampleFormatAWindowSurfaceMightReport
		         capabilities:
		         VkSurfaceCapabilitiesKHR
			         exampleCapabilitiesAWindowSurfaceMightReport
		         extent: VkImage exampleExtent.
	rows := [ built swapchainRows ] ensure: [ built getHandle free ].
	self assert: example swapchainRows equals: rows.
	self assert: example getHandle isExternalAddress not
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSwapchainRequestRowsNameTheFormatTheTransformAndThePresentMode [
	"What the Swapchain tab reads. Every value is named through its constant class rather than
	 restated, and the surface and old swapchain are reported as set or not because their
	 addresses say nothing to a reader. Read only, so the tab leaves the store alone."

	| info rows |
	info := VkSwapchain
		        createInfoForSurface: VkSwapchainCreateInfoKHR exampleSurfaceHandle
		        format: VkSurfaceFormatKHR exampleFormatAWindowSurfaceMightReport
		        capabilities:
		        VkSurfaceCapabilitiesKHR
			        exampleCapabilitiesAWindowSurfaceMightReport
		        extent: VkImage exampleExtent.
	rows := [ info swapchainRows ] ensure: [ info getHandle free ].
	self assert: (rows at: #formatName) equals: 'b8g8r8a8Unorm'.
	self assert: (rows at: #colorSpaceName) equals: 'srgbNonlinearKHR'.
	self assert: (rows at: #extent) equals: VkImage exampleExtent.
	self assert: (rows at: #preTransformNames) equals: 'Identity'.
	self assert: (rows at: #compositeAlphaNames) equals: 'Opaque'.
	self assert: (rows at: #presentModeName) equals: 'presentModeFifo'.
	self
		assert: (rows at: #usageNames)
		equals: (VkImageUsage nameForFlags: VkImageUsage colorAttachmentBit).
	self assert: (rows at: #discardsObscuredPixels).
	self deny: (rows at: #surfaceSet).
	self deny: (rows at: #replacesASwapchain).
	self deny: (rows at: #sharedBetweenQueueFamilies)
]

{ #category : 'tests - layout' }
VkBindingsTest >> testSwapchainRequestTabShowsEveryRowTheRequestReports [
	"The Swapchain tab is the report laid out, so it must carry one row per entry
	 swapchainRows answers: a value added to the report cannot then stay invisible. Building
	 the table only reads, which is why the report is compared with itself afterwards."

	| example rows table shown |
	example := VkSwapchainCreateInfoKHR exampleRequestForAWindowSurface.
	rows := example swapchainRows.
	table := example inspectorSwapchain: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :each | self assert: (shown includes: each) ].
	self assert: example swapchainRows equals: rows
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

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexDescriptionRowsNameTheRateAndTheFormat [
	"Both descriptions hold numbers that mean something in Vulkan's terms: the rate a buffer
	 advances at and the format of one attribute. Each is named through its constant class
	 rather than through a table a view keeps, so a row cannot name something the constants do
	 not."

	| binding attribute bindingRows attributeRows |
	binding := VkGraphicsPipeline vertexBindingDescriptions first.
	attribute := VkGraphicsPipeline vertexAttributeDescriptions first.
	bindingRows := binding bindingRows.
	attributeRows := attribute attributeRows.
	self
		assert: (bindingRows at: #inputRateName)
		equals: (VkVertexInputRate nameForValue: VkVertexInputRate perVertex)
				asString.
	self assert: (bindingRows at: #stride) equals: binding stride.
	self
		assert: (attributeRows at: #formatName)
		equals: (VkFormat nameForValue: VkFormat r32g32Sfloat) asString.
	self assert: (attributeRows at: #location) equals: attribute location
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexInputExamplesAreTheDescriptionsTheProjectDraws [
	"Each example is what this project really hands the driver, rebuilt on every call. The two
	 descriptions live in object memory, so a click frees nothing. The state example keeps a
	 copy with both runs freed and both fields nulled, so it says the runs are not there rather
	 than pointing at memory that has gone, and both counts survive the copy."

	| binding attribute state |
	binding := VkVertexInputBindingDescription
		           exampleBindingOfTheVertexThisProjectDraws.
	attribute := VkVertexInputAttributeDescription
		             examplePositionAttributeOfTheVertexThisProjectDraws.
	self
		assert: binding stride
		equals: VkGraphicsPipeline vertexBindingDescriptions first stride.
	self assert: attribute format equals: VkFormat r32g32Sfloat.
	state := VkPipelineVertexInputStateCreateInfo
		         exampleStateOfTheVertexThisProjectDraws.
	self
		assert: state sType
		equals: VkStructureType pipelineVertexInputStateCreateInfo.
	self
		assert: state vertexBindingDescriptionCount
		equals: VkGraphicsPipeline vertexBindingDescriptions size.
	self
		assert: state vertexAttributeDescriptionCount
		equals: VkGraphicsPipeline vertexAttributeDescriptions size.
	self assert: state pVertexBindingDescriptions isNull.
	self assert: state pVertexAttributeDescriptions isNull.
	self assert: state pNext isNull
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexInputLayoutsMatchTheCLayout [
	"Three structures: a binding description says how wide one vertex is, an attribute
	 description says where one value sits inside it, and the state structure points at a run of
	 each. Both descriptions are plain uint32 quartets with no chain header, twelve and sixteen
	 bytes. The state structure pads after the flags and count pair so the first run pointer
	 lands on a pointer boundary, which makes it forty-eight bytes."

	| bindingRows attributeRows stateRows |
	bindingRows := VkVertexInputBindingDescription layoutRows.
	self
		assert: (bindingRows collect: [ :each | each first ]) asArray
		equals: #( #binding #stride #inputRate ).
	self
		assert: (bindingRows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 ).
	self assert: VkVertexInputBindingDescription byteSize equals: 12.
	attributeRows := VkVertexInputAttributeDescription layoutRows.
	self
		assert: (attributeRows collect: [ :each | each first ]) asArray
		equals: #( #location #binding #format #offset ).
	self
		assert: (attributeRows collect: [ :each | each second ]) asArray
		equals: #( 0 4 8 12 ).
	self assert: VkVertexInputAttributeDescription byteSize equals: 16.
	stateRows := VkPipelineVertexInputStateCreateInfo layoutRows.
	self
		assert: (stateRows collect: [ :each | each first ]) asArray
		equals:
			#( #sType #pNext #flags #vertexBindingDescriptionCount
			   #pVertexBindingDescriptions #vertexAttributeDescriptionCount
			   #pVertexAttributeDescriptions ).
	self
		assert: (stateRows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 40 ).
	self assert: VkPipelineVertexInputStateCreateInfo byteSize equals: 48
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexInputRowsNameTheCountsAndSayWhichRunsAreThere [
	"The rows the Vertex input tab reads: how many of each description the state names, and
	 whether each run is there. A row never follows a run — a freed run would be read through a
	 pointer the structure no longer owns — so the rows say a run is given rather than what it
	 holds."

	| state rows |
	state := VkGraphicsPipeline
		         vertexInputStateForBindings:
		         VkGraphicsPipeline vertexBindingDescriptions
		         attributes: VkGraphicsPipeline vertexAttributeDescriptions.
	rows := [ state vertexInputRows ] ensure: [
		        VkGraphicsPipeline freeVertexInputState: state ].
	self
		assert: (rows at: #vertexBindingDescriptionCount)
		equals: VkGraphicsPipeline vertexBindingDescriptions size.
	self
		assert: (rows at: #vertexAttributeDescriptionCount)
		equals: VkGraphicsPipeline vertexAttributeDescriptions size.
	self assert: (rows at: #bindingRunGiven).
	self assert: (rows at: #attributeRunGiven)
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexInputStateInitializesOnlyWhatIsConstantForTheType [
	"The state structure's type is fixed by its type; both counts and both run pointers are a
	 caller's choice. Neither description carries a chain header, so neither has anything
	 constant for its type, and neither may declare an initializer: each is pointed at from a
	 structure whose getter would run initialize over it."

	| state setters |
	state := VkPipelineVertexInputStateCreateInfo externalInstance.
	[
	self
		assert: state sType
		equals: VkStructureType pipelineVertexInputStateCreateInfo ] ensure: [
		state getHandle free ].
	setters := (VkPipelineVertexInputStateCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkPipelineVertexInputStateCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: ).
	#( #VkVertexInputBindingDescription
	   #VkVertexInputAttributeDescription ) do: [ :each |
		self deny:
			((Smalltalk at: each) includesSelector: #initializeConstantFields).
		self deny: ((Smalltalk at: each) includesSelector: #sType:) ]
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexInputStateNamesOneRunOfEachDescription [
	"What the one builder writes, read back through the declared fields and through the runs it
	 points at. A builder is a function of its arguments, so no device is needed. Each count is
	 the size of the collection it was given, and each run holds those descriptions in order at
	 the declared stride, which is what the driver reads."

	| state bindings attributes firstAttribute |
	bindings := VkGraphicsPipeline vertexBindingDescriptions.
	attributes := VkGraphicsPipeline vertexAttributeDescriptions.
	state := VkGraphicsPipeline
		         vertexInputStateForBindings: bindings
		         attributes: attributes.
	[
	self
		assert: state vertexBindingDescriptionCount
		equals: bindings size.
	self
		assert: state vertexAttributeDescriptionCount
		equals: attributes size.
	self deny: state pVertexBindingDescriptions isNull.
	self deny: state pVertexAttributeDescriptions isNull.
	self
		assert: (VkVertexInputBindingDescription fromHandle:
				 state pVertexBindingDescriptions getHandle) stride
		equals: bindings first stride.
	firstAttribute := VkVertexInputAttributeDescription fromHandle:
		                  state pVertexAttributeDescriptions getHandle.
	self assert: firstAttribute format equals: attributes first format.
	self
		assert: (VkVertexInputAttributeDescription fromHandle:
				 state pVertexAttributeDescriptions getHandle
				 + VkVertexInputAttributeDescription byteSize) offset
		equals: (attributes at: 2) offset ] ensure: [
		VkGraphicsPipeline freeVertexInputState: state ]
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexInputTabsShowEveryRowTheirReportsAnswer [
	"Each of the three tabs is its report laid out, so each must carry one row per entry the
	 report answers: a value added to a report cannot then stay invisible. Building a table only
	 reads, which is why each report is compared with itself afterwards."

	| pairs |
	pairs := {
		         { VkPipelineVertexInputStateCreateInfo
			         exampleStateOfTheVertexThisProjectDraws.
		         #vertexInputRows.
		         #inspectorVertexInput: }.
		         { VkVertexInputBindingDescription
			         exampleBindingOfTheVertexThisProjectDraws.
		         #bindingRows.
		         #inspectorBinding: }.
		         { VkVertexInputAttributeDescription
			         examplePositionAttributeOfTheVertexThisProjectDraws.
		         #attributeRows.
		         #inspectorAttribute: } }.
	pairs do: [ :each |
		| example rows table shown |
		example := each first.
		rows := example perform: each second.
		table := example perform: each third with: SpPresenter new.
		self assert: table items size equals: rows size.
		shown := table items collect: [ :item | item second ].
		rows valuesDo: [ :value | self assert: (shown includes: value) ].
		self assert: (example perform: each second) equals: rows ]
]

{ #category : 'tests - vertex input' }
VkBindingsTest >> testVertexLayoutDescribesAPositionAndAColourInOneVertex [
	"The vertex layout this project draws with: one buffer, advanced per vertex, holding a
	 two-float position followed by a three-float colour. The stride is derived from the two
	 attributes rather than written again, so a format changed on one side cannot leave the
	 stride naming a width no vertex has."

	| bindings attributes |
	bindings := VkGraphicsPipeline vertexBindingDescriptions.
	attributes := VkGraphicsPipeline vertexAttributeDescriptions.
	self assert: bindings size equals: 1.
	self
		assert: bindings first binding
		equals: VkGraphicsPipeline vertexBufferBinding.
	self
		assert: bindings first stride
		equals:
		VkGraphicsPipeline positionByteCount
		+ VkGraphicsPipeline colourByteCount.
	self
		assert: bindings first inputRate
		equals: VkVertexInputRate perVertex.
	self assert: attributes size equals: 2.
	self
		assert: (attributes collect: [ :each | each location ]) asArray
		equals: {
				VkGraphicsPipeline positionLocation.
				VkGraphicsPipeline colourLocation }.
	self
		assert: (attributes collect: [ :each | each format ]) asArray
		equals: {
				VkFormat r32g32Sfloat.
				VkFormat r32g32b32Sfloat }.
	self
		assert: (attributes collect: [ :each | each offset ]) asArray
		equals: { 0. VkGraphicsPipeline positionByteCount }.
	self
		assert: (attributes collect: [ :each | each binding ]) asArray
		equals: (Array new: 2 withAll: VkGraphicsPipeline vertexBufferBinding)
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

{ #category : 'tests - viewport' }
VkBindingsTest >> testViewportRowsSayBothRectanglesComeFromTheCommandBuffer [
	"The rows the Viewport tab reads: a count for each rectangle kind and no run for either,
	 which is what a dynamic rectangle looks like in the state."

	| state rows |
	state := VkGraphicsPipeline viewportState.
	rows := [ state viewportRows ] ensure: [ state getHandle free ].
	self
		assert: (rows at: #viewportCount)
		equals: VkGraphicsPipeline viewportsPerPipeline.
	self
		assert: (rows at: #scissorCount)
		equals: VkGraphicsPipeline scissorsPerPipeline.
	self deny: (rows at: #viewportRunGiven).
	self deny: (rows at: #scissorRunGiven)
]

{ #category : 'tests - viewport' }
VkBindingsTest >> testViewportStateCountsOneOfEachAndPointsAtNeither [
	"One viewport and one scissor rectangle, and no run of either: that pair is how a dynamic
	 rectangle is declared, and the command buffer sets both while it records."

	| state |
	state := VkGraphicsPipeline viewportState.
	[		
		self
			assert: state viewportCount
			equals: VkGraphicsPipeline viewportsPerPipeline.
		self
			assert: state scissorCount
			equals: VkGraphicsPipeline scissorsPerPipeline.
		self assert: state pViewports isNull.
		self assert: state pScissors isNull ] ensure: [
		state getHandle free ]
]

{ #category : 'tests - viewport' }
VkBindingsTest >> testViewportStateExampleAndTabAgree [
	"The example is the state the project draws with, kept in object memory so it reads after
	 the external store has gone, and the tab carries one row per entry the report answers."

	| state rows table shown |
	state := VkPipelineViewportStateCreateInfo
		         exampleStateOfTheDynamicViewportThisProjectUses.
	rows := state viewportRows.
	self
		assert: state viewportCount
		equals: VkGraphicsPipeline viewportsPerPipeline.
	table := state inspectorViewport: SpPresenter new.
	self assert: table items size equals: rows size.
	shown := table items collect: [ :each | each second ].
	rows valuesDo: [ :value | self assert: (shown includes: value) ].
	self assert: state viewportRows equals: rows
]

{ #category : 'tests - viewport' }
VkBindingsTest >> testViewportStateInitializesOnlyWhatIsConstantForTheType [
	"The structure type is fixed by the type; the counts and the runs are a caller's choice, so
	 the initializer stamps the type alone."

	| state setters |
	state := VkPipelineViewportStateCreateInfo externalInstance.
	[	self
		assert: state sType
		equals: VkStructureType pipelineViewportStateCreateInfo ] ensure: [
		state getHandle free ].
	setters := (VkPipelineViewportStateCreateInfo
		            >> #initializeConstantFields) messages select: [ :each |
		           VkPipelineViewportStateCreateInfo includesSelector: each ].
	self assert: setters asArray equals: #( #sType: )
]

{ #category : 'tests - viewport' }
VkBindingsTest >> testViewportStateLayoutMatchesTheCLayout [
	"A count and a run pointer per rectangle kind: the counts at twenty and thirty-two, the
	 pointers at twenty-four and forty, which makes forty-eight bytes."

	| rows |
	rows := VkPipelineViewportStateCreateInfo layoutRows.
	self
		assert: (rows collect: [ :each | each first ]) asArray
		equals: #( #sType #pNext #flags #viewportCount #pViewports
		   #scissorCount #pScissors ).
	self
		assert: (rows collect: [ :each | each second ]) asArray
		equals: #( 0 8 16 20 24 32 40 ).
	self assert: VkPipelineViewportStateCreateInfo byteSize equals: 48
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
