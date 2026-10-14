"
Named constants for VkAccessFlagBits2 (VK_KHR_synchronization2, core since Vulkan 1.3), the access half of the memory barriers a dependency info carries. The values are sixty-four bits wide, which is why a barrier declares its mask fields as uint64. Key methods: transferWriteBit, hostReadBit, and namedBits, through which the inherited nameForFlags: decodes a mask for a view. VkPipelineStage2 holds the stage half of the same barriers.
"
Class {
	#name : 'VkAccess2',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkAccess2 class >> hostReadBit [
	"VK_ACCESS_2_HOST_READ_BIT, bit 13."

	^ 8192
]

{ #category : 'decoding' }
VkAccess2 class >> namedBits [
	"Lowest bit first, as the inherited decoder expects. Only the bits this project records are
	 named; a mask carrying any other bit shows it as hex rather than hiding it."

	^ {
		  (self transferWriteBit -> 'TransferWrite').
		  (self hostReadBit -> 'HostRead') }
]

{ #category : 'constants' }
VkAccess2 class >> transferWriteBit [
	"VK_ACCESS_2_TRANSFER_WRITE_BIT, bit 12."

	^ 4096
]
