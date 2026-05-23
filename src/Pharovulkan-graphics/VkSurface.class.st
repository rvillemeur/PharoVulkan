Class {
	#name : 'VkSurface',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'instance',
		'physicalDevice'
	],
	#category : 'Pharovulkan-graphics',
	#package : 'Pharovulkan-graphics'
}

{ #category : 'instance creation' }
VkSurface class >> fromWindow: aVulkanBackendWindow instance: aVkInstance physicalDevice: aVkPhysicalDevice [
    | s |
    s := self new.
    s initializeWithWindow: aVulkanBackendWindow instance: aVkInstance physicalDevice: aVkPhysicalDevice.
    ^ s
]

{ #category : 'lifecycle' }
VkSurface >> destroy [
    handle ifNotNil: [
        Vk destroySurfaceKHR: instance surface: handle allocator: ExternalAddress null.
        handle := nil ]
]

{ #category : 'accessing' }
VkSurface >> handle [
    ^ handle
]

{ #category : 'initialize-release' }
VkSurface >> initializeWithWindow: aWindow instance: aVkInstance physicalDevice: aVkPhysDev [
    instance := aVkInstance.
    physicalDevice := aVkPhysDev.
    handle := aWindow createVulkanSurface: aVkInstance
]

{ #category : 'accessing' }
VkSurface >> physicalDevice [
    ^ physicalDevice
]

{ #category : 'querying' }
VkSurface >> queryCapabilitiesInto: capsBuf [
    | result |
    result := Vk getPhysicalDeviceSurfaceCapabilitiesKHR: physicalDevice handle surface: handle pSurfaceCapabilities: capsBuf.
    Vk checkResult: result
]

{ #category : 'querying' }
VkSurface >> supportsPresentation: queueFamilyIndex [
    | pSupported result |
    pSupported := ExternalAddress allocate: 4.
    [
        result := Vk getPhysicalDeviceSurfaceSupportKHR: physicalDevice handle
            queueFamilyIndex: queueFamilyIndex
            surface: handle
            pSupported: pSupported.
        Vk checkResult: result.
        ^ (pSupported unsignedLongAt: 1) = 1
    ] ensure: [ pSupported free ]
]
