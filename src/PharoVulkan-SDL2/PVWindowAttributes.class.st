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

{ #category : 'initialize-release' }
PVWindowAttributes >> initialize [
    super initialize.
    vulkanAttributes := nil
]

{ #category : 'accessing' }
PVWindowAttributes >> vulkanAttributes [
    ^ vulkanAttributes
]

{ #category : 'accessing' }
PVWindowAttributes >> vulkanAttributes: anAttrs [
    vulkanAttributes := anAttrs
]
