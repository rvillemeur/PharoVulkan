"
Vulkan swapchain. Manages the queue of presentable images for a surface, creates image views, acquires images, and presents frames. Key methods: acquireNextImage:fence:, present:queue:waitSemaphore:.
"
Class {
	#name : 'VkSwapchain',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'surface',
		'images',
		'imageViews',
		'format',
		'extent',
		'imageCount'
	],
	#category : 'Pharovulkan-graphics',
	#package : 'Pharovulkan-graphics'
}

{ #category : 'instance creation' }
VkSwapchain class >> on: aVkDevice surface: aVkSurface extent: aPoint [
    ^ self new initializeDevice: aVkDevice surface: aVkSurface extent: aPoint
]

{ #category : 'operations' }
VkSwapchain >> acquireNextImage: semaphore fence: fence [
    | idxBuf result |
    idxBuf := ExternalAddress allocate: 4.
    [
        result := Vk acquireNextImageKHR: device handle swapchain: handle
            timeout: 16rFFFFFFFFFFFFFFFF semaphore: semaphore fence: fence pImageIndex: idxBuf.
        Vk checkResult: result.
        ^ idxBuf unsignedLongAt: 1
    ] ensure: [ idxBuf free ]
]

{ #category : 'initialization' }
VkSwapchain >> createImageViews [
    "VkImageViewCreateInfo (80 bytes):
     0:sType  8:pNext  16:flags  24:image  32:viewType  36:format  40:components(r,g,b,a)  56:subresourceRange(aspectMask,baseMipLevel,levelCount,baseArrayLayer,layerCount)"
    | viewInfo outBuf result |
    imageViews := OrderedCollection new.
    images do: [ :img |
        viewInfo := ExternalAddress allocate: 80.
        [ viewInfo unsignedLongAt: 1  put: VkStructureType imageViewCreateInfo.
          viewInfo pointerAt:   9  put: ExternalAddress null.
          viewInfo unsignedLongAt: 17 put: 0.
          viewInfo pointerAt:   25 put: img getHandle.
          viewInfo unsignedLongAt: 33 put: 1.
          viewInfo unsignedLongAt: 37 put: format.
          viewInfo unsignedLongAt: 41 put: 0.
          viewInfo unsignedLongAt: 45 put: 0.
          viewInfo unsignedLongAt: 49 put: 0.
          viewInfo unsignedLongAt: 53 put: 0.
          viewInfo unsignedLongAt: 57 put: 1.
          viewInfo unsignedLongAt: 61 put: 0.
          viewInfo unsignedLongAt: 65 put: 1.
          viewInfo unsignedLongAt: 69 put: 0.
          viewInfo unsignedLongAt: 73 put: 1.
          outBuf := ExternalAddress allocate: 8.
          [ result := Vk createImageView: device handle createInfo: viewInfo allocator: ExternalAddress null pView: outBuf.
            Vk checkResult: result.
            imageViews add: (VkImageView_H fromHandle: (outBuf pointerAt: 1))
          ] ensure: [ outBuf free ]
        ] ensure: [ viewInfo free ] ]
]

{ #category : 'lifecycle' }
VkSwapchain >> destroy [
    imageViews ifNotNil: [
        imageViews do: [:iv | Vk destroyImageView: device handle imageView: iv allocator: ExternalAddress null].
        imageViews := nil ].
    handle ifNotNil: [
        Vk destroySwapchainKHR: device handle swapchain: handle allocator: ExternalAddress null.
        handle := nil ]
]

{ #category : 'accessing' }
VkSwapchain >> extent [
    ^ extent
]

{ #category : 'accessing' }
VkSwapchain >> format [
    ^ format
]

{ #category : 'accessing' }
VkSwapchain >> handle [
    ^ handle
]

{ #category : 'accessing' }
VkSwapchain >> imageCount [
    ^ imageCount
]

{ #category : 'accessing' }
VkSwapchain >> imageViews [
    ^ imageViews
]

{ #category : 'accessing' }
VkSwapchain >> images [
    ^ images
]

{ #category : 'initialization' }
VkSwapchain >> initializeDevice: aVkDevice surface: aVkSurface extent: aPoint [
    | caps formatBuf countBuf result fmtCount swapInfo outBuf imgCountBuf imgBuf |
    device := aVkDevice. surface := aVkSurface. extent := aPoint.
    caps := ExternalAddress allocate: 52.
    [ aVkSurface queryCapabilitiesInto: caps.
      countBuf := ExternalAddress allocate: 4.
      [ result := Vk getPhysicalDeviceSurfaceFormatsKHR: aVkSurface physicalDevice handle
            surface: aVkSurface handle pSurfaceFormatCount: countBuf pSurfaceFormats: ExternalAddress null.
        Vk checkResult: result.
        fmtCount := countBuf unsignedLongAt: 1.
        formatBuf := ExternalAddress allocate: fmtCount * 8.
        [ result := Vk getPhysicalDeviceSurfaceFormatsKHR: aVkSurface physicalDevice handle
              surface: aVkSurface handle pSurfaceFormatCount: countBuf pSurfaceFormats: formatBuf.
          Vk checkResult: result.
          format := formatBuf unsignedLongAt: 1.
          1 to: fmtCount do: [:i |
              (formatBuf unsignedLongAt: (i - 1) * 8 + 1) = 44 ifTrue: [ format := 44 ]]
        ] ensure: [ formatBuf free ]
      ] ensure: [ countBuf free ].
      imageCount := (caps unsignedLongAt: 1) + 1.
      (caps unsignedLongAt: 5) > 0 ifTrue: [ imageCount := imageCount min: (caps unsignedLongAt: 5) ].
      "VkSwapchainCreateInfoKHR (104 bytes):
       0:sType 8:pNext 16:flags 20:surface(ptr) 28:minImageCount 32:imageFormat 36:imageColorSpace 40:imageExtent.width 44:imageExtent.height 48:imageArrayLayers 52:imageUsage 56:imageSharingMode 60:queueFamilyIndexCount 64:pQueueFamilyIndices(ptr) 72:preTransform 76:compositeAlpha 80:presentMode 84:clipped 88:oldSwapchain(ptr)
       VkSurfaceCapabilitiesKHR: 0:minImageCount 4:maxImageCount ... 40:currentTransform ..."
      swapInfo := ExternalAddress allocate: 104.
      [ swapInfo unsignedLongAt: 1  put: VkStructureType swapchainCreateInfoKHR.
        swapInfo pointerAt: 9  put: ExternalAddress null.
        swapInfo unsignedLongAt: 17 put: 0.
        swapInfo pointerAt: 25 put: aVkSurface handle getHandle.
        swapInfo unsignedLongAt: 33 put: imageCount.
        swapInfo unsignedLongAt: 37 put: format.
        swapInfo unsignedLongAt: 41 put: 0.
        swapInfo unsignedLongAt: 45 put: aPoint x.
        swapInfo unsignedLongAt: 49 put: aPoint y.
        swapInfo unsignedLongAt: 53 put: 1.
        swapInfo unsignedLongAt: 57 put: 16.
        swapInfo unsignedLongAt: 61 put: 0.
        swapInfo unsignedLongAt: 65 put: 0.
        swapInfo pointerAt: 73 put: ExternalAddress null.
        swapInfo unsignedLongAt: 81 put: (caps unsignedLongAt: 41).
        swapInfo unsignedLongAt: 85 put: 1.
        swapInfo unsignedLongAt: 89 put: 2.
        swapInfo unsignedLongAt: 93 put: 1.
        swapInfo pointerAt: 97 put: ExternalAddress null.
        outBuf := ExternalAddress allocate: 8.
        [ result := Vk createSwapchainKHR: device handle createInfo: swapInfo allocator: ExternalAddress null swapchain: outBuf.
          Vk checkResult: result.
          handle := VkSwapchainKHR_H fromHandle: (outBuf pointerAt: 1)
        ] ensure: [ outBuf free ]
      ] ensure: [ swapInfo free ].
      imgCountBuf := ExternalAddress allocate: 4.
      [ result := Vk getSwapchainImagesKHR: device handle swapchain: handle pSwapchainImageCount: imgCountBuf pSwapchainImages: ExternalAddress null.
        Vk checkResult: result.
        imageCount := imgCountBuf unsignedLongAt: 1.
        imgBuf := ExternalAddress allocate: imageCount * 8.
        [ result := Vk getSwapchainImagesKHR: device handle swapchain: handle pSwapchainImageCount: imgCountBuf pSwapchainImages: imgBuf.
          Vk checkResult: result.
          images := (1 to: imageCount) collect: [:i | VkImage_H fromHandle: (imgBuf pointerAt: (i - 1) * 8 + 1)]
        ] ensure: [ imgBuf free ]
      ] ensure: [ imgCountBuf free ].
      self createImageViews
    ] ensure: [ caps free ]
]

{ #category : 'rendering' }
VkSwapchain >> present: imageIndex queue: aVkQueue waitSemaphore: semaphore [
    "VkPresentInfoKHR (64 bytes):
     0:sType  8:pNext  16:waitSemaphoreCount  20:pWaitSemaphores(ptr)  28:swapchainCount  32:pSwapchains(ptr)  40:pImageIndices(ptr)  48:pResults(ptr)"
    | semBuf presentInfo result |
    semBuf := ExternalAddress allocate: 8.
    [ semBuf pointerAt: 1 put: semaphore getHandle.
      presentInfo := ExternalAddress allocate: 64.
      [ | idxBuf swapBuf |
        idxBuf := ExternalAddress allocate: 4.
        swapBuf := ExternalAddress allocate: 8.
        [ idxBuf unsignedLongAt: 1 put: imageIndex.
          swapBuf pointerAt: 1 put: handle getHandle.
          presentInfo unsignedLongAt: 1  put: VkStructureType presentInfoKHR.
          presentInfo pointerAt:   9  put: ExternalAddress null.
          presentInfo unsignedLongAt: 17 put: 1.
          presentInfo pointerAt:   25 put: semBuf.
          presentInfo unsignedLongAt: 33 put: 1.
          presentInfo pointerAt:   41 put: swapBuf.
          presentInfo pointerAt:   49 put: idxBuf.
          presentInfo pointerAt:   57 put: ExternalAddress null.
          result := Vk queuePresentKHR: aVkQueue handle pPresentInfo: presentInfo.
          Vk checkResult: result
        ] ensure: [ idxBuf free. swapBuf free ]
      ] ensure: [ presentInfo free ]
    ] ensure: [ semBuf free ]
]
