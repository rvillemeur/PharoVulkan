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

{ #category : 'factory' }
VkCommandBuffer class >> on: aHandle pool: aPool level: aLevel [
	^ self new initializeWith: aHandle pool: aPool level: aLevel
]

{ #category : 'recording' }
VkCommandBuffer >> barrierForHostRead [
	"Makes the transfer writes visible to a host read of the destination buffer.
	 It is needed even though submit:andWait: waits for the queue, because that call waits with
	 vkQueueWaitIdle rather than with a fence; the host-read availability the specification
	 grants on fence signal is not what happens here.
	 VkMemoryBarrier2, 48 bytes, 1-based: 1:sType 9:pNext 17:srcStageMask(u64)
	 25:srcAccessMask(u64) 33:dstStageMask(u64) 41:dstAccessMask(u64).
	 VkDependencyInfo, 64 bytes, 1-based: 1:sType 9:pNext 17:dependencyFlags
	 21:memoryBarrierCount 25:pMemoryBarriers 33:bufferMemoryBarrierCount
	 41:pBufferMemoryBarriers 49:imageMemoryBarrierCount 57:pImageMemoryBarriers.
	 The masks are 64-bit in synchronization2, hence unsignedLongLongAt:put:."

	| barrier info |
	barrier := ExternalAddress allocate: 48.
	[
	barrier unsignedLongAt: 1 put: VkStructureType memoryBarrier2.
	barrier pointerAt: 9 put: ExternalAddress null.
	barrier unsignedLongLongAt: 17 put: VkPipelineStage2 allTransferBit.
	barrier unsignedLongLongAt: 25 put: VkAccess2 transferWriteBit.
	barrier unsignedLongLongAt: 33 put: VkPipelineStage2 hostBit.
	barrier unsignedLongLongAt: 41 put: VkAccess2 hostReadBit.
	info := ExternalAddress allocate: 64.
	[
	info unsignedLongAt: 1 put: VkStructureType dependencyInfo.
	info pointerAt: 9 put: ExternalAddress null.
	info unsignedLongAt: 17 put: 0.
	info unsignedLongAt: 21 put: 1.
	info pointerAt: 25 put: barrier.
	info unsignedLongAt: 33 put: 0.
	info pointerAt: 41 put: ExternalAddress null.
	info unsignedLongAt: 49 put: 0.
	info pointerAt: 57 put: ExternalAddress null.
	Vk cmdPipelineBarrier2: handle pDependencyInfo: info ] ensure: [ info free ] ]
		ensure: [ barrier free ]
]

{ #category : 'recording' }
VkCommandBuffer >> begin [
    "VkCommandBufferBeginInfo (32 bytes):
     0:sType  8:pNext  16:flags  24:pInheritanceInfo"
    | info result |
    info := ExternalAddress allocate: 32.
    [ info unsignedLongAt: 1 put: VkStructureType commandBufferBeginInfo.
      info pointerAt: 9 put: ExternalAddress null.
      info unsignedLongAt: 17 put: 1.
      info pointerAt: 25 put: ExternalAddress null.
      result := Vk beginCommandBuffer: handle beginInfo: info.
      Vk checkResult: result
    ] ensure: [ info free ]
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
	"VkClearValue (16 bytes): 4 floats for colour (r, g, b, a). anArray holds r, g, b, a as
	 floats in 0.0 to 1.0; this layer speaks in numbers rather than in Color so it stays
	 independent of the image format's channel order.
	 VkRenderPassBeginInfo (64 bytes):
	 0:sType  8:pNext  16:renderPass  24:framebuffer  32:renderArea.offset.x
	 36:renderArea.offset.y  40:renderArea.extent.width  44:renderArea.extent.height
	 48:clearValueCount  56:pClearValues(ptr)"

	| info clearVal |
	clearVal := ExternalAddress allocate: 16.
	[
	1 to: 4 do: [ :i |
		clearVal floatAt: i - 1 * 4 + 1 put: (anArray at: i) asFloat ].
	info := ExternalAddress allocate: 64.
	[
	info unsignedLongAt: 1 put: VkStructureType renderPassBeginInfo.
	info pointerAt: 9 put: ExternalAddress null.
	info pointerAt: 17 put: aRenderPass handle getHandle.
	info pointerAt: 25 put: aFramebuffer handle getHandle.
	info unsignedLongAt: 33 put: 0.
	info unsignedLongAt: 37 put: 0.
	info unsignedLongAt: 41 put: aPoint x.
	info unsignedLongAt: 45 put: aPoint y.
	info unsignedLongAt: 49 put: 1.
	info pointerAt: 57 put: clearVal.
	Vk cmdBeginRenderPass: handle pRenderPassBegin: info contents: 0 ] ensure: [
		info free ] ] ensure: [ clearVal free ]
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
	"What the buffer was allocated with: the level and its name, the queue family the pool it
	 came from serves, and whether the handle is still usable. A buffer is freed with the pool
	 it was cut from and the driver leaves the handle reading as non-null, so liveness asks the
	 pool as well, and a buffer that was never allocated has no pool to ask. The rows are built
	 fresh on every call, so reading them cannot change the buffer."

	^ Dictionary newFrom: {
			  (#level -> level).
			  (#levelName -> (VkCommandBufferLevel nameForValue: level)).
			  (#queueFamilyIndex
			   -> (pool ifNotNil: [ :each | each poolRows at: #queueFamilyIndex ])).
			  (#live -> (handle isNotNil and: [
				    handle isNull not and: [
					    pool isNotNil and: [ pool poolRows at: #live ] ] ])) }
]

{ #category : 'recording' }
VkCommandBuffer >> copyImage: anImage layout: layout toBuffer: aBuffer extent: aPoint [
	"VkBufferImageCopy, 56 bytes, 1-based: 1:bufferOffset(u64) 9:bufferRowLength
	 13:bufferImageHeight 17:aspectMask 21:mipLevel 25:baseArrayLayer 29:layerCount
	 33,37,41:imageOffset x,y,z 45,49,53:imageExtent width,height,depth.
	 Row length and image height stay 0, which asks the driver for tightly packed rows of
	 exactly aPoint x pixels, so the host side can index by width alone."

	| region |
	region := ExternalAddress allocate: 56.
	[
	region unsignedLongLongAt: 1 put: 0.
	region unsignedLongAt: 9 put: 0.
	region unsignedLongAt: 13 put: 0.
	region unsignedLongAt: 17 put: VkRenderConfig imageAspectColorBit.
	region unsignedLongAt: 21 put: 0.
	region unsignedLongAt: 25 put: 0.
	region unsignedLongAt: 29 put: 1.
	region unsignedLongAt: 33 put: 0.
	region unsignedLongAt: 37 put: 0.
	region unsignedLongAt: 41 put: 0.
	region unsignedLongAt: 45 put: aPoint x.
	region unsignedLongAt: 49 put: aPoint y.
	region unsignedLongAt: 53 put: 1.
	Vk
		cmdCopyImageToBuffer: handle
		srcImage: anImage handle
		srcImageLayout: layout
		dstBuffer: aBuffer handle
		regionCount: 1
		pRegions: region ] ensure: [ region free ]
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
VkCommandBuffer >> inspectorBuffer: aBuilder [
	"What the buffer was allocated with: the level, named by the constants class that owns the
	 values, the queue family of the pool it came from, and whether it is still usable. The
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
				  { 'Usable'. (rows at: #live) } };
		  yourself
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
