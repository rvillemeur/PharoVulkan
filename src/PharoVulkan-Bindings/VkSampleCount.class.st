"
How many samples a pixel is made of, one constant per bit. Only the single sample count this project asks for is named; VkFlagConstants shows a bit no constant here carries as raw hex, so a view can never hide a count a device reported.

VkRenderConfig class >> sampleCount1Bit delegates here, so the value has one home.
"
Class {
	#name : 'VkSampleCount',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkSampleCount class >> count1Bit [
	"One sample per pixel: no multisampling. The higher counts are bits of their own — two,
	 four and so on — and none is named here, because nothing in this project asks a device
	 for more than one sample."

	^ 1
]

{ #category : 'decoding' }
VkSampleCount class >> namedBits [

	^ { (self count1Bit -> #count1Bit) }
]
