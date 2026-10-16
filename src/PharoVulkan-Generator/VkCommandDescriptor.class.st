"
Describes one Vulkan function (command) as parsed from vk.xml.
params is an OrderedCollection of VkParamDescriptor.
successCodes and errorCodes are Arrays of String.
"
Class {
	#name : 'VkCommandDescriptor',
	#superclass : 'Object',
	#instVars : [
		'name',
		'returnType',
		'params',
		'successCodes',
		'errorCodes'
	],
	#category : 'PharoVulkan-Generator-Vulkan',
	#package : 'PharoVulkan-Generator',
	#tag : 'Vulkan'
}

{ #category : 'accessing' }
VkCommandDescriptor >> errorCodes [
    ^ errorCodes
]

{ #category : 'accessing' }
VkCommandDescriptor >> errorCodes: aValue [
    errorCodes := aValue
]

{ #category : 'accessing' }
VkCommandDescriptor >> name [
    ^ name
]

{ #category : 'accessing' }
VkCommandDescriptor >> name: aValue [
    name := aValue
]

{ #category : 'accessing' }
VkCommandDescriptor >> params [
    ^ params
]

{ #category : 'accessing' }
VkCommandDescriptor >> params: aValue [
    params := aValue
]

{ #category : 'accessing' }
VkCommandDescriptor >> returnType [
    ^ returnType
]

{ #category : 'accessing' }
VkCommandDescriptor >> returnType: aValue [
    returnType := aValue
]

{ #category : 'accessing' }
VkCommandDescriptor >> successCodes [
    ^ successCodes
]

{ #category : 'accessing' }
VkCommandDescriptor >> successCodes: aValue [
    successCodes := aValue
]
