"
Top-level Vulkan context. Owns the VkInstance, selects a physical device and queue family, creates a logical VkDevice, and retrieves the queue. Key methods: computeContextForExtensions:, graphicsContextForExtensions:, destroy.
"
Class {
	#name : 'VkContext',
	#superclass : 'Object',
	#instVars : [
		'instance',
		'physicalDevice',
		'device',
		'computeQueue',
		'computeQueueFamily'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan-Core'
}

{ #category : 'factory' }
VkContext class >> computeContext [
    ^ self new initializeCompute
]

{ #category : 'private' }
VkContext >> buildDeviceCreateInfo: queueInfoBuf [
    | sync2Feat buf |
    "VkPhysicalDeviceSynchronization2Features: sType=1000314007, sync2=1"
    sync2Feat := ExternalAddress allocate: 24.
    sync2Feat unsignedLongAt: 1 put: 1000314007.   "sType"
    sync2Feat pointerAt: 9 put: ExternalAddress null. "pNext"
    sync2Feat unsignedLongAt: 17 put: 1.            "synchronization2 = VK_TRUE"
    buf := ExternalAddress allocate: 72.
    buf unsignedLongAt: 1 put: 3.         "sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO"
    buf pointerAt: 9 put: sync2Feat.      "pNext -> sync2 feature struct"
    buf unsignedLongAt: 17 put: 0.        "flags"
    buf unsignedLongAt: 21 put: 1.        "queueCreateInfoCount"
    buf pointerAt: 25 put: queueInfoBuf.  "pQueueCreateInfos"
    buf unsignedLongAt: 33 put: 0.        "enabledLayerCount (deprecated)"
    buf pointerAt: 41 put: ExternalAddress null. "ppEnabledLayerNames"
    buf unsignedLongAt: 49 put: 0.        "enabledExtensionCount"
    buf pointerAt: 57 put: ExternalAddress null. "ppEnabledExtensionNames"
    buf pointerAt: 65 put: ExternalAddress null. "pEnabledFeatures"
    ^ buf
]

{ #category : 'private' }
VkContext >> buildDeviceQueueCreateInfo: familyIndex [
    "VkDeviceQueueCreateInfo layout (64 bytes):"
    "  0: sType=2  4: pad  8: pNext=0  16: flags=0  20: familyIndex  24: queueCount=1  28: pad  32: pPriorities"
    | buf priorityBuf |
    priorityBuf := ExternalAddress allocate: 4.
    priorityBuf floatAt: 1 put: 1.0.
    buf := ExternalAddress allocate: 40.
    buf unsignedLongAt: 1 put: 2.           "sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO"
    buf unsignedLongAt: 5 put: 0.           "pad"
    buf pointerAt: 9 put: ExternalAddress null.  "pNext"
    buf unsignedLongAt: 17 put: 0.          "flags"
    buf unsignedLongAt: 21 put: familyIndex. "queueFamilyIndex"
    buf unsignedLongAt: 25 put: 1.          "queueCount"
    buf unsignedLongAt: 29 put: 0.          "pad"
    buf pointerAt: 33 put: priorityBuf.     "pQueuePriorities"
    ^ buf
]

{ #category : 'accessing' }
VkContext >> computeQueue [
    ^ computeQueue
]

{ #category : 'accessing' }
VkContext >> computeQueueFamily [
    ^ computeQueueFamily
]

{ #category : 'initialization' }
VkContext >> createGraphicsDevice [
    | queueInfo sync2Feat extNameBytes extName extPtrBuf deviceInfo devBuf result devHandle |
    queueInfo := self buildDeviceQueueCreateInfo: computeQueueFamily.
    sync2Feat := ExternalAddress allocate: 24.
    sync2Feat unsignedLongAt: 1 put: 1000314007.
    sync2Feat pointerAt: 9 put: ExternalAddress null.
    sync2Feat unsignedLongAt: 17 put: 1.
    extNameBytes := 'VK_KHR_swapchain' asByteArray copyWith: 0.
    extName := ExternalAddress allocate: extNameBytes size.
    [ 1 to: extNameBytes size do: [:i | extName byteAt: i put: (extNameBytes at: i)].
      extPtrBuf := ExternalAddress allocate: 8.
      [ extPtrBuf pointerAt: 1 put: extName.
        deviceInfo := ExternalAddress allocate: 72.
        [ deviceInfo unsignedLongAt: 1 put: 3.
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
          [ result := Vk createDevice: physicalDevice handle createInfo: deviceInfo allocator: ExternalAddress null deviceOut: devBuf.
            Vk checkResult: result.
            devHandle := VkDevice_H fromHandle: (devBuf pointerAt: 1).
            device := VkDevice on: devHandle physicalDevice: physicalDevice context: self
          ] ensure: [ devBuf free ]
        ] ensure: [ deviceInfo free ]
      ] ensure: [ extPtrBuf free ]
    ] ensure: [ extName free ]
]

{ #category : 'initialization' }
VkContext >> createLogicalDevice [
    | queueInfo deviceInfo devBuf result devHandle |
    "Build VkDeviceQueueCreateInfo (sType=2, familyIdx, queueCount=1, pPriorities)"
    queueInfo := self buildDeviceQueueCreateInfo: computeQueueFamily.
    deviceInfo := self buildDeviceCreateInfo: queueInfo.
    devBuf := ExternalAddress allocate: 8.
    [ result := Vk createDevice: physicalDevice handle
        createInfo: deviceInfo
        allocator: ExternalAddress null
        deviceOut: devBuf.
      Vk checkResult: result.
      devHandle := VkDevice_H fromHandle: (devBuf pointerAt: 1).
      device := VkDevice on: devHandle physicalDevice: physicalDevice context: self.
    ] ensure: [ devBuf free ]
]

{ #category : 'lifecycle' }
VkContext >> destroy [
    device ifNotNil: [ device destroy. device := nil ].
    instance ifNotNil: [
        Vk destroyInstance: instance allocator: ExternalAddress null.
        instance := nil ]
]

{ #category : 'accessing' }
VkContext >> device [
    ^ device
]

{ #category : 'initialization' }
VkContext >> fetchComputeQueue [
    | buf |
    buf := ExternalAddress allocate: 8.
    [ Vk getDeviceQueue: device handle
        queueFamilyIndex: computeQueueFamily
        queueIndex: 0
        queue: buf.
      computeQueue := VkQueue on: (VkQueue_H fromHandle: (buf pointerAt: 1))
          familyIndex: computeQueueFamily
    ] ensure: [ buf free ]
]

{ #category : 'initialization' }
VkContext >> initializeCompute [
	"Create instance with Vulkan 1.3 API version so device dispatch table includes vkQueueSubmit2."
	| appInfo info buf result |
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
			info unsignedLongAt: 1 put: 1.
			info pointerAt: 9 put: ExternalAddress null.
			info unsignedLongAt: 17 put: 0.
			info pointerAt: 25 put: appInfo.
			info unsignedLongAt: 33 put: 0.
			info pointerAt: 41 put: ExternalAddress null.
			info unsignedLongAt: 49 put: 0.
			info pointerAt: 57 put: ExternalAddress null.
			buf := ExternalAddress allocate: 8.
			[
				result := Vk primCreateInstance: info allocator: ExternalAddress null instanceOut: buf.
				Vk checkResult: result.
				instance := VkInstance_H fromHandle: (buf pointerAt: 1)
			] ensure: [ buf free ]
		] ensure: [ info free ]
	] ensure: [ appInfo free ].
	self selectPhysicalDevice.
	self createLogicalDevice.
	self fetchComputeQueue.
	^ self
]

{ #category : 'initialization' }
VkContext >> initializeGraphicsWithExtensions: extNames [
    | appInfo info extPtrs extArray buf result |
    appInfo := ExternalAddress allocate: 48.
    [ appInfo unsignedLongAt: 1 put: 0.
      appInfo pointerAt: 9 put: ExternalAddress null.
      appInfo pointerAt: 17 put: ExternalAddress null.
      appInfo unsignedLongAt: 25 put: 0.
      appInfo pointerAt: 33 put: ExternalAddress null.
      appInfo unsignedLongAt: 41 put: 0.
      appInfo unsignedLongAt: 45 put: 4206592.
      info := ExternalAddress allocate: 64.
      [ extPtrs := extNames collect: [:n |
            | bytes p |
            bytes := n asByteArray copyWith: 0.
            p := ExternalAddress allocate: bytes size.
            1 to: bytes size do: [:i | p byteAt: i put: (bytes at: i)].
            p].
        extArray := ExternalAddress allocate: extNames size * 8.
        [ extPtrs doWithIndex: [:p :i | extArray pointerAt: (i - 1) * 8 + 1 put: p].
          info unsignedLongAt: 1 put: 1.
          info pointerAt: 9 put: ExternalAddress null.
          info unsignedLongAt: 17 put: 0.
          info pointerAt: 25 put: appInfo.
          info unsignedLongAt: 33 put: 0.
          info pointerAt: 41 put: ExternalAddress null.
          info unsignedLongAt: 49 put: extNames size.
          info pointerAt: 57 put: extArray.
          buf := ExternalAddress allocate: 8.
          [ result := Vk primCreateInstance: info allocator: ExternalAddress null instanceOut: buf.
            Vk checkResult: result.
            instance := VkInstance_H fromHandle: (buf pointerAt: 1)
          ] ensure: [ buf free ]
        ] ensure: [ extArray free. extPtrs do: [:p | p free] ]
      ] ensure: [ info free ]
    ] ensure: [ appInfo free ].
    self selectGraphicsPhysicalDevice.
    self createGraphicsDevice.
    self fetchGraphicsQueue.
    ^ self
]

{ #category : 'accessing' }
VkContext >> instance [
    ^ instance
]

{ #category : 'accessing' }
VkContext >> physicalDevice [
    ^ physicalDevice
]

{ #category : 'initialization' }
VkContext >> selectPhysicalDevice [
    | handles |
    handles := Vk enumeratePhysicalDevices: instance.
    handles isEmpty ifTrue: [ VkError signal: 'No Vulkan physical devices found' ].
    "Pick first device that has a compute queue"
    handles do: [ :h |
        | pd |
        pd := VkPhysicalDevice on: h.
        pd findComputeQueueFamily ifNotNil: [ :idx |
            physicalDevice := pd.
            computeQueueFamily := idx.
            ^ self ] ].
    VkError signal: 'No device with compute queue found'
]
