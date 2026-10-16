"
How the driver assembles primitives from the vertex run, one constant per topology. Only the topology this project draws with is named; VkValueConstants answers nil for a value no constant here carries, so a view shows the raw number rather than a wrong name.

VkRenderConfig class >> primitiveTopologyTriangleList delegates here, so the value has one home.
"
Class {
	#name : 'VkPrimitiveTopology',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkPrimitiveTopology class >> constantProtocol [

	^ 'constants'
]

{ #category : 'constants' }
VkPrimitiveTopology class >> triangleList [
	"Three vertices make one triangle and the next three make the next one: the shape every
	 draw in this project uses. The strip and fan topologies share vertices between triangles,
	 which the vertex run here is not laid out for."

	^ 3
]
