Class {
	#name : 'VkShaderStage',
	#superclass : 'Object',
	#category : 'PharoVulkan',
	#package : 'PharoVulkan'
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
