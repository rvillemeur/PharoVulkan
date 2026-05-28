"
Vertex buffer binding description for VkPipelineVertexInputStateCreateInfo. Holds binding index, byte stride between consecutive vertices, and inputRate (0=per-vertex, 1=per-instance). Instantiate via binding:stride:inputRate:.
"
Class {
	#name : 'VkVertexBindingDescription',
	#superclass : 'Object',
	#instVars : [
		'binding',
		'stride',
		'inputRate'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'instance creation' }
VkVertexBindingDescription class >> binding: b stride: s inputRate: r [
	^ self new binding: b; stride: s; inputRate: r; yourself
]

{ #category : 'accessing' }
VkVertexBindingDescription >> binding [
	^ binding
]

{ #category : 'accessing' }
VkVertexBindingDescription >> binding: v [
	binding := v
]

{ #category : 'accessing' }
VkVertexBindingDescription >> inputRate [
	^ inputRate
]

{ #category : 'accessing' }
VkVertexBindingDescription >> inputRate: v [
	inputRate := v
]

{ #category : 'accessing' }
VkVertexBindingDescription >> stride [
	^ stride
]

{ #category : 'accessing' }
VkVertexBindingDescription >> stride: v [
	stride := v
]
