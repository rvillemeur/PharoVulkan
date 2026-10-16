"
Named constants for VkPipelineStageFlagBits2 (VK_KHR_synchronization2), the stage half of the memory barriers a dependency info carries and of the submissions in a VkSubmitInfo2. The values are sixty-four bits wide, which is why a barrier declares its mask fields as uint64. Key methods: allTransferBit, hostBit, colorAttachmentOutputBit, and namedBits, through which the inherited nameForFlags: decodes a mask for a view. VkAccess2 holds the access half of the same barriers.
"
Class {
	#name : 'VkPipelineStage2',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkPipelineStage2 class >> allTransferBit [
	"VK_PIPELINE_STAGE_2_ALL_TRANSFER_BIT, bit 12."

	^ 4096
]

{ #category : 'constants' }
VkPipelineStage2 class >> colorAttachmentOutputBit [
	^ 1024
]

{ #category : 'constants' }
VkPipelineStage2 class >> hostBit [
	"VK_PIPELINE_STAGE_2_HOST_BIT, bit 14."

	^ 16384
]

{ #category : 'decoding' }
VkPipelineStage2 class >> namedBits [
	"Lowest bit first, as the inherited decoder expects. Only the bits this project records are
	 named; a mask carrying any other bit shows it as hex rather than hiding it."

	^ {
		  (self colorAttachmentOutputBit -> 'ColorAttachmentOutput').
		  (self allTransferBit -> 'AllTransfer').
		  (self hostBit -> 'Host') }
]
