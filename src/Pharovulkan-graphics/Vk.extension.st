Extension { #name : 'Vk' }

{ #category : '*pharovulkan-graphics' }
Vk class >> acquireNextImageKHR: device swapchain: swapchain timeout: timeout semaphore: semaphore fence: fence pImageIndex: pImageIndex [
    ^ self ffiCall: #( int32 vkAcquireNextImageKHR (
        VkDevice_H device,
        VkSwapchainKHR_H swapchain,
        uint64 timeout,
        VkSemaphore_H semaphore,
        VkFence_H fence,
        void* pImageIndex ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> cmdBeginRenderPass: cmdBuf pRenderPassBegin: pBeginInfo contents: contents [
    ^ self ffiCall: #( void vkCmdBeginRenderPass (
        VkCommandBuffer_H cmdBuf,
        void* pBeginInfo,
        int32 contents ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> cmdBindVertexBuffers: cmdBuf firstBinding: firstBinding bindingCount: count pBuffers: pBuffers pOffsets: pOffsets [
    ^ self ffiCall: #( void vkCmdBindVertexBuffers (
        VkCommandBuffer_H cmdBuf,
        uint32 firstBinding,
        uint32 count,
        void* pBuffers,
        void* pOffsets ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> cmdDraw: cmdBuf vertexCount: vertexCount instanceCount: instanceCount firstVertex: firstVertex firstInstance: firstInstance [
    ^ self ffiCall: #( void vkCmdDraw (
        VkCommandBuffer_H cmdBuf,
        uint32 vertexCount,
        uint32 instanceCount,
        uint32 firstVertex,
        uint32 firstInstance ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> cmdEndRenderPass: cmdBuf [
    ^ self ffiCall: #( void vkCmdEndRenderPass ( VkCommandBuffer_H cmdBuf ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> cmdSetScissor: cmdBuf firstScissor: first scissorCount: count pScissors: pScissors [
    ^ self ffiCall: #( void vkCmdSetScissor (
        VkCommandBuffer_H cmdBuf,
        uint32 first,
        uint32 count,
        void* pScissors ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> cmdSetViewport: cmdBuf firstViewport: first viewportCount: count pViewports: pViewports [
    ^ self ffiCall: #( void vkCmdSetViewport (
        VkCommandBuffer_H cmdBuf,
        uint32 first,
        uint32 count,
        void* pViewports ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> createFence: device createInfo: pCreateInfo allocator: pAllocator pFence: pFence [
    ^ self ffiCall: #( int32 vkCreateFence (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pFence ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> createFramebuffer: device createInfo: pCreateInfo allocator: pAllocator pFramebuffer: pFramebuffer [
    ^ self ffiCall: #( int32 vkCreateFramebuffer (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pFramebuffer ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> createGraphicsPipelines: device pipelineCache: cache createInfoCount: count pCreateInfos: pInfos allocator: pAllocator pPipelines: pPipelines [
    ^ self ffiCall: #( int32 vkCreateGraphicsPipelines (
        VkDevice_H device,
        void* cache,
        uint32 count,
        void* pInfos,
        void* pAllocator,
        void* pPipelines ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> createImageView: device createInfo: pCreateInfo allocator: pAllocator pView: pView [
    ^ self ffiCall: #( int32 vkCreateImageView (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pView ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> createRenderPass: device createInfo: pCreateInfo allocator: pAllocator pRenderPass: pRenderPass [
    ^ self ffiCall: #( int32 vkCreateRenderPass (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pRenderPass ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> createSemaphore: device createInfo: pCreateInfo allocator: pAllocator pSemaphore: pSemaphore [
    ^ self ffiCall: #( int32 vkCreateSemaphore (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pSemaphore ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> createSwapchainKHR: device createInfo: pCreateInfo allocator: pAllocator swapchain: pSwapchain [
    ^ self ffiCall: #( int32 vkCreateSwapchainKHR (
        VkDevice_H device,
        void* pCreateInfo,
        void* pAllocator,
        void* pSwapchain ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> destroyFence: device fence: fence allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyFence (
        VkDevice_H device,
        VkFence_H fence,
        void* pAllocator ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> destroyFramebuffer: device framebuffer: framebuffer allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyFramebuffer (
        VkDevice_H device,
        VkFramebuffer_H framebuffer,
        void* pAllocator ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> destroyImageView: device imageView: imageView allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyImageView (
        VkDevice_H device,
        VkImageView_H imageView,
        void* pAllocator ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> destroyRenderPass: device renderPass: renderPass allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyRenderPass (
        VkDevice_H device,
        VkRenderPass_H renderPass,
        void* pAllocator ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> destroySemaphore: device semaphore: semaphore allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroySemaphore (
        VkDevice_H device,
        VkSemaphore_H semaphore,
        void* pAllocator ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> destroySurfaceKHR: instance surface: surface allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroySurfaceKHR (
        VkInstance_H instance,
        VkSurfaceKHR_H surface,
        void* pAllocator ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> destroySwapchainKHR: device swapchain: swapchain allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroySwapchainKHR (
        VkDevice_H device,
        VkSwapchainKHR_H swapchain,
        void* pAllocator ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> getPhysicalDeviceSurfaceCapabilitiesKHR: physDev surface: surface pSurfaceCapabilities: pCaps [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfaceCapabilitiesKHR (
        VkPhysicalDevice_H physDev,
        VkSurfaceKHR_H surface,
        void* pCaps ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> getPhysicalDeviceSurfaceFormatsKHR: physDev surface: surface pSurfaceFormatCount: pCount pSurfaceFormats: pFormats [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfaceFormatsKHR (
        VkPhysicalDevice_H physDev,
        VkSurfaceKHR_H surface,
        void* pCount,
        void* pFormats ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> getPhysicalDeviceSurfacePresentModesKHR: physDev surface: surface pPresentModeCount: pCount pPresentModes: pModes [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfacePresentModesKHR (
        VkPhysicalDevice_H physDev,
        VkSurfaceKHR_H surface,
        void* pCount,
        void* pModes ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> getPhysicalDeviceSurfaceSupportKHR: physDev queueFamilyIndex: qfi surface: surface pSupported: pSupported [
    ^ self ffiCall: #( int32 vkGetPhysicalDeviceSurfaceSupportKHR (
        VkPhysicalDevice_H physDev,
        uint32 qfi,
        VkSurfaceKHR_H surface,
        void* pSupported ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> getSwapchainImagesKHR: device swapchain: swapchain pSwapchainImageCount: pCount pSwapchainImages: pImages [
    ^ self ffiCall: #( int32 vkGetSwapchainImagesKHR (
        VkDevice_H device,
        VkSwapchainKHR_H swapchain,
        void* pCount,
        void* pImages ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> queuePresentKHR: queue pPresentInfo: pPresentInfo [
    ^ self ffiCall: #( int32 vkQueuePresentKHR (
        VkQueue_H queue,
        void* pPresentInfo ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> resetFences: device fenceCount: count pFences: pFences [
    ^ self ffiCall: #( int32 vkResetFences (
        VkDevice_H device,
        uint32 count,
        void* pFences ) )
]

{ #category : '*pharovulkan-graphics' }
Vk class >> waitForFences: device fenceCount: count pFences: pFences waitAll: waitAll timeout: timeout [
    ^ self ffiCall: #( int32 vkWaitForFences (
        VkDevice_H device,
        uint32 count,
        void* pFences,
        uint32 waitAll,
        uint64 timeout ) )
]
