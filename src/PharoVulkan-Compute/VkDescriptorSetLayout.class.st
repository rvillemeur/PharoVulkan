"
Vulkan descriptor set layout. Declares the storage-buffer binding schema used by compute shaders. Key method: initializeDevice:bindingCount:.
"
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
    bindings add: { bindingIndex. VkDescriptorType storageBuffer. 1. stageFlags }
]

{ #category : 'lifecycle' }
VkDescriptorSetLayout >> create [
	"VkDescriptorSetLayoutBinding: binding(4)+type(4)+count(4)+stageFlags(4)+pImmutableSamplers(8) = 24 bytes"

	"VkDescriptorSetLayoutCreateInfo: sType=descriptorSetLayoutCreateInfo, pNext, flags=0, bindingCount, pBindings(8)"

	| bindBuf info layoutBuf result |
	bindBuf := ExternalAddress allocate: bindings size * 24.
	handle := [
		          bindings doWithIndex: [ :b :i |
				          | base |
				          base := i - 1 * 24.
				          bindBuf unsignedLongAt: base + 1 put: b first.
				          bindBuf unsignedLongAt: base + 5 put: (b at: 2).
				          bindBuf unsignedLongAt: base + 9 put: (b at: 3).
				          bindBuf unsignedLongAt: base + 13 put: (b at: 4).
				          bindBuf pointerAt: base + 17 put: ExternalAddress null ].
		          info := ExternalAddress allocate: 32.
		          [
			          info
				          unsignedLongAt: 1
				          put: VkStructureType descriptorSetLayoutCreateInfo.
			          info pointerAt: 9 put: ExternalAddress null.
			          info unsignedLongAt: 17 put: 0.
			          info unsignedLongAt: 21 put: bindings size.
			          info pointerAt: 25 put: bindBuf.
			          layoutBuf := ExternalAddress allocate: 8.
			          [
				          result := Vk
					                    createDescriptorSetLayout: device handle
					                    createInfo: info
					                    allocator: ExternalAddress null
					                    setLayoutOut: layoutBuf.
				          Vk checkResult: result.
				          VkDescriptorSetLayout_H fromHandle:
					          (layoutBuf pointerAt: 1) ] ensure: [ layoutBuf free ] ]
			          ensure: [ info free ] ] ensure: [ bindBuf free ]
]

{ #category : 'lifecycle' }
VkDescriptorSetLayout >> destroy [

	handle ifNotNil: [
			Vk
				destroyDescriptorSetLayout: device handle
				descriptorSetLayout: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkDescriptorSetLayout >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkDescriptorSetLayout >> initializeOn: aDevice [
    device := aDevice. bindings := OrderedCollection new
]
