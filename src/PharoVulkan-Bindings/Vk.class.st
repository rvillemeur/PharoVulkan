"
Entry point for all Vulkan function calls. All methods are class-side FFI wrappers
mirroring the Vulkan C API. Mirrors the pattern of Pharo's SDL2 class.
Do not instantiate — use class-side methods only.
Key methods: checkResult: (raises VkError on non-success), ffiLibrary (class-side).
"
Class {
	#name : 'Vk',
	#superclass : 'Object',
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'error handling' }
Vk class >> checkResult: anInteger [
    "Wrap the raw Vulkan result code. Raise VkError if it is not VK_SUCCESS."
    | result |
    result := VkResult withCode: anInteger.
    result isSuccess ifFalse: [ result signal ]
]

{ #category : 'instance-management' }
Vk class >> createInstance: aVkInstanceCreateInfo [
    | buf result instance |
    buf := ExternalAddress allocate: 8.
    [ result := self primCreateInstance: aVkInstanceCreateInfo
        allocator: ExternalAddress null instanceOut: buf.
      self checkResult: result.
      instance := VkInstance_H fromHandle: (buf pointerAt: 1)
    ] ensure: [ buf free ].
    ^ instance
]

{ #category : 'ffi-primitives' }
Vk class >> destroyInstance: aVkInstance_H [
    ^ self ffiCall: #( void vkDestroyInstance (
        VkInstance_H aVkInstance_H,
        void* null ) )
]

{ #category : 'as yet unclassified' }
Vk class >> destroyInstance: aVkInstance_H allocator: pAllocator [
    ^ self ffiCall: #( void vkDestroyInstance (VkInstance_H aVkInstance_H, void* pAllocator) )
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
