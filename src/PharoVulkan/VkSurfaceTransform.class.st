"
Named constants for VkSurfaceTransformFlagBitsKHR, how a surface's contents are rotated or mirrored before they are presented. All nine bits the specification declares are named, not only the identity this project asks for: the driver reports which transforms a surface supports and which one it is currently in, and a view must be able to name whatever it reported. A VkFlagConstants subclass, so nameForFlags: decodes a mask by reading namedBits.
"
Class {
	#name : 'VkSurfaceTransform',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkSurfaceTransform class >> horizontalMirrorBit [

	^ 16
]

{ #category : 'constants' }
VkSurfaceTransform class >> horizontalMirrorRotate180Bit [

	^ 64
]

{ #category : 'constants' }
VkSurfaceTransform class >> horizontalMirrorRotate270Bit [

	^ 128
]

{ #category : 'constants' }
VkSurfaceTransform class >> horizontalMirrorRotate90Bit [

	^ 32
]

{ #category : 'constants' }
VkSurfaceTransform class >> identityBit [

	^ 1
]

{ #category : 'constants' }
VkSurfaceTransform class >> inheritBit [

	^ 256
]

{ #category : 'decoding' }
VkSurfaceTransform class >> namedBits [
	"Value -> name for every surface transform the specification declares, lowest bit first.
	 All nine are named rather than only the identity this project asks for: the driver
	 reports whichever one the display is rotated to, and a view must name what it reported."

	^ {
		  (self identityBit -> 'Identity').
		  (self rotate90Bit -> 'Rotate90').
		  (self rotate180Bit -> 'Rotate180').
		  (self rotate270Bit -> 'Rotate270').
		  (self horizontalMirrorBit -> 'HorizontalMirror').
		  (self horizontalMirrorRotate90Bit -> 'HorizontalMirrorRotate90').
		  (self horizontalMirrorRotate180Bit -> 'HorizontalMirrorRotate180').
		  (self horizontalMirrorRotate270Bit -> 'HorizontalMirrorRotate270').
		  (self inheritBit -> 'Inherit') }
]

{ #category : 'constants' }
VkSurfaceTransform class >> rotate180Bit [

	^ 4
]

{ #category : 'constants' }
VkSurfaceTransform class >> rotate270Bit [

	^ 8
]

{ #category : 'constants' }
VkSurfaceTransform class >> rotate90Bit [

	^ 2
]
