"
OSWindowAttributes subclass carrying a vulkanAttributes slot. Set on the OSWindow before opening to signal that a Vulkan surface should be created by the backend.
"
Class {
	#name : 'PVWindowAttributes',
	#superclass : 'OSWindowAttributes',
	#instVars : [
		'vulkanAttributes'
	],
	#category : 'PharoVulkan-SDL2',
	#package : 'PharoVulkan-SDL2'
}

{ #category : 'instance creation' }
PVWindowAttributes class >> newVulkan [
    ^ self new vulkanAttributes: OSVulkanAttributes new; yourself
]

{ #category : 'accessing' }
PVWindowAttributes >> vulkanAttributes [
    ^ vulkanAttributes
]

{ #category : 'accessing' }
PVWindowAttributes >> vulkanAttributes: anAttrs [
    vulkanAttributes := anAttrs
]
