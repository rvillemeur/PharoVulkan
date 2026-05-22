Class {
	#name : 'PVComputeKernel',
	#superclass : 'Object',
	#instVars : [
		'context',
		'spirvBytes',
		'buffers',
		'workgroupX',
		'workgroupY',
		'workgroupZ',
		'commandPool',
		'descriptorPool',
		'shaderModule',
		'pipeline',
		'pipelineLayout',
		'descriptorSetLayout',
		'descriptorSet'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan-Compute'
}

{ #category : 'instance creation' }
PVComputeKernel class >> on: aContext spirv: bytes [
	| k |
	k := self new.
	k context: aContext.
	k spirvBytes: bytes.
	k buffers: OrderedCollection new.
	k workgroupX: 1 workgroupY: 1 workgroupZ: 1.
	^ k
]

{ #category : 'accessing' }
PVComputeKernel >> bindBuffer: aBuffer [
	buffers add: aBuffer
]

{ #category : 'accessing' }
PVComputeKernel >> buffers: col [
	buffers := col
]

{ #category : 'accessing' }
PVComputeKernel >> context: aContext [
	context := aContext
]

{ #category : 'lifecycle' }
PVComputeKernel >> destroy [
	"Destroy in reverse order"
	commandPool isNil ifFalse: [ commandPool destroy. commandPool := nil ].
	descriptorPool isNil ifFalse: [ descriptorPool destroy. descriptorPool := nil ].
	pipeline isNil ifFalse: [ pipeline destroy. pipeline := nil ].
	pipelineLayout isNil ifFalse: [ pipelineLayout destroy. pipelineLayout := nil ].
	descriptorSetLayout isNil ifFalse: [ descriptorSetLayout destroy. descriptorSetLayout := nil ].
	shaderModule isNil ifFalse: [ shaderModule destroy. shaderModule := nil ]
]

{ #category : 'operations' }
PVComputeKernel >> dispatch: x y: y z: z [
	| cmd |
	cmd := commandPool allocateBuffer.
	cmd do: [:cb |
		cb bindComputePipeline: pipeline.
		cb bindDescriptorSets: (Array with: descriptorSet) pipelineLayout: pipelineLayout.
		cb dispatch: x y: y z: z].
	context computeQueue submit: cmd andWait: true
]

{ #category : 'lifecycle' }
PVComputeKernel >> prepare [
	"Build shader module, DSL, pipeline layout, pipeline, descriptor pool/set, command pool"
	shaderModule := VkShaderModule fromBytes: spirvBytes device: context device.
	descriptorSetLayout := VkDescriptorSetLayout on: context device.
	0 to: buffers size - 1 do: [:i |
		descriptorSetLayout addStorageBufferBinding: i stageFlags: 32].
	descriptorSetLayout create.
	pipelineLayout := VkPipelineLayout on: context device setLayouts: (Array with: descriptorSetLayout).
	pipeline := VkComputePipeline on: shaderModule layout: pipelineLayout device: context device.
	"Pool needs descriptorCount = total bindings across all sets"
	descriptorPool := VkDescriptorPool on: context device maxSets: buffers size.
	descriptorSet := descriptorPool allocateSet: descriptorSetLayout.
	buffers doWithIndex: [:buf :i |
		descriptorSet updateStorageBuffer: buf atBinding: i - 1].
	commandPool := VkCommandPool on: context device queueFamilyIndex: context computeQueueFamily
]

{ #category : 'accessing' }
PVComputeKernel >> spirvBytes: bytes [
	spirvBytes := bytes
]

{ #category : 'accessing' }
PVComputeKernel >> workgroupX: x workgroupY: y workgroupZ: z [
	workgroupX := x. workgroupY := y. workgroupZ := z
]
