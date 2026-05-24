Extension { #name : 'VkCommandBuffer' }

{ #category : '*pharovulkan-graphics' }
VkCommandBuffer >> beginRenderPass: aRenderPass framebuffer: aFramebuffer extent: aPoint [
    | info clearVal clearColor |
    clearColor := ExternalAddress allocate: 16.
    [ clearColor floatAt: 1 put: 0.0.
      clearColor floatAt: 5 put: 0.0.
      clearColor floatAt: 9 put: 0.0.
      clearColor floatAt: 13 put: 1.0.
      clearVal := ExternalAddress allocate: 16.
      [ clearVal copyFrom: clearColor to: 16.
        info := ExternalAddress allocate: 64.
        [ info unsignedLongAt: 1 put: 43.
          info pointerAt: 9 put: ExternalAddress null.
          info pointerAt: 17 put: aRenderPass handle getHandle.
          info pointerAt: 25 put: aFramebuffer handle getHandle.
          info unsignedLongAt: 33 put: 0.
          info unsignedLongAt: 37 put: 0.
          info unsignedLongAt: 41 put: aPoint x.
          info unsignedLongAt: 45 put: aPoint y.
          info unsignedLongAt: 49 put: 1.
          info pointerAt: 57 put: clearVal.
          Vk cmdBeginRenderPass: handle renderPassBegin: info contents: 0
        ] ensure: [ info free ]
      ] ensure: [ clearVal free ]
    ] ensure: [ clearColor free ]
]

{ #category : '*pharovulkan-graphics' }
VkCommandBuffer >> bindGraphicsPipeline: aPipeline [
    Vk cmdBindPipeline: handle pipelineBindPoint: 0 pipeline: aPipeline handle getHandle
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
