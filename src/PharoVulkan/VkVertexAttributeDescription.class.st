"
Vertex attribute description for VkPipelineVertexInputStateCreateInfo. Holds the shader location, buffer binding index, VkFormat of the attribute data, and byte offset within the vertex. Instantiate via location:binding:format:offset:.
"
Class {
	#name : 'VkVertexAttributeDescription',
	#superclass : 'Object',
	#instVars : [
		'location',
		'binding',
		'format',
		'offset'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'instance creation' }
VkVertexAttributeDescription class >> location: l binding: b format: f offset: o [
	^ self new location: l; binding: b; format: f; offset: o; yourself
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> binding [
	^ binding
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> binding: v [
	binding := v
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> format [
	^ format
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> format: v [
	format := v
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> location [
	^ location
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> location: v [
	location := v
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> offset [
	^ offset
]

{ #category : 'accessing' }
VkVertexAttributeDescription >> offset: v [
	offset := v
]
