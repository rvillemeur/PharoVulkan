Class {
	#name : 'VkDescriptorSetLayout',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'bindings'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan-Compute'
}

{ #category : 'factory' }
VkDescriptorSetLayout class >> on: aDevice [
    ^ self new initializeOn: aDevice
]

{ #category : 'configuring' }
VkDescriptorSetLayout >> addStorageBufferBinding: bindingIndex stageFlags: stageFlags [
    "Store as Array: (binding, descriptorType=STORAGE_BUFFER=7, count=1, stageFlags)"
    bindings add: { bindingIndex. 7. 1. stageFlags }
]

{ #category : 'lifecycle' }
VkDescriptorSetLayout >> create [
    "VkDescriptorSetLayoutBinding: binding(4)+type(4)+count(4)+stageFlags(4)+pImmutableSamplers(8) = 24 bytes"
    "VkDescriptorSetLayoutCreateInfo: sType=32, pNext, flags=0, bindingCount, pBindings(8)"
    | bindBuf info layoutBuf result |
    bindBuf := ExternalAddress allocate: bindings size * 24.
    [ bindings doWithIndex: [ :b :i |
        | base |
        base := (i - 1) * 24.
        bindBuf unsignedLongAt: base + 1 put: (b at: 1).  "binding"
        bindBuf unsignedLongAt: base + 5 put: (b at: 2).  "descriptorType"
        bindBuf unsignedLongAt: base + 9 put: (b at: 3).  "descriptorCount"
        bindBuf unsignedLongAt: base + 13 put: (b at: 4). "stageFlags"
        bindBuf pointerAt: base + 17 put: ExternalAddress null ]. "pImmutableSamplers"
      info := ExternalAddress allocate: 32.
      [ info unsignedLongAt: 1 put: 32.
        info pointerAt: 9 put: ExternalAddress null.
        info unsignedLongAt: 17 put: 0. "flags"
        info unsignedLongAt: 21 put: bindings size.
        info pointerAt: 25 put: bindBuf.
        layoutBuf := ExternalAddress allocate: 8.
        [ result := Vk createDescriptorSetLayout: device handle createInfo: info allocator: ExternalAddress null setLayoutOut: layoutBuf.
          Vk checkResult: result.
          handle := VkDescriptorSetLayout_H fromHandle: (layoutBuf pointerAt: 1)
        ] ensure: [ layoutBuf free ]
      ] ensure: [ info free ]
    ] ensure: [ bindBuf free ]
]

{ #category : 'lifecycle' }
VkDescriptorSetLayout >> destroy [
    handle ifNotNil: [ Vk destroyDescriptorSetLayout: device handle descriptorSetLayout: handle allocator: ExternalAddress null. handle := nil ]
]

{ #category : 'accessing' }
VkDescriptorSetLayout >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkDescriptorSetLayout >> initializeOn: aDevice [
    device := aDevice. bindings := OrderedCollection new
]
