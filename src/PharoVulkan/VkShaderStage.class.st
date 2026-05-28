"
Named constants for VkShaderStageFlagBits bitmask values used in pipeline layout and shader module creation. Key methods: vertexBit (1), fragmentBit (16), computeBit (32).
"
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
