"
Named constants for VkVertexInputRate, the rate at which a bound vertex buffer advances: perVertex (VK_VERTEX_INPUT_RATE_VERTEX = 0), which is how every buffer this project binds is read, and perInstance (= 1), declared so a description's rate is named rather than shown as a number even when it is a rate this project does not use. A VkValueConstants subclass, so the inherited nameForValue: names a rate by reflection over these constants; VkVertexInputBindingDescription >> bindingRows asks it.
"
Class {
	#name : 'VkVertexInputRate',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkVertexInputRate class >> constantProtocol [
	"Where this class files its constants, for the inherited reverse lookup. The two rates are
	 distinct values, so a value maps to at most one name."

	^ 'constants'
]

{ #category : 'constants' }
VkVertexInputRate class >> perInstance [
	"VK_VERTEX_INPUT_RATE_INSTANCE — the buffer advances one stride for every instance, so
	 every vertex of one instance reads the same entry. Declared so the rate a description
	 carries is named rather than shown as a number, including the rate this project does not
	 use."

	^ 1
]

{ #category : 'constants' }
VkVertexInputRate class >> perVertex [
	"VK_VERTEX_INPUT_RATE_VERTEX — the buffer advances one stride for every vertex, which is
	 how every buffer this project binds is read."

	^ 0
]
