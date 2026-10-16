"
Which colour channels of an attachment a fragment is written to, one constant per bit, plus allChannels for the mask of all four. VkFlagConstants shows a bit no constant here carries as raw hex, so a view can never hide a channel a mask selected.

VkRenderConfig class >> colorWriteMaskRGBA delegates here, so the mask has one home.
"
Class {
	#name : 'VkColorComponent',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkColorComponent class >> aBit [

	^ 8
]

{ #category : 'constants' }
VkColorComponent class >> allChannels [
	"Every colour channel is written, which is what this project asks for: a fragment replaces
	 what is in the attachment, alpha included. Summed from the bits rather than written as
	 fifteen, so the mask cannot disagree with the bits it is made of."

	^ self rBit + self gBit + self bBit + self aBit
]

{ #category : 'constants' }
VkColorComponent class >> bBit [

	^ 4
]

{ #category : 'constants' }
VkColorComponent class >> gBit [

	^ 2
]

{ #category : 'decoding' }
VkColorComponent class >> namedBits [

	^ {
		  (self rBit -> #rBit).
		  (self gBit -> #gBit).
		  (self bBit -> #bBit).
		  (self aBit -> #aBit) }
]

{ #category : 'constants' }
VkColorComponent class >> rBit [

	^ 1
]
