"
Named constants for VkPipelineBindPoint, which of a device's pipeline slots a command or a subpass means. Key methods: graphics, which is zero and so is what a zeroed subpass description already asks for, and compute. VkCommandBuffer still passes the two values inline to vkCmdBindPipeline and vkCmdBindDescriptorSets; those methods write no structure, so they are not part of the declared-layout work and are left for a later tidy.
"
Class {
	#name : 'VkPipelineBindPoint',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkPipelineBindPoint class >> compute [
	"VK_PIPELINE_BIND_POINT_COMPUTE."

	^ 1
]

{ #category : 'reflecting' }
VkPipelineBindPoint class >> constantProtocol [
	"Where this class files its constants, for the inherited reverse lookup."

	^ 'constants'
]

{ #category : 'constants' }
VkPipelineBindPoint class >> graphics [
	"VK_PIPELINE_BIND_POINT_GRAPHICS. Zero, so a subpass that asks for it writes nothing: a
	 zeroed description already says graphics."

	^ 0
]
