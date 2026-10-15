"
Named constants for VkColorSpaceKHR, the colour spaces a surface may accept. Only srgbNonlinearKHR (VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0) is declared, because it is the one every surface supports and the one this project renders in. A VkValueConstants subclass, so the inherited nameForValue: names a colour space by reflection over these constants.
"
Class {
	#name : 'VkColorSpace',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkColorSpace class >> constantProtocol [
	"Where this class files its constants, for the inherited reverse lookup. Every colour
	 space value is distinct, so a value maps to at most one name."

	^ 'constants'
]

{ #category : 'constants' }
VkColorSpace class >> srgbNonlinearKHR [
	"VK_COLOR_SPACE_SRGB_NONLINEAR_KHR — the one colour space every surface supports, and
	 the one this project renders in."

	^ 0
]
