Extension { #name : 'VkContext' }

{ #category : '*pharovulkan-graphics' }
VkContext >> createGraphicsDevice [
    | queueInfo sync2Feat extName extPtr extPtrBuf deviceInfo devBuf result devHandle |
    queueInfo := self buildDeviceQueueCreateInfo: computeQueueFamily.
    sync2Feat := ExternalAddress allocate: 24.
    sync2Feat unsignedLongAt: 1 put: 1000314007.
    sync2Feat pointerAt: 9 put: ExternalAddress null.
    sync2Feat unsignedLongAt: 17 put: 1.
    extName := 'VK_KHR_swapchain' asCString.
    extPtrBuf := ExternalAddress allocate: 8.
    [
        extPtrBuf pointerAt: 1 put: extName.
        deviceInfo := ExternalAddress allocate: 72.
        [
            deviceInfo unsignedLongAt: 1 put: 3.
            deviceInfo pointerAt: 9 put: sync2Feat.
            deviceInfo unsignedLongAt: 17 put: 0.
            deviceInfo unsignedLongAt: 21 put: 1.
            deviceInfo pointerAt: 25 put: queueInfo.
            deviceInfo unsignedLongAt: 33 put: 0.
            deviceInfo pointerAt: 41 put: ExternalAddress null.
            deviceInfo unsignedLongAt: 49 put: 1.
            deviceInfo pointerAt: 57 put: extPtrBuf.
            deviceInfo pointerAt: 65 put: ExternalAddress null.
            devBuf := ExternalAddress allocate: 8.
            [
                result := Vk createDevice: physicalDevice handle createInfo: deviceInfo allocator: ExternalAddress null deviceOut: devBuf.
                Vk checkResult: result.
                devHandle := VkDevice_H fromHandle: (devBuf pointerAt: 1).
                device := VkDevice on: devHandle physicalDevice: physicalDevice context: self
            ] ensure: [ devBuf free ]
        ] ensure: [ deviceInfo free ]
    ] ensure: [ extPtrBuf free ]
]

{ #category : '*pharovulkan-graphics' }
VkContext >> fetchGraphicsQueue [
    | buf |
    buf := ExternalAddress allocate: 8.
    [
        Vk getDeviceQueue: device handle queueFamilyIndex: computeQueueFamily queueIndex: 0 queue: buf.
        computeQueue := VkQueue on: (VkQueue_H fromHandle: (buf pointerAt: 1)) familyIndex: computeQueueFamily
    ] ensure: [ buf free ]
]

{ #category : '*pharovulkan-graphics' }
VkContext class >> graphicsContextForExtensions: extNames [
    "extNames: Array of String (from SDL_Vulkan_GetInstanceExtensions)."
    ^ self new initializeGraphicsWithExtensions: extNames
]

{ #category : '*pharovulkan-graphics' }
VkContext >> initializeGraphicsWithExtensions: extNames [
    | appInfo info extPtrs extArray buf result |
    appInfo := ExternalAddress allocate: 48.
    [
        appInfo unsignedLongAt: 1 put: 0.
        appInfo pointerAt: 9 put: ExternalAddress null.
        appInfo pointerAt: 17 put: ExternalAddress null.
        appInfo unsignedLongAt: 25 put: 0.
        appInfo pointerAt: 33 put: ExternalAddress null.
        appInfo unsignedLongAt: 41 put: 0.
        appInfo unsignedLongAt: 45 put: 4206592.
        info := ExternalAddress allocate: 64.
        [
            extPtrs := extNames collect: [:n | n asCString].
            extArray := ExternalAddress allocate: extNames size * 8.
            [
                extPtrs doWithIndex: [:p :i | extArray pointerAt: (i - 1) * 8 + 1 put: p].
                info unsignedLongAt: 1 put: 1.
                info pointerAt: 9 put: ExternalAddress null.
                info unsignedLongAt: 17 put: 0.
                info pointerAt: 25 put: appInfo.
                info unsignedLongAt: 33 put: 0.
                info pointerAt: 41 put: ExternalAddress null.
                info unsignedLongAt: 49 put: extNames size.
                info pointerAt: 57 put: extArray.
                buf := ExternalAddress allocate: 8.
                [
                    result := Vk primCreateInstance: info allocator: ExternalAddress null instanceOut: buf.
                    Vk checkResult: result.
                    instance := VkInstance_H fromHandle: (buf pointerAt: 1)
                ] ensure: [ buf free ]
            ] ensure: [ extArray free ]
        ] ensure: [ info free ]
    ] ensure: [ appInfo free ].
    self selectGraphicsPhysicalDevice.
    self createGraphicsDevice.
    self fetchGraphicsQueue.
    ^ self
]

{ #category : '*pharovulkan-graphics' }
VkContext >> selectGraphicsPhysicalDevice [
    | handles |
    handles := Vk enumeratePhysicalDevices: instance.
    handles isEmpty ifTrue: [ VkError signal: 'No Vulkan physical devices found' ].
    handles do: [ :h |
        | pd |
        pd := VkPhysicalDevice on: h.
        pd findGraphicsQueueFamily ifNotNil: [ :idx |
            physicalDevice := pd.
            computeQueueFamily := idx.
            ^ self ] ].
    VkError signal: 'No device with graphics+compute queue found'
]
