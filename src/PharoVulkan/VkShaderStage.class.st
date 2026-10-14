"
Named constants for VkShaderStageFlagBits bitmask values used in pipeline layout and shader module creation. Key methods: vertexBit (1), fragmentBit (16), computeBit (32).
"
Class {
	#name : 'VkShaderStage',
	#superclass : 'VkFlagConstants',
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

{ #category : 'decoding' }
VkShaderStage class >> namedBits [
	"Value -> name for every stage bit this class names, lowest bit first. The decoder reads
	 this list, so naming one more stage never touches the decoding itself."

	^ {
		  (self vertexBit -> 'Vertex').
		  (self fragmentBit -> 'Fragment').
		  (self computeBit -> 'Compute') }
]

{ #category : 'constants' }
VkShaderStage class >> vertexBit [
	^ 1
]
