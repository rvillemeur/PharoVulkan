"
Named constants that pipeline creation itself carries, whatever kind of pipeline is being created: pipelinesPerCreate, the number of requests one vkCreate*Pipelines call takes here, and noBasePipelineIndex, the index that means the pipeline derives from no other. Both VkComputePipeline and VkGraphicsPipeline ask for them — the compute pipeline through its own two methods, which delegate here so that neither value is written in two places. A kind of pipeline keeps its own constants on its own class side; only what both kinds share lives here.
"
Class {
	#name : 'VkPipelineCreation',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'constants' }
VkPipelineCreation class >> noBasePipelineIndex [
	"VK_PIPELINE_CREATE_DERIVATIVE is not asked for, so a request here derives from no other
	 pipeline. basePipelineIndex is a signed int32 and the value for no base pipeline is minus
	 one; written through the declared field, so the sign is the field's business rather than the
	 caller's."

	^ -1
]

{ #category : 'constants' }
VkPipelineCreation class >> pipelinesPerCreate [
	"One request per call, so one pipeline comes back and the out parameter the driver answers
	 through is one handle wide. Both kinds of pipeline create one at a time."

	^ 1
]
