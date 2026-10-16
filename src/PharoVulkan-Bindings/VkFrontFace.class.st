"
Which winding of a triangle's vertices makes its front face, one constant per convention. Only the winding this project's vertex data uses is named; VkValueConstants answers nil for a value no constant here carries, so a view shows the raw number rather than a wrong name.
"
Class {
	#name : 'VkFrontFace',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkFrontFace class >> constantProtocol [

	^ 'constants'
]

{ #category : 'constants' }
VkFrontFace class >> counterClockwise [
	"A triangle whose vertices wind counter clockwise in framebuffer space is its front face.
	 This is the winding the vertex data in this project is written in, and the convention
	 Vulkan shares with OpenGL."

	^ 0
]
