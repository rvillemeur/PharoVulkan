"
Describes one Vulkan type as parsed from vk.xml.
category is a Symbol: #struct, #union, #handle, #enum, #bitmask, #basetype, #funcpointer.
members is an OrderedCollection of VkMemberDescriptor.
"
Class {
	#name : 'VkTypeDescriptor',
	#superclass : 'Object',
	#instVars : [
		'name',
		'category',
		'members',
		'requires',
		'alias'
	],
	#category : 'PharoVulkan-Generator',
	#package : 'PharoVulkan',
	#tag : 'Generator'
}

{ #category : 'accessing' }
VkTypeDescriptor >> alias [
    ^ alias
]

{ #category : 'accessing' }
VkTypeDescriptor >> alias: aValue [
    alias := aValue
]

{ #category : 'accessing' }
VkTypeDescriptor >> category [
    ^ category
]

{ #category : 'accessing' }
VkTypeDescriptor >> category: aValue [
    category := aValue
]

{ #category : 'accessing' }
VkTypeDescriptor >> members [
    ^ members
]

{ #category : 'accessing' }
VkTypeDescriptor >> members: aValue [
    members := aValue
]

{ #category : 'accessing' }
VkTypeDescriptor >> name [
    ^ name
]

{ #category : 'accessing' }
VkTypeDescriptor >> name: aValue [
    name := aValue
]

{ #category : 'accessing' }
VkTypeDescriptor >> requires [
    ^ requires
]

{ #category : 'accessing' }
VkTypeDescriptor >> requires: aValue [
    requires := aValue
]
