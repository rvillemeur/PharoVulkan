"
Tests for PharoVulkan-Bindings correctness.
Tests cover result codes, structure types, handle creation, and queue flags
without requiring libvulkan to be installed.
"
Class {
	#name : 'VkBindingsTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Bindings',
	#package : 'PharoVulkan-Tests-Bindings'
}

{ #category : 'as yet unclassified' }
VkBindingsTest >> testCreateDestroyInstance [
    | info instance |
    info := VkInstanceCreateInfo new.
    instance := Vk createInstance: info.
    self assert: instance isNotNil.
    Vk destroyInstance: instance allocator: ExternalAddress null
]

{ #category : 'as yet unclassified' }
VkBindingsTest >> testEnumeratePhysicalDevices [
    | info instance devices |
    info := VkInstanceCreateInfo new.
    instance := Vk createInstance: info.
    [ devices := Vk enumeratePhysicalDevices: instance.
      self assert: devices size > 0 ]
    ensure: [ Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'as yet unclassified' }
VkBindingsTest >> testGeneratorIsIdempotent [
    "Idempotency: generating an existing enum creates no new class."
    | gen desc before after |
    gen := VkBindingGenerator new.
    desc := VkEnumDescriptor new.
    desc name: 'VkResult'.
    desc values: OrderedCollection new.
    before := Smalltalk allClasses size.
    gen generateEnum: desc.
    after := Smalltalk allClasses size.
    self assert: after - before equals: 0
]

{ #category : 'as yet unclassified' }
VkBindingsTest >> testLibraryLoads [
    | lib |
    lib := VkLibrary uniqueInstance.
    self assert: lib isNotNil
]

{ #category : 'as yet unclassified' }
VkBindingsTest >> testPhysicalDeviceProperties [
    | info instance devices props name |
    info := VkInstanceCreateInfo new.
    instance := Vk createInstance: info.
    [ devices := Vk enumeratePhysicalDevices: instance.
      props := VkPhysicalDeviceProperties new.
      Vk getPhysicalDeviceProperties: (devices at: 1) into: props.
      name := props deviceNameString.
      self assert: (name isKindOf: String).
      self assert: name isNotEmpty ]
    ensure: [ Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'tests' }
VkBindingsTest >> testQueueFlagsConstants [
    "VkQueueFlags must expose named bit constants."
    self assert: VkQueueFlags graphicsBit equals: 1.
    self assert: VkQueueFlags computeBit equals: 2.
    self assert: VkQueueFlags transferBit equals: 4
]

{ #category : 'tests' }
VkBindingsTest >> testStructureTypeConstants [
    "VkStructureType must expose named constants — no magic numbers."
    self assert: VkStructureType applicationInfo equals: 0.
    self assert: VkStructureType instanceCreateInfo equals: 1
]

{ #category : 'tests' }
VkBindingsTest >> testVkApplicationInfoSType [
    "VkApplicationInfo initialize must set sType to applicationInfo."
    | info |
    info := VkApplicationInfo new.
    self assert: info sType equals: VkStructureType applicationInfo
]

{ #category : 'tests' }
VkBindingsTest >> testVkHandleIsNull [
    "A freshly created VkHandle with no backing pointer must report isNull."
    | h |
    h := VkHandle new.
    self assert: h isNull
]

{ #category : 'tests' }
VkBindingsTest >> testVkInstanceCreateInfoSType [
    "VkInstanceCreateInfo initialize must set sType to instanceCreateInfo."
    | info |
    info := VkInstanceCreateInfo new.
    self assert: info sType equals: VkStructureType instanceCreateInfo
]

{ #category : 'tests' }
VkBindingsTest >> testVkQueueFamilyNotCompute [
    "supportsCompute must return false when only graphicsBit is set."
    | props |
    props := VkQueueFamilyProperties new.
    props queueFlags: VkQueueFlags graphicsBit.
    self deny: props supportsCompute
]

{ #category : 'tests' }
VkBindingsTest >> testVkQueueFamilySupportsCompute [
    "supportsCompute must return true when computeBit is set."
    | props |
    props := VkQueueFamilyProperties new.
    props queueFlags: VkQueueFlags computeBit.
    self assert: props supportsCompute
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultError [
    "Negative VkResult codes must be errors."
    | r |
    r := VkResult withCode: -1.
    self deny: r isSuccess.
    self assert: r isError.
    self assert: r name equals: 'VK_ERROR_OUT_OF_HOST_MEMORY'
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultNameForUnknownCode [
    "Unknown codes get a fallback name that includes the code value."
    | r |
    r := VkResult withCode: 99999.
    self assert: (r name beginsWith: 'VK_UNKNOWN')
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultSignals [
    "VkResult signal must raise VkError for error codes."
    | r |
    r := VkResult withCode: -1.
    self should: [ r signal ] raise: VkError
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultSuccess [
    "VkResult withCode: 0 must be a success result."
    | r |
    r := VkResult withCode: 0.
    self assert: r isSuccess.
    self deny: r isError.
    self assert: r name equals: 'VK_SUCCESS'
]

{ #category : 'as yet unclassified' }
VkBindingsTest >> vkXmlPath [
    ^ FileLocator image parent parent parent parent / 'sources' / 'PharoVulkan' / 'vk.xml'
]
