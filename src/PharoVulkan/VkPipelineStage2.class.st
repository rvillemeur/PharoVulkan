"
Named constants for VkPipelineStageFlagBits2 (VK_KHR_synchronization2) bitmask values used in VkSubmitInfo2 and memory barriers. Key method: colorAttachmentOutputBit (= 1024).
"
Class {
	#name : 'VkPipelineStage2',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
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
