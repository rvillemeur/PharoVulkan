Extension { #name : 'VkContext' }

{ #category : '*pharovulkan-graphics' }
VkContext >> fetchGraphicsQueue [

	| buf |
	buf := ExternalAddress allocate: 8.
	computeQueue := [
		                Vk
			                getDeviceQueue: device handle
			                queueFamilyIndex: computeQueueFamily
			                queueIndex: 0
			                queue: buf.
		                VkQueue
			                on: (VkQueue_H fromHandle: (buf pointerAt: 1))
			                familyIndex: computeQueueFamily ] ensure: [
		                buf free ]
]

{ #category : '*pharovulkan-graphics' }
VkContext class >> graphicsContextForExtensions: extNames [
    "extNames: Array of String (from SDL_Vulkan_GetInstanceExtensions)."
    ^ self new initializeGraphicsWithExtensions: extNames
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
