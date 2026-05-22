"
Describes one parameter of a Vulkan function as parsed from vk.xml.
optional is a Boolean; len is a String or nil (names the length parameter for arrays).
"
Class {
	#name : 'VkParamDescriptor',
	#superclass : 'Object',
	#instVars : [
		'name',
		'type',
		'isPointer',
		'isConst',
		'optional',
		'len'
	],
	#category : 'PharoVulkan-Generator',
	#package : 'PharoVulkan-Generator'
}

{ #category : 'accessing' }
VkParamDescriptor >> isConst [
    ^ isConst
]

{ #category : 'accessing' }
VkParamDescriptor >> isConst: aValue [
    isConst := aValue
]

{ #category : 'accessing' }
VkParamDescriptor >> isPointer [
    ^ isPointer
]

{ #category : 'accessing' }
VkParamDescriptor >> isPointer: aValue [
    isPointer := aValue
]

{ #category : 'accessing' }
VkParamDescriptor >> len [
    ^ len
]

{ #category : 'accessing' }
VkParamDescriptor >> len: aValue [
    len := aValue
]

{ #category : 'accessing' }
VkParamDescriptor >> name [
    ^ name
]

{ #category : 'accessing' }
VkParamDescriptor >> name: aValue [
    name := aValue
]

{ #category : 'accessing' }
VkParamDescriptor >> optional [
    ^ optional
]

{ #category : 'accessing' }
VkParamDescriptor >> optional: aValue [
    optional := aValue
]

{ #category : 'accessing' }
VkParamDescriptor >> type [
    ^ type
]

{ #category : 'accessing' }
VkParamDescriptor >> type: aValue [
    type := aValue
]
