"
Named constants for VkFormat enum values covering the surface and vertex-attribute formats used in this project. Key methods: b8g8r8a8Unorm (swapchain color), r32g32Sfloat (vec2 position), r32g32b32Sfloat (vec3 color).
"
Class {
	#name : 'VkFormat',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkFormat class >> b8g8r8a8Unorm [
	^ 44
]

{ #category : 'constants' }
VkFormat class >> r32g32Sfloat [
	^ 103
]

{ #category : 'constants' }
VkFormat class >> r32g32b32Sfloat [
	^ 106
]
