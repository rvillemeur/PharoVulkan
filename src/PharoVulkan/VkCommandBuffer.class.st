"
Wrapper around a VkCommandBuffer_H. Records Vulkan commands inside a do: block. Key methods: do:, begin, end, dispatch:y:z:, bindComputePipeline:, bindDescriptorSets:pipelineLayout:, draw:.
"
Class {
	#name : 'VkCommandBuffer',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'pool',
		'level'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'constants' }
VkCommandBuffer class >> barriersPerDependency [
	"One dependency carries one memory barrier here: every barrier this project records is a
	 single global one, never a list and never a per-buffer or per-image barrier."

	^ 1
]

{ #category : 'constants' }
VkCommandBuffer class >> clearComponentByteCount [
	"A clear colour component is a float, and the clear values are a union of arrays rather than
	 a declared structure, so there is no field specification to read a width from and the
	 stride is named here."

	^ 4
]

{ #category : 'constants' }
VkCommandBuffer class >> clearComponentCount [
	"Four components per clear colour, in the order Vulkan reads them."

	^ 4
]

{ #category : 'recording' }
VkCommandBuffer class >> clearValuesOutsideObjectMemory: anArray [
	"The clear values a pass loads with, as r, g, b, a floats in nought to one. A clear value is
	 a union of arrays, which uFFI in this image cannot declare, so this is a block with no
	 field specification and the stride is the named one. The caller owns the block and must
	 free it. The components are numbers rather than a Color, so this layer stays independent of
	 the image format's channel order."

	| values |
	values := ExternalAddress allocate:
		          self clearValuesPerPass * self clearComponentCount
		          * self clearComponentByteCount.
	1 to: self clearComponentCount do: [ :index |
		values
			floatAt: index - 1 * self clearComponentByteCount + 1
			put: (anArray at: index) asFloat ].
	^ values
]

{ #category : 'constants' }
VkCommandBuffer class >> clearValuesPerPass [
	"One clear value per pass: every render pass in this project has a single colour attachment
	 and no depth attachment, so the load operation reads one value."

	^ 1
]

{ #category : 'constants' }
VkCommandBuffer class >> copyDepth [
	"A two dimensional image is one texel deep, and Vulkan rejects a copy extent with a zero
	 depth, so the depth is written where the width and the height come from the caller."

	^ 1
]

{ #category : 'recording' }
VkCommandBuffer class >> dependencyForBarrier: aMemoryBarrier [
	"The dependency info that carries one memory barrier and nothing else. The caller owns the
	 block and must free its handle; the barrier must outlive the recording call, because the
	 driver reads it through the pointer written here."

	| info |
	info := VkDependencyInfo externalInstance.
	^ info
		  memoryBarrierCount: self barriersPerDependency;
		  pMemoryBarriers: aMemoryBarrier getHandle;
		  yourself
]

{ #category : 'examples' }
VkCommandBuffer class >> exampleBufferFromTheComputePoolOnThisMachine [
	"One click: the primary command buffer a compute dispatch here records into, cut from a
	 pool on this machine's compute queue family. The pool is destroyed with its context, which
	 frees the buffer with it, so the Buffer tab shows the level and the family it was
	 allocated with over a handle it reports as dead. Where no device is available it answers
	 an unallocated buffer, which is what the inspector should show on such a machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ self new ].
	^ [
	  | pool |
	  pool := context device createCommandPool: context computeQueueFamily.
	  [ pool allocateBuffer ] ensure: [ pool destroy ] ] ensure: [
		  context destroy ]
]

{ #category : 'recording' }
VkCommandBuffer class >> hostReadBarrier [
	"The barrier a recording needs before the host reads what the device wrote: everything a
	 transfer stage has written becomes visible to a host read. The caller owns the block and
	 must free its handle. Answering the structure rather than writing it in place is what lets
	 the Barrier tab show the masks the recorder really uses."

	| barrier |
	barrier := VkMemoryBarrier2 externalInstance.
	^ barrier
		  srcStageMask: VkPipelineStage2 allTransferBit;
		  srcAccessMask: VkAccess2 transferWriteBit;
		  dstStageMask: VkPipelineStage2 hostBit;
		  dstAccessMask: VkAccess2 hostReadBit;
		  yourself
]

{ #category : 'constants' }
VkCommandBuffer class >> layersPerCopy [
	"One array layer per readback: every image this project copies back is a single layer."

	^ 1
]

{ #category : 'factory' }
VkCommandBuffer class >> on: aHandle pool: aPool level: aLevel [
	^ self new initializeWith: aHandle pool: aPool level: aLevel
]

{ #category : 'constants' }
VkCommandBuffer class >> recordingFlags [
	"Every recording here is submitted once and then re-recorded, so the driver is told to keep
	 nothing for a resubmission."

	^ VkCommandBufferUsageFlag oneTimeSubmitBit
]

{ #category : 'recording' }
VkCommandBuffer class >> regionForExtent: aPoint [
	"The region a whole-image readback copies: the colour aspect of the first mip level, one
	 layer, and the extent the caller gives at a depth of one. The caller owns the block and
	 must free its handle. Everything not written here — the buffer offset, the row packing, the
	 mip level, the array layer and the image offset — is the zero a fresh block already holds,
	 and a zero row length and image height are what ask the driver for tightly packed rows of
	 exactly the width, which is what the host side indexes by."

	| region |
	region := VkBufferImageCopy externalInstance.
	region imageSubresource
		aspectMask: VkImageAspect colorBit;
		layerCount: self layersPerCopy.
	region imageExtent
		width: aPoint x;
		height: aPoint y;
		depth: self copyDepth.
	^ region
]

{ #category : 'constants' }
VkCommandBuffer class >> regionsPerCopy [
	"One region per readback: the whole image is copied in one go, never in tiles."

	^ 1
]

{ #category : 'recording' }
VkCommandBuffer class >> renderPassBeginInfoFor: aRenderPassHandle framebuffer: aFramebufferHandle extent: aPoint clearValues: aClearValueBlock [
	"The begin info a pass opens with: which pass runs over which framebuffer, the whole extent
	 of the attachments starting at their corner, and the one clear value the load operation
	 reads. The caller owns the block and must free its handle; the clear values must outlive
	 the recording call, because the driver reads them through the pointer written here. The
	 render area's offset is the zero a fresh block already holds."

	| info |
	info := VkRenderPassBeginInfo externalInstance.
	info
		renderPass: aRenderPassHandle;
		framebuffer: aFramebufferHandle;
		clearValueCount: self clearValuesPerPass;
		pClearValues: aClearValueBlock.
	info renderArea extent
		width: aPoint x;
		height: aPoint y.
	^ info
]

{ #category : 'constants' }
VkCommandBuffer class >> subpassContents [
	"Every subpass in this project is recorded in the buffer that begins the pass, because the
	 pool allocates primary buffers only."

	^ VkSubpassContents inline
]

{ #category : 'recording' }
VkCommandBuffer >> barrierForHostRead [
	"Records the transfer to host barrier. It is needed because submit:andWait: waits with
	 vkQueueWaitIdle rather than with a fence, which orders the work but makes nothing visible
	 to a host read on its own."

	| barrier |
	barrier := self class hostReadBarrier.
	[ self recordBarrier: barrier ] ensure: [ barrier getHandle free ]
]

{ #category : 'accessing' }
VkCommandBuffer >> barrierRows [
	"What the host read barrier really says, sampled off the structures the recorder builds
	 rather than restated here: the four masks with the names of their bits, and the counts of
	 the dependency that carries them. The structures are built and freed on every call, so
	 reading the rows records nothing and changes nothing."

	| barrier info |
	barrier := self class hostReadBarrier.
	^ [
	  info := self class dependencyForBarrier: barrier.
	  [
	  Dictionary newFrom: {
			  (#srcStageMask -> barrier srcStageMask).
			  (#srcStageNames
			   -> (VkPipelineStage2 nameForFlags: barrier srcStageMask)).
			  (#srcAccessMask -> barrier srcAccessMask).
			  (#srcAccessNames
			   -> (VkAccess2 nameForFlags: barrier srcAccessMask)).
			  (#dstStageMask -> barrier dstStageMask).
			  (#dstStageNames
			   -> (VkPipelineStage2 nameForFlags: barrier dstStageMask)).
			  (#dstAccessMask -> barrier dstAccessMask).
			  (#dstAccessNames
			   -> (VkAccess2 nameForFlags: barrier dstAccessMask)).
			  (#dependencyFlags -> info dependencyFlags).
			  (#memoryBarrierCount -> info memoryBarrierCount).
			  (#bufferMemoryBarrierCount -> info bufferMemoryBarrierCount).
			  (#imageMemoryBarrierCount -> info imageMemoryBarrierCount) } ]
		  ensure: [ info getHandle free ] ] ensure: [ barrier getHandle free ]
]

{ #category : 'recording' }
VkCommandBuffer >> begin [
	"Opens the recording. The request is freed whichever way the call goes, and the call itself
	 is a separate method so the one sender of vkBeginCommandBuffer is a method of its own."

	| info |
	info := VkCommandBufferBeginInfo externalInstance.
	[
	info flags: self class recordingFlags.
	self beginRecordingWith: info ] ensure: [ info getHandle free ]
]

{ #category : 'recording' }
VkCommandBuffer >> beginRecordingWith: aBeginInfo [
	Vk checkResult:
		(Vk beginCommandBuffer: handle beginInfo: aBeginInfo getHandle)
]

{ #category : 'recording' }
VkCommandBuffer >> beginRenderPass: aRenderPass framebuffer: aFramebuffer extent: aPoint [
	"Kept so the window path reads unchanged: it never asked for a clear colour."

	^ self
		  beginRenderPass: aRenderPass
		  framebuffer: aFramebuffer
		  extent: aPoint
		  clearColor: VkRenderConfig clearColorBlackOpaque
]

{ #category : 'recording' }
VkCommandBuffer >> beginRenderPass: aRenderPass framebuffer: aFramebuffer extent: aPoint clearColor: anArray [
	"Opens the pass. The clear values live outside the begin info, so they are allocated first
	 and freed last: the driver follows the pointer to them while the pass is being recorded."

	| values |
	values := self class clearValuesOutsideObjectMemory: anArray.
	[
	| info |
	info := self class
		        renderPassBeginInfoFor: aRenderPass handle
		        framebuffer: aFramebuffer handle
		        extent: aPoint
		        clearValues: values.
	[ self recordRenderPassBeginWith: info ] ensure: [ info getHandle free ] ]
		ensure: [ values free ]
]

{ #category : 'recording' }
VkCommandBuffer >> bindComputePipeline: aPipeline [
    "VK_PIPELINE_BIND_POINT_COMPUTE = 1"
    Vk cmdBindPipeline: handle pipelineBindPoint: 1 pipeline: aPipeline handle
]

{ #category : 'recording' }
VkCommandBuffer >> bindDescriptorSets: setsArray pipelineLayout: aLayout [
    "VK_PIPELINE_BIND_POINT_COMPUTE = 1"
    | setsBuf |
    setsBuf := ExternalAddress allocate: setsArray size * 8.
    [ setsArray doWithIndex: [ :set :i |
        setsBuf pointerAt: (i - 1) * 8 + 1 put: set handle getHandle ].
      Vk cmdBindDescriptorSets: handle
          pipelineBindPoint: 1
          layout: aLayout handle
          firstSet: 0
          descriptorSetCount: setsArray size
          pDescriptorSets: setsBuf
          dynamicOffsetCount: 0
          pDynamicOffsets: ExternalAddress null
    ] ensure: [ setsBuf free ]
]

{ #category : 'binding' }
VkCommandBuffer >> bindGraphicsPipeline: aPipeline [
    Vk cmdBindPipeline: handle pipelineBindPoint: 0 pipeline: aPipeline handle
]

{ #category : 'binding' }
VkCommandBuffer >> bindVertexBuffer: aVkBuffer [
    | pBufs pOffsets |
    pBufs := ExternalAddress allocate: 8.
    [ pOffsets := ExternalAddress allocate: 8.
      [ pBufs pointerAt: 1 put: aVkBuffer handle getHandle.
        pOffsets unsignedLongLongAt: 1 put: 0.
        Vk cmdBindVertexBuffers: handle firstBinding: 0 bindingCount: 1 pBuffers: pBufs pOffsets: pOffsets
      ] ensure: [ pOffsets free ]
    ] ensure: [ pBufs free ]
]

{ #category : 'accessing' }
VkCommandBuffer >> bufferRows [
	"What the buffer was allocated with and what it records under: the level and its name, the
	 queue family the pool it came from serves, the recording flags every recording in this
	 project asks for with their names, and whether the handle is still usable. A buffer is
	 freed with the pool it was cut from and the driver leaves the handle reading as non-null,
	 so liveness asks the pool as well, and a buffer that was never allocated has no pool to
	 ask. The rows are built fresh on every call, so reading them cannot change the buffer."

	^ Dictionary newFrom: {
			  (#level -> level).
			  (#levelName -> (VkCommandBufferLevel nameForValue: level)).
			  (#queueFamilyIndex
			   -> (pool ifNotNil: [ :each | each poolRows at: #queueFamilyIndex ])).
			  (#recordingFlags -> self class recordingFlags).
			  (#recordingFlagNames
			   -> (VkCommandBufferUsageFlag nameForFlags: self class recordingFlags)).
			  (#live -> (handle isNotNil and: [
				    handle isNull not and: [
					    pool isNotNil and: [ pool poolRows at: #live ] ] ])) }
]

{ #category : 'recording' }
VkCommandBuffer >> copyImage: anImage layout: layout toBuffer: aBuffer extent: aPoint [
	"Records the whole-image readback. The region is built by the class, so the Copy tab and
	 this recording are shown the same structure."

	| region |
	region := self class regionForExtent: aPoint.
	[
	self
		recordCopyOf: anImage
		layout: layout
		toBuffer: aBuffer
		region: region ] ensure: [ region getHandle free ]
]

{ #category : 'recording' }
VkCommandBuffer >> dispatch: x y: y z: z [
    Vk cmdDispatch: handle groupCountX: x groupCountY: y groupCountZ: z
]

{ #category : 'recording' }
VkCommandBuffer >> do: aBlock [
    self begin.
    aBlock value: self.
    self end
]

{ #category : 'drawing' }
VkCommandBuffer >> draw: vertexCount [
    Vk cmdDraw: handle vertexCount: vertexCount instanceCount: 1 firstVertex: 0 firstInstance: 0
]

{ #category : 'recording' }
VkCommandBuffer >> end [
    Vk checkResult: (Vk endCommandBuffer: handle)
]

{ #category : 'rendering' }
VkCommandBuffer >> endRenderPass [
    Vk cmdEndRenderPass: handle
]

{ #category : 'accessing' }
VkCommandBuffer >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkCommandBuffer >> initialize [
	"A buffer that was never allocated still answers its rows, so the level reads as the one
	 the allocate info would have asked for rather than as nil."

	super initialize.
	level := VkCommandPool allocationLevel
]

{ #category : 'initialization' }
VkCommandBuffer >> initializeWith: aHandle pool: aPool level: aLevel [
	"The level is kept because the driver answers it back no more than it answers the pool's
	 queue family: it is only ever what the allocate info asked for."

	handle := aHandle.
	pool := aPool.
	level := aLevel
]

{ #category : 'inspector' }
VkCommandBuffer >> inspectorBarrier: aBuilder [
	"The barrier this buffer records before a host read, read off the structures the recorder
	 builds: what it waits on, what it makes visible, and how many barriers of each kind the
	 dependency carries. The structures are built and freed while the rows are gathered, so
	 opening the tab records nothing into the buffer."

	<inspectorPresentationOrder: 40 title: 'Barrier'>
	| rows |
	rows := self barrierRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Waits on stage'. (rows at: #srcStageNames) }.
				  { 'Waits on access'. (rows at: #srcAccessNames) }.
				  { 'Visible to stage'. (rows at: #dstStageNames) }.
				  { 'Visible to access'. (rows at: #dstAccessNames) }.
				  { 'Memory barriers'. (rows at: #memoryBarrierCount) }.
				  { 'Buffer barriers'. (rows at: #bufferMemoryBarrierCount) }.
				  { 'Image barriers'. (rows at: #imageMemoryBarrierCount) } };
		  yourself
]

{ #category : 'inspector' }
VkCommandBuffer >> inspectorBuffer: aBuilder [
	"What the buffer was allocated with and what it records under: the level, named by the
	 constants class that owns the values, the queue family of the pool it came from, the
	 recording flags named by the class that owns the bits, and whether it is still usable. The
	 rows are built fresh, so opening the tab cannot change the buffer."

	<inspectorPresentationOrder: 30 title: 'Buffer'>
	| rows |
	rows := self bufferRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Level'. (rows at: #levelName) }.
				  { 'Queue family'. (rows at: #queueFamilyIndex) }.
				  { 'Recording flags'. (rows at: #recordingFlagNames) }.
				  { 'Usable'. (rows at: #live) } };
		  yourself
]

{ #category : 'recording' }
VkCommandBuffer >> recordBarrier: aMemoryBarrier [
	"The one place a pipeline barrier is recorded. The driver reads the dependency info and the
	 barrier it points at during this call, so the barrier must still be alive here and the
	 dependency is freed only once the call has returned."

	| info |
	info := self class dependencyForBarrier: aMemoryBarrier.
	[ Vk cmdPipelineBarrier2: handle pDependencyInfo: info getHandle ] ensure: [
		info getHandle free ]
]

{ #category : 'recording' }
VkCommandBuffer >> recordCopyOf: anImage layout: layout toBuffer: aBuffer region: aRegion [
	"The one place an image to buffer copy is recorded. The driver reads the region during this
	 call, so it must still be alive here and is freed by whoever built it."

	Vk
		cmdCopyImageToBuffer: handle
		srcImage: anImage handle
		srcImageLayout: layout
		dstBuffer: aBuffer handle
		regionCount: self class regionsPerCopy
		pRegions: aRegion getHandle
]

{ #category : 'recording' }
VkCommandBuffer >> recordRenderPassBeginWith: aBeginInfo [
	"The one place a render pass is opened. The driver reads the begin info and the clear values
	 it points at during this call, so both must still be alive here."

	Vk
		cmdBeginRenderPass: handle
		pRenderPassBegin: aBeginInfo getHandle
		contents: self class subpassContents
]

{ #category : 'setter' }
VkCommandBuffer >> setScissor: aPoint [
    "VkRect2D (16 bytes): 0:offset.x  4:offset.y  8:extent.width  12:extent.height"
    | sc |
    sc := ExternalAddress allocate: 16.
    [ sc unsignedLongAt: 1 put: 0.
      sc unsignedLongAt: 5 put: 0.
      sc unsignedLongAt: 9 put: aPoint x.
      sc unsignedLongAt: 13 put: aPoint y.
      Vk cmdSetScissor: handle firstScissor: 0 scissorCount: 1 pScissors: sc
    ] ensure: [ sc free ]
]

{ #category : 'setter' }
VkCommandBuffer >> setViewport: aPoint [
    "VkViewport (24 bytes): 0:x  4:y  8:width  12:height  16:minDepth  20:maxDepth"
    | vp |
    vp := ExternalAddress allocate: 24.
    [ vp floatAt: 1 put: 0.0.
      vp floatAt: 5 put: 0.0.
      vp floatAt: 9 put: aPoint x asFloat.
      vp floatAt: 13 put: aPoint y asFloat.
      vp floatAt: 17 put: 0.0.
      vp floatAt: 21 put: 1.0.
      Vk cmdSetViewport: handle firstViewport: 0 viewportCount: 1 pViewports: vp
    ] ensure: [ vp free ]
]
