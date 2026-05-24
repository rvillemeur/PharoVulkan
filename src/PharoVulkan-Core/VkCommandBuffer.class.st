"
Wrapper around a VkCommandBuffer_H. Records Vulkan commands inside a do: block. Key methods: do:, begin, end, dispatch:y:z:, bindComputePipeline:, bindDescriptorSets:pipelineLayout:, draw:.
"
Class {
	#name : 'VkCommandBuffer',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'pool'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan-Core'
}

{ #category : 'factory' }
VkCommandBuffer class >> on: aHandle pool: aPool [
    ^ self new initializeWith: aHandle pool: aPool
]

{ #category : 'recording' }
VkCommandBuffer >> begin [
    | info result |
    info := ExternalAddress allocate: 32.
    [ info unsignedLongAt: 1 put: 42.
      info pointerAt: 9 put: ExternalAddress null.
      info unsignedLongAt: 17 put: 1.
      info pointerAt: 25 put: ExternalAddress null.
      result := Vk beginCommandBuffer: handle beginInfo: info.
      Vk checkResult: result
    ] ensure: [ info free ]
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

{ #category : 'recording' }
VkCommandBuffer >> end [
    Vk checkResult: (Vk endCommandBuffer: handle)
]

{ #category : 'accessing' }
VkCommandBuffer >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkCommandBuffer >> initializeWith: aHandle pool: aPool [
    handle := aHandle. pool := aPool
]
