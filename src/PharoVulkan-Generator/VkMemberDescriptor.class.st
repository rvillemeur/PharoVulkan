"
Describes one member of a Vulkan struct as parsed from vk.xml.
isPointer and isConst are Booleans; arrayLen is a String or nil.
"
Class {
	#name : 'VkMemberDescriptor',
	#superclass : 'Object',
	#instVars : [
		'name',
		'type',
		'isPointer',
		'isConst',
		'arrayLen'
	],
	#category : 'PharoVulkan-Generator-Vulkan',
	#package : 'PharoVulkan-Generator',
	#tag : 'Vulkan'
}

{ #category : 'accessing' }
VkMemberDescriptor >> arrayLen [
    ^ arrayLen
]

{ #category : 'accessing' }
VkMemberDescriptor >> arrayLen: aValue [
    arrayLen := aValue
]

{ #category : 'accessing' }
VkMemberDescriptor >> isConst [
    ^ isConst
]

{ #category : 'accessing' }
VkMemberDescriptor >> isConst: aValue [
    isConst := aValue
]

{ #category : 'accessing' }
VkMemberDescriptor >> isPointer [
    ^ isPointer
]

{ #category : 'accessing' }
VkMemberDescriptor >> isPointer: aValue [
    isPointer := aValue
]

{ #category : 'accessing' }
VkMemberDescriptor >> name [
    ^ name
]

{ #category : 'accessing' }
VkMemberDescriptor >> name: aValue [
    name := aValue
]

{ #category : 'accessing' }
VkMemberDescriptor >> type [
    ^ type
]

{ #category : 'accessing' }
VkMemberDescriptor >> type: aValue [
    type := aValue
]
