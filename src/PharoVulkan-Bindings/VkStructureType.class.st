"
Named constants for the sType field present in most Vulkan structs.
All methods are class-side and return the integer discriminant value.
Generated from vk.xml; the Phase 1 subset is hand-written here.
Key methods: applicationInfo, instanceCreateInfo (class-side).
"
Class {
	#name : 'VkStructureType',
	#superclass : 'Object',
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'structure-types' }
VkStructureType class >> applicationInfo [           ^ 0
]

{ #category : 'structure-types' }
VkStructureType class >> bufferCreateInfo [          ^ 12
]

{ #category : 'structure-types' }
VkStructureType class >> commandBufferAllocateInfo [ ^ 40
]

{ #category : 'structure-types' }
VkStructureType class >> commandBufferBeginInfo [    ^ 42
]

{ #category : 'structure-types' }
VkStructureType class >> commandPoolCreateInfo [     ^ 39
]

{ #category : 'structure-types' }
VkStructureType class >> computePipelineCreateInfo [ ^ 29
]

{ #category : 'structure-types' }
VkStructureType class >> descriptorPoolCreateInfo [  ^ 33
]

{ #category : 'structure-types' }
VkStructureType class >> descriptorSetLayoutCreateInfo [ ^ 37
]

{ #category : 'structure-types' }
VkStructureType class >> deviceCreateInfo [          ^ 3
]

{ #category : 'structure-types' }
VkStructureType class >> deviceQueueCreateInfo [     ^ 2
]

{ #category : 'structure-types' }
VkStructureType class >> instanceCreateInfo [        ^ 1
]

{ #category : 'structure-types' }
VkStructureType class >> memoryAllocateInfo [        ^ 5
]

{ #category : 'structure-types' }
VkStructureType class >> pipelineLayoutCreateInfo [  ^ 30
]

{ #category : 'structure-types' }
VkStructureType class >> shaderModuleCreateInfo [    ^ 16
]

{ #category : 'structure-types' }
VkStructureType class >> submitInfo [                ^ 4
]

{ #category : 'structure-types' }
VkStructureType class >> writeDescriptorSet [        ^ 35
]
