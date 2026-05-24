Extension { #name : 'VkCommandBuffer' }

{ #category : '*pharovulkan-graphics' }
VkCommandBuffer >> beginRenderPass: aRenderPass framebuffer: aFramebuffer extent: aPoint [
    "VkClearValue (16 bytes): 4 floats for colour (r, g, b, a).
     VkRenderPassBeginInfo (64 bytes):
     0:sType  8:pNext  16:renderPass  24:framebuffer  32:renderArea.offset.x  36:renderArea.offset.y  40:renderArea.extent.width  44:renderArea.extent.height  48:clearValueCount  56:pClearValues(ptr)"
    | info clearVal |
    clearVal := ExternalAddress allocate: 16.
    [ clearVal floatAt: 1 put: 0.0.
      clearVal floatAt: 5 put: 0.0.
      clearVal floatAt: 9 put: 0.0.
      clearVal floatAt: 13 put: 1.0.
      info := ExternalAddress allocate: 64.
      [ info unsignedLongAt: 1 put: VkStructureType renderPassBeginInfo.
        info pointerAt: 9 put: ExternalAddress null.
        info pointerAt: 17 put: aRenderPass handle getHandle.
        info pointerAt: 25 put: aFramebuffer handle getHandle.
        info unsignedLongAt: 33 put: 0.
        info unsignedLongAt: 37 put: 0.
        info unsignedLongAt: 41 put: aPoint x.
        info unsignedLongAt: 45 put: aPoint y.
        info unsignedLongAt: 49 put: 1.
        info pointerAt: 57 put: clearVal.
        Vk cmdBeginRenderPass: handle pRenderPassBegin: info contents: 0
      ] ensure: [ info free ]
    ] ensure: [ clearVal free ]
]

{ #category : '*pharovulkan-graphics' }
VkCommandBuffer >> bindGraphicsPipeline: aPipeline [
    Vk cmdBindPipeline: handle pipelineBindPoint: 0 pipeline: aPipeline handle
]

{ #category : '*pharovulkan-graphics' }
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

{ #category : '*pharovulkan-graphics' }
VkCommandBuffer >> draw: vertexCount [
    Vk cmdDraw: handle vertexCount: vertexCount instanceCount: 1 firstVertex: 0 firstInstance: 0
]

{ #category : '*pharovulkan-graphics' }
VkCommandBuffer >> endRenderPass [
    Vk cmdEndRenderPass: handle
]

{ #category : '*pharovulkan-graphics' }
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

{ #category : '*pharovulkan-graphics' }
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
