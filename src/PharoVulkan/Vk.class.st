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

{ #category : 'PharoVulkan' }
Vk class >> acquireNextImageKHR: device swapchain: swapchain timeout: timeout semaphore: semaphore fence: fence pImageIndex: pImageIndex [
    ^ self ffiCall: #( int32 vkAcquireNextImageKHR (
        VkDevice_H device,
        VkSwapchainKHR_H swapchain,
        uint64 timeout,
        VkSemaphore_H semaphore,
        VkFence_H fence,
        void* pImageIndex ) )
]

{ #category : 'utilities' }
Vk class >> allocateCString: aString [
	"Vulkan takes names as NUL-terminated C strings; the caller owns the memory and frees
	 it. VkContext has its own instance-side copy of this, which is older and used while
	 building create-infos; this one is here so a class with no context can ask too."

	| bytes buf |
	bytes := aString asByteArray copyWith: 0.
	buf := ExternalAddress allocate: bytes size.
	bytes doWithIndex: [ :byte :i | buf byteAt: i put: byte ].
	^ buf
]

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

{ #category : 'ffi-calls' }
Vk class >> cmdBeginRenderPass: cmdBuf pRenderPassBegin: pBeginInfo contents: contents [
    ^ self ffiCall: #( void vkCmdBeginRenderPass (
        VkCommandBuffer_H cmdBuf,
        void* pBeginInfo,
        int32 contents ) )
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

{ #category : 'ffi' }
Vk class >> cmdBindVertexBuffers: cmdBuf firstBinding: firstBinding bindingCount: count pBuffers: pBuffers pOffsets: pOffsets [
    ^ self ffiCall: #( void vkCmdBindVertexBuffers (
        VkCommandBuffer_H cmdBuf,
        uint32 firstBinding,
        uint32 count,
        void* pBuffers,
        void* pOffsets ) )
]

{ #category : 'generated-api' }
Vk class >> cmdDispatch: cmdBuf groupCountX: x groupCountY: y groupCountZ: z [
    ^ self ffiCall: #( void vkCmdDispatch (
        VkCommandBuffer_H cmdBuf, uint32 x, uint32 y, uint32 z ) )
]

{ #category : 'ffi' }
Vk class >> cmdDraw: cmdBuf vertexCount: vertexCount instanceCount: instanceCount firstVertex: firstVertex firstInstance: firstInstance [
    ^ self ffiCall: #( void vkCmdDraw (
        VkCommandBuffer_H cmdBuf,
        uint32 vertexCount,
        uint32 instanceCount,
        uint32 firstVertex,
        uint32 firstInstance ) )
]

{ #category : 'ffi' }
Vk class >> cmdEndRenderPass: cmdBuf [
    ^ self ffiCall: #( void vkCmdEndRenderPass ( VkCommandBuffer_H cmdBuf ) )
]

{ #category : 'ffi' }
Vk class >> cmdSetScissor: cmdBuf firstScissor: first scissorCount: count pScissors: pScissors [
    ^ self ffiCall: #( void vkCmdSetScissor (
        VkCommandBuffer_H cmdBuf,
        uint32 first,
        uint32 count,
        void* pScissors ) )
]

{ #category : 'ffi' }
Vk class >> cmdSetViewport: cmdBuf firstViewport: first viewportCount: count pViewports: pViewports [
    ^ self ffiCall: #( void vkCmdSetViewport (
        VkCommandBuffer_H cmdBuf,
        uint32 first,
        uint32 count,
        void* pViewports ) )
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

{ #category : 'ffi' }
Vk class >> createFence: device createInfo: pCreateInfo allocator: pAllocator pFence: pFence [
    ^ self ffiCall: #( int32 vkCreateFence (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pFence ) )
]

{ #category : 'ffi' }
Vk class >> createFramebuffer: device createInfo: pCreateInfo allocator: pAllocator pFramebuffer: pFramebuffer [
    ^ self ffiCall: #( int32 vkCreateFramebuffer (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pFramebuffer ) )
]

{ #category : 'ffi' }
Vk class >> createGraphicsPipelines: device pipelineCache: cache createInfoCount: count pCreateInfos: pInfos allocator: pAllocator pPipelines: pPipelines [
    ^ self ffiCall: #( int32 vkCreateGraphicsPipelines (
        VkDevice_H device,
        void* cache,
        uint32 count,
        void* pInfos,
        void* pAllocator,
        void* pPipelines ) )
]

{ #category : 'ffi' }
Vk class >> createImageView: device createInfo: pCreateInfo allocator: pAllocator pView: pView [
    ^ self ffiCall: #( int32 vkCreateImageView (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pView ) )
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

{ #category : 'ffi' }
Vk class >> createRenderPass: device createInfo: pCreateInfo allocator: pAllocator pRenderPass: pRenderPass [
    ^ self ffiCall: #( int32 vkCreateRenderPass (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pRenderPass ) )
]

{ #category : 'ffi' }
Vk class >> createSemaphore: device createInfo: pCreateInfo allocator: pAllocator pSemaphore: pSemaphore [
    ^ self ffiCall: #( int32 vkCreateSemaphore (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pSemaphore ) )
]

{ #category : 'generated-api' }
Vk class >> createShaderModule: device createInfo: pCreateInfo allocator: pAllocator shaderModuleOut: pModule [
    ^ self ffiCall: #( VkResult vkCreateShaderModule (
        VkDevice_H device, void* pCreateInfo, void* pAllocator, void* pModule ) )
]

{ #category : 'ffi' }
Vk class >> createSwapchainKHR: device createInfo: pCreateInfo allocator: pAllocator swapchain: pSwapchain [
    ^ self ffiCall: #( int32 vkCreateSwapchainKHR (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pSwapchain ) )
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

{ #category : 'ffi' }
Vk class >> destroyFence: device fence: fence allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyFence (
        VkDevice_H device,
        VkFence_H fence,
        void* pAllocator ) )
]

{ #category : 'ffi' }
Vk class >> destroyFramebuffer: device framebuffer: framebuffer allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyFramebuffer (
        VkDevice_H device,
        VkFramebuffer_H framebuffer,
        void* pAllocator ) )
]

{ #category : 'ffi' }
Vk class >> destroyImageView: device imageView: imageView allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyImageView (
        VkDevice_H device,
        VkImageView_H imageView,
        void* pAllocator ) )
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

{ #category : 'ffi' }
Vk class >> destroyRenderPass: device renderPass: renderPass allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyRenderPass (
        VkDevice_H device,
        VkRenderPass_H renderPass,
        void* pAllocator ) )
]

{ #category : 'ffi' }
Vk class >> destroySemaphore: device semaphore: semaphore allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroySemaphore (
        VkDevice_H device,
        VkSemaphore_H semaphore,
        void* pAllocator ) )
]

{ #category : 'generated-api' }
Vk class >> destroyShaderModule: device shaderModule: shaderModule allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyShaderModule (
        VkDevice_H device, VkShaderModule_H shaderModule, void* pAllocator ) )
]

{ #category : 'ffi' }
Vk class >> destroySurfaceKHR: instance surface: surface allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroySurfaceKHR (
        VkInstance_H instance,
        VkSurfaceKHR_H surface,
        void* pAllocator ) )
]

{ #category : 'ffi' }
Vk class >> destroySwapchainKHR: device swapchain: swapchain allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroySwapchainKHR (
        VkDevice_H device,
        VkSwapchainKHR_H swapchain,
        void* pAllocator ) )
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

{ #category : 'physical devices' }
Vk class >> getPhysicalDeviceFeatures2: physDevice into: pFeatures2 [
	"pFeatures2 points at a VkPhysicalDeviceFeatures2 whose pNext chain the driver walks, so
	 it must be memory outside the image: a ByteArray may move while the driver holds a
	 pointer into it."

	^ self ffiCall: #( void vkGetPhysicalDeviceFeatures2 (
			   VkPhysicalDevice_H physDevice,
			   void* pFeatures2 ) )
]

{ #category : 'generated-api' }
Vk class >> getPhysicalDeviceMemoryProperties: physDevice memoryProperties: pMemProps [
    ^ self ffiCall: #( void vkGetPhysicalDeviceMemoryProperties (
        VkPhysicalDevice_H physDevice, void* pMemProps ) )
]

{ #category : 'physical device' }
Vk class >> getPhysicalDeviceProperties2: physDevice into: pProperties2 [
	"pProperties2 points at a VkPhysicalDeviceProperties2 whose pNext chain the driver walks, so
	 it must be memory outside the image: a ByteArray may move while the driver holds a pointer
	 into it."

	^ self ffiCall: #( void vkGetPhysicalDeviceProperties2 (
			   VkPhysicalDevice_H physDevice,
			   void* pProperties2 ) )
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

{ #category : 'ffi' }
Vk class >> getPhysicalDeviceSurfaceCapabilitiesKHR: physDev surface: surface pSurfaceCapabilities: pCaps [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfaceCapabilitiesKHR (
        VkPhysicalDevice_H physDev,
        VkSurfaceKHR_H surface,
        void* pCaps ) )
]

{ #category : 'ffi-calls' }
Vk class >> getPhysicalDeviceSurfaceFormatsKHR: physDev surface: surface pSurfaceFormatCount: pCount pSurfaceFormats: pFormats [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfaceFormatsKHR (
        VkPhysicalDevice_H physDev,
        VkSurfaceKHR_H surface,
        void* pCount,
        void* pFormats ) )
]

{ #category : 'ffi' }
Vk class >> getPhysicalDeviceSurfacePresentModesKHR: physDev surface: surface pPresentModeCount: pCount pPresentModes: pModes [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfacePresentModesKHR (
        VkPhysicalDevice_H physDev,
        VkSurfaceKHR_H surface,
        void* pCount,
        void* pModes ) )
]

{ #category : 'ffi-calls' }
Vk class >> getPhysicalDeviceSurfaceSupportKHR: physDev queueFamilyIndex: qfi surface: surface pSupported: pSupported [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfaceSupportKHR (
        VkPhysicalDevice_H physDev,
        uint32 qfi,
        VkSurfaceKHR_H surface,
        void* pSupported ) )
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

{ #category : 'ffi' }
Vk class >> getSwapchainImagesKHR: device swapchain: swapchain pSwapchainImageCount: pCount pSwapchainImages: pImages [
    ^ self ffiCall: #( int32 vkGetSwapchainImagesKHR (
        VkDevice_H device,
        VkSwapchainKHR_H swapchain,
        void* pCount,
        void* pImages ) )
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
Vk class >> primEnumerateDeviceExtensionProperties: physDevice layerName: pLayerName count: pCount props: pProps [
    ^ self ffiCall: #( int32 vkEnumerateDeviceExtensionProperties (
        VkPhysicalDevice_H physDevice,
        void* pLayerName,
        void* pCount,
        void* pProps ) )
]

{ #category : 'ffi-primitives' }
Vk class >> primEnumeratePhysicalDevices: instance count: pCount devices: pDevices [
    ^ self ffiCall: #( int32 vkEnumeratePhysicalDevices (
        VkInstance_H instance,
        void* pCount,
        void* pDevices ) )
]

{ #category : 'primitives' }
Vk class >> primGetInstanceProcAddr: instance name: pName [
	^ self ffiCall: #( void* vkGetInstanceProcAddr (
			   VkInstance_H instance,
			   void* pName ) )
]

{ #category : 'ffi-primitives' }
Vk class >> primGetQueueFamilyProperties: physDevice count: pCount props: pProps [
    ^ self ffiCall: #( void vkGetPhysicalDeviceQueueFamilyProperties (
        VkPhysicalDevice_H physDevice,
        void* pCount,
        void* pProps ) )
]

{ #category : 'ffi-calls' }
Vk class >> queuePresentKHR: queue pPresentInfo: pPresentInfo [
    ^ self ffiCall: #( int32 vkQueuePresentKHR (
        VkQueue_H queue,
        void* pPresentInfo ) )
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

{ #category : 'ffi-calls' }
Vk class >> resetFences: device fenceCount: count pFences: pFences [
    ^ self ffiCall: #( int32 vkResetFences (
        VkDevice_H device,
        uint32 count,
        void* pFences ) )
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

{ #category : 'ffi-calls' }
Vk class >> waitForFences: device fenceCount: count pFences: pFences waitAll: waitAll timeout: timeout [
    ^ self ffiCall: #( int32 vkWaitForFences (
        VkDevice_H device,
        uint32 count,
        void* pFences,
        uint32 waitAll,
        uint64 timeout ) )
]
