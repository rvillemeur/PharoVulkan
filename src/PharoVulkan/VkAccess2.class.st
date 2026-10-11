"
Named constants for VkAccessFlagBits2 (VK_KHR_synchronization2, core since Vulkan 1.3) used in the memory barriers a dependency info carries. The values are 64-bit, so a barrier writes them with unsignedLongLongAt:put: rather than unsignedLongAt:put:. Key methods: transferWriteBit, hostReadBit. VkPipelineStage2 holds the stage half of the same barriers.
"
Class {
	#name : 'VkAccess2',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkAccess2 class >> hostReadBit [
	"VK_ACCESS_2_HOST_READ_BIT, bit 13."

	^ 8192
]

{ #category : 'constants' }
VkAccess2 class >> transferWriteBit [
	"VK_ACCESS_2_TRANSFER_WRITE_BIT, bit 12."

	^ 4096
]
