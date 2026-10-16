"
Describes one Vulkan enum or bitmask group as parsed from vk.xml.
type is #enum or #bitmask. values is a Dictionary of valueName String -> Integer.
"
Class {
	#name : 'VkEnumDescriptor',
	#superclass : 'Object',
	#instVars : [
		'name',
		'type',
		'values'
	],
	#category : 'PharoVulkan-Generator-Vulkan',
	#package : 'PharoVulkan-Generator',
	#tag : 'Vulkan'
}

{ #category : 'accessing' }
VkEnumDescriptor >> name [
    ^ name
]

{ #category : 'accessing' }
VkEnumDescriptor >> name: aValue [
    name := aValue
]

{ #category : 'accessing' }
VkEnumDescriptor >> type [
    ^ type
]

{ #category : 'accessing' }
VkEnumDescriptor >> type: aValue [
    type := aValue
]

{ #category : 'accessing' }
VkEnumDescriptor >> values [
    ^ values
]

{ #category : 'accessing' }
VkEnumDescriptor >> values: aValue [
    values := aValue
]
