"
Entry point for all Vulkan function calls. All methods are class-side FFI wrappers
mirroring the Vulkan C API. Mirrors the pattern of Pharo's SDL2 class.
Do not instantiate — use class-side methods only.
Key methods: checkResult: (raises VkError on non-success), ffiLibrary (class-side).
"
Class {
	#name : 'Vk',
	#superclass : 'Object',
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'generated-api' }
Vk class >> allocateCommandBuffers: device allocateInfo: pAllocateInfo commandBuffers: pCommandBuffers [
    ^ self ffiCall: #( VkResult vkAllocateCommandBuffers (
        VkDevice_H device, void* pAllocateInfo, void* pCommandBuffers ) )
]

{ #category : 'generated-api' }
Vk class >> allocateDescriptorSets: device allocateInfo: pAllocateInfo descriptorSets: pDescriptorSets [
    ^ self ffiCall: #( VkResult vkAllocateDescriptorSets (
        VkDevice_H device, void* pAllocateInfo, void* pDescriptorSets ) )
]

{ #category : 'generated-api' }
Vk class >> allocateMemory: device allocateInfo: pAllocateInfo allocator: pAllocator memory: pMemory [
    ^ self ffiCall: #( VkResult vkAllocateMemory (
        VkDevice_H device, void* pAllocateInfo, void* pAllocator, void* pMemory ) )
]

{ #category : 'generated-api' }
Vk class >> beginCommandBuffer: commandBuffer beginInfo: pBeginInfo [
    ^ self ffiCall: #( VkResult vkBeginCommandBuffer (
        VkCommandBuffer_H commandBuffer, void* pBeginInfo ) )
]

{ #category : 'generated-api' }
Vk class >> bindBufferMemory: device buffer: buffer memory: memory memoryOffset: offset [
    ^ self ffiCall: #( VkResult vkBindBufferMemory (
        VkDevice_H device, VkBuffer_H buffer, VkDeviceMemory_H memory, uint64 offset ) )
]

{ #category : 'error handling' }
Vk class >> checkResult: anInteger [
    "Wrap the raw Vulkan result code. Raise VkError if it is not VK_SUCCESS."
    | result |
    result := VkResult withCode: anInteger.
    result isSuccess ifFalse: [ result signal ]
]

{ #category : 'generated-api' }
Vk class >> cmdBindDescriptorSets: cmdBuf pipelineBindPoint: bindPoint layout: layout firstSet: firstSet descriptorSetCount: count pDescriptorSets: pSets dynamicOffsetCount: dynCount pDynamicOffsets: dynOffsets [
    ^ self ffiCall: #( void vkCmdBindDescriptorSets (
        VkCommandBuffer_H cmdBuf, uint32 bindPoint, VkPipelineLayout_H layout,
        uint32 firstSet, uint32 count, void* pSets,
        uint32 dynCount, void* dynOffsets ) )
]

{ #category : 'generated-api' }
Vk class >> cmdBindPipeline: cmdBuf pipelineBindPoint: bindPoint pipeline: pipeline [
    ^ self ffiCall: #( void vkCmdBindPipeline (
        VkCommandBuffer_H cmdBuf, uint32 bindPoint, VkPipeline_H pipeline ) )
]

{ #category : 'generated-api' }
Vk class >> cmdDispatch: cmdBuf groupCountX: x groupCountY: y groupCountZ: z [
    ^ self ffiCall: #( void vkCmdDispatch (
        VkCommandBuffer_H cmdBuf, uint32 x, uint32 y, uint32 z ) )
]

{ #category : 'generated-api' }
Vk class >> createBuffer: device createInfo: pCreateInfo allocator: pAllocator bufferOut: pBuffer [
    ^ self ffiCall: #( VkResult vkCreateBuffer (
        VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pBuffer ) )
]

{ #category : 'generated-api' }
Vk class >> createCommandPool: device createInfo: pCreateInfo allocator: pAllocator poolOut: pPool [
    ^ self ffiCall: #( VkResult vkCreateCommandPool (
        VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pPool ) )
]

{ #category : 'generated-api' }
Vk class >> createComputePipelines: device pipelineCache: cache createInfoCount: count createInfos: pCreateInfos allocator: pAllocator pipelines: pPipelines [
    ^ self ffiCall: #( VkResult vkCreateComputePipelines (
        VkDevice_H device, void* cache, uint32 count,
        void* pCreateInfos, void* pAllocator, void* pPipelines ) )
]

{ #category : 'generated-api' }
Vk class >> createDescriptorPool: device createInfo: pCreateInfo allocator: pAllocator descriptorPoolOut: pPool [
    ^ self ffiCall: #( VkResult vkCreateDescriptorPool (
        VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pPool ) )
]

{ #category : 'generated-api' }
Vk class >> createDescriptorSetLayout: device createInfo: pCreateInfo allocator: pAllocator setLayoutOut: pSetLayout [
    ^ self ffiCall: #( VkResult vkCreateDescriptorSetLayout (
        VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pSetLayout ) )
]

{ #category : 'generated-api' }
Vk class >> createDevice: physDevice createInfo: pCreateInfo allocator: pAllocator deviceOut: pDevice [
    ^ self ffiCall: #( VkResult vkCreateDevice (
        VkPhysicalDevice_H physDevice,
        void* pCreateInfo,
        void* pAllocator,
        void* pDevice ) )
]

{ #category : 'instance-management' }
Vk class >> createInstance: aVkInstanceCreateInfo [

	| buf result instance |
	buf := ExternalAddress allocate: 8.
	instance := [
		            result := self
			                      primCreateInstance: aVkInstanceCreateInfo
			                      allocator: ExternalAddress null
			                      instanceOut: buf.
		            self checkResult: result.
		            VkInstance_H fromHandle: (buf pointerAt: 1) ] ensure: [
		            buf free ].
	^ instance
]

{ #category : 'generated-api' }
Vk class >> createPipelineLayout: device createInfo: pCreateInfo allocator: pAllocator pipelineLayoutOut: pLayout [
    ^ self ffiCall: #( VkResult vkCreatePipelineLayout (
        VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pLayout ) )
]

{ #category : 'generated-api' }
Vk class >> createShaderModule: device createInfo: pCreateInfo allocator: pAllocator shaderModuleOut: pModule [
    ^ self ffiCall: #( VkResult vkCreateShaderModule (
        VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pModule ) )
]

{ #category : 'generated-api' }
Vk class >> destroyBuffer: device buffer: buffer allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyBuffer (
        VkDevice_H device, VkBuffer_H buffer, void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> destroyCommandPool: device commandPool: pool allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyCommandPool (
        VkDevice_H device, VkCommandPool_H pool, void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> destroyDescriptorPool: device descriptorPool: pool allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyDescriptorPool (
        VkDevice_H device, VkDescriptorPool_H pool, void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> destroyDescriptorSetLayout: device descriptorSetLayout: layout allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyDescriptorSetLayout (
        VkDevice_H device, VkDescriptorSetLayout_H layout, void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> destroyDevice: device allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyDevice (
        VkDevice_H device, void* pAllocator ) )
]

{ #category : 'ffi-primitives' }
Vk class >> destroyInstance: aVkInstance_H [
    ^ self ffiCall: #( void vkDestroyInstance (
        VkInstance_H aVkInstance_H,
        void* null ) )
]

{ #category : 'ffi-calls' }
Vk class >> destroyInstance: aVkInstance_H allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyInstance (VkInstance_H aVkInstance_H, void* pAllocator) )
]

{ #category : 'generated-api' }
Vk class >> destroyPipeline: device pipeline: pipeline allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyPipeline (
        VkDevice_H device, VkPipeline_H pipeline, void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> destroyPipelineLayout: device pipelineLayout: layout allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyPipelineLayout (
        VkDevice_H device, VkPipelineLayout_H layout, void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> destroyShaderModule: device shaderModule: shaderModule allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyShaderModule (
        VkDevice_H device, VkShaderModule_H shaderModule, void* pAllocator ) )
]

{ #category : 'commands' }
Vk class >> deviceWaitIdle: device [
    ^ self ffiCall: #( int vkDeviceWaitIdle ( VkDevice_H device ) )
]

{ #category : 'generated-api' }
Vk class >> endCommandBuffer: commandBuffer [
    ^ self ffiCall: #( VkResult vkEndCommandBuffer (
        VkCommandBuffer_H commandBuffer ) )
]

{ #category : 'instance-management' }
Vk class >> enumeratePhysicalDevices: aVkInstance_H [
    | countBuf result count devicesBuf handles |
    countBuf := ExternalAddress allocate: 4.
    [ result := self primEnumeratePhysicalDevices: aVkInstance_H
        count: countBuf devices: ExternalAddress null.
      self checkResult: result.
      count := countBuf unsignedLongAt: 1.
      count = 0 ifTrue: [ ^ #() ].
      devicesBuf := ExternalAddress allocate: count * 8.
      [ result := self primEnumeratePhysicalDevices: aVkInstance_H
          count: countBuf devices: devicesBuf.
        self checkResult: result.
        handles := Array new: count.
        1 to: count do: [ :i |
            handles at: i put: (VkPhysicalDevice_H fromHandle:
                (devicesBuf pointerAt: (i - 1) * 8 + 1)) ]
      ] ensure: [ devicesBuf free ]
    ] ensure: [ countBuf free ].
    ^ handles
]

{ #category : 'ffi' }
Vk class >> ffiLibrary [
    ^ VkLibrary
]

{ #category : 'generated-api' }
Vk class >> freeMemory: device memory: memory allocator: pAllocator [
    ^ self ffiCall: #( void vkFreeMemory (
        VkDevice_H device, VkDeviceMemory_H memory, void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> getBufferMemoryRequirements: device buffer: buffer memoryRequirements: pMemReqs [
    ^ self ffiCall: #( void vkGetBufferMemoryRequirements (
        VkDevice_H device, VkBuffer_H buffer, void* pMemReqs ) )
]

{ #category : 'generated-api' }
Vk class >> getDeviceQueue: device queueFamilyIndex: familyIndex queueIndex: queueIndex queue: pQueue [
    ^ self ffiCall: #( void vkGetDeviceQueue (
        VkDevice_H device, uint32 familyIndex, uint32 queueIndex, void* pQueue ) )
]

{ #category : 'generated-api' }
Vk class >> getPhysicalDeviceMemoryProperties: physDevice memoryProperties: pMemProps [
    ^ self ffiCall: #( void vkGetPhysicalDeviceMemoryProperties (
        VkPhysicalDevice_H physDevice, void* pMemProps ) )
]

{ #category : 'physical-device' }
Vk class >> getPhysicalDeviceProperties: aVkPhysicalDevice_H [
    "Return a populated VkPhysicalDeviceProperties for the given physical device."
    | props |
    props := VkPhysicalDeviceProperties new.
    self getPhysicalDeviceProperties: aVkPhysicalDevice_H into: props.
    ^ props
]

{ #category : 'ffi-primitives' }
Vk class >> getPhysicalDeviceProperties: aVkPhysicalDevice_H into: aVkPhysicalDeviceProperties [
    ^ self ffiCall: #( void vkGetPhysicalDeviceProperties (
        VkPhysicalDevice_H aVkPhysicalDevice_H,
        VkPhysicalDeviceProperties* aVkPhysicalDeviceProperties ) )
]

{ #category : 'physical-device' }
Vk class >> getQueueFamilyProperties: aVkPhysicalDevice_H [
    "Return an Array of VkQueueFamilyProperties for the given physical device."
    | countBuf count propsBuf stride result |
    countBuf := ExternalAddress allocate: 4.
    self primGetQueueFamilyProperties: aVkPhysicalDevice_H
        count: countBuf props: ExternalAddress null.
    count := countBuf unsignedLongAt: 1.
    count = 0 ifTrue: [ ^ #() ].
    stride := VkQueueFamilyProperties externalTypeSize.
    propsBuf := ExternalAddress allocate: count * stride.
    self primGetQueueFamilyProperties: aVkPhysicalDevice_H
        count: countBuf props: propsBuf.
    result := Array new: count.
    1 to: count do: [:i |
        result at: i put: (VkQueueFamilyProperties fromHandle:
            (propsBuf + ((i - 1) * stride)) autoRelease)].
    ^ result
]

{ #category : 'generated-api' }
Vk class >> mapMemory: device memory: memory offset: offset size: size flags: flags ppData: ppData [
    ^ self ffiCall: #( VkResult vkMapMemory (
        VkDevice_H device, VkDeviceMemory_H memory, uint64 offset, uint64 size,
        uint32 flags, void* ppData ) )
]

{ #category : 'ffi-primitives' }
Vk class >> primCreateInstance: pCreateInfo allocator: pAllocator instanceOut: pInstance [
    "Raw FFI call. pInstance must be an ExternalAddress pointing to 8 bytes of storage."
    ^ self ffiCall: #( int32 vkCreateInstance (
        VkInstanceCreateInfo* pCreateInfo,
        void* pAllocator,
        void* pInstance ) )
]

{ #category : 'ffi-primitives' }
Vk class >> primEnumeratePhysicalDevices: instance count: pCount devices: pDevices [
    ^ self ffiCall: #( int32 vkEnumeratePhysicalDevices (
        VkInstance_H instance,
        void* pCount,
        void* pDevices ) )
]

{ #category : 'ffi-primitives' }
Vk class >> primGetQueueFamilyProperties: physDevice count: pCount props: pProps [
    ^ self ffiCall: #( void vkGetPhysicalDeviceQueueFamilyProperties (
        VkPhysicalDevice_H physDevice,
        void* pCount,
        void* pProps ) )
]

{ #category : 'generated-api' }
Vk class >> queueSubmit2: queue submitCount: count submits: pSubmits fence: fence [
    ^ self ffiCall: #( VkResult vkQueueSubmit2 (
        VkQueue_H queue, uint32 count, void* pSubmits, void* fence ) )
]

{ #category : 'generated-api' }
Vk class >> queueWaitIdle: queue [
    ^ self ffiCall: #( VkResult vkQueueWaitIdle ( VkQueue_H queue ) )
]

{ #category : 'commands' }
Vk class >> resetCommandPool: deviceHandle commandPool: poolHandle flags: flags [
    <primitive: #primitiveNativeCall>
    ^ self ffiCall: #(int vkResetCommandPool (void* deviceHandle, void* poolHandle, uint32 flags)) library: VkLibrary
]

{ #category : 'generated-api' }
Vk class >> unmapMemory: device memory: memory [
    ^ self ffiCall: #( void vkUnmapMemory (
        VkDevice_H device, VkDeviceMemory_H memory ) )
]

{ #category : 'generated-api' }
Vk class >> updateDescriptorSets: device descriptorWriteCount: writeCount pDescriptorWrites: pWrites descriptorCopyCount: copyCount pDescriptorCopies: pCopies [
    ^ self ffiCall: #( void vkUpdateDescriptorSets (
        VkDevice_H device, uint32 writeCount, void* pWrites,
        uint32 copyCount, void* pCopies ) )
]
