"
How a polygon is turned into fragments, one constant per mode. Only the mode this project draws with is named; VkValueConstants answers nil for a value no constant here carries, so a view shows the raw number rather than a wrong name.
"
Class {
	#name : 'VkPolygonMode',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkPolygonMode class >> constantProtocol [

	^ 'constants'
]

{ #category : 'constants' }
VkPolygonMode class >> fill [
	"Every triangle is filled with fragments: the only polygon mode this project draws with.
	 The line and point modes need the fillModeNonSolid feature, which nothing here enables."

	^ 0
]
