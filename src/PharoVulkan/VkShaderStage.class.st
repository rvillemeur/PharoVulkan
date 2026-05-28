Class {
	#name : 'VkShaderStage',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkShaderStage class >> computeBit [
	^ 32
]

{ #category : 'constants' }
VkShaderStage class >> fragmentBit [
	^ 16
]

{ #category : 'constants' }
VkShaderStage class >> vertexBit [
	^ 1
]
