"
Vulkan compute pipeline. Wraps a VkPipeline_H created from a SPIR-V compute shader module and a VkPipelineLayout; PVComputeKernel >> prepare builds the one this project dispatches.

The request is declared rather than counted: createInfoForModule:entryPoint:layout: fills a VkComputePipelineCreateInfo with the shader stage nested inside it, freeCreateInfo: gives back the entry point string the request points at and then the request itself, and handleForCreateInfo:on: is the only caller of vkCreateComputePipelines — its out parameter is a run of one handle rather than a structure, which is the one block here still read at an offset. The name of the entered function comes from VkShaderModule class >> defaultEntryPoint, because it belongs to the compiled module rather than to a kind of pipeline. Key methods: class-side on:layout:device:, create, destroy, class-side createInfoForModule:entryPoint:layout:.
"
Class {
	#name : 'VkComputePipeline',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'layout',
		'shaderModule',
		'entryPoint'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'request' }
VkComputePipeline class >> createInfoForModule: aModuleHandle entryPoint: anEntryPointName layout: aLayoutHandle [
	"The request this project creates every compute pipeline from, outside object memory because
	 the driver reads it after this method answers. The nested stage is written through the field
	 rather than built separately: the generated getter answers a view on the request's own
	 bytes, so a write through it lands inside the request. The stage carries its own structure
	 type, which no initializer may write for a nested field, and the entry point becomes a NUL
	 terminated C string the request points at — freeCreateInfo: frees it."

	| request |
	request := VkComputePipelineCreateInfo externalInstance.
	request stage
		sType: VkStructureType pipelineShaderStageCreateInfo;
		stage: VkShaderStage computeBit;
		module: aModuleHandle;
		pName: (Vk allocateCString: anEntryPointName).
	^ request
		  layout: aLayoutHandle;
		  basePipelineIndex: self noBasePipelineIndex;
		  yourself
]

{ #category : 'request' }
VkComputePipeline class >> freeCreateInfo: aCreateInfo [
	"Everything the request owns, in the order that keeps each address readable until it is
	 freed: the entry point string the request points at, then the request's own store."

	self freeEntryPointOf: aCreateInfo.
	aCreateInfo getHandle free
]

{ #category : 'request' }
VkComputePipeline class >> freeEntryPointOf: aCreateInfo [
	"Give back the C string the request points at, and null the field as it goes: the request is
	 the record of where that string is, so a freed address left in it could be read or freed
	 twice."

	aCreateInfo stage pName getHandle free.
	aCreateInfo stage pName: ExternalAddress null
]

{ #category : 'request' }
VkComputePipeline class >> handleForCreateInfo: aCreateInfo on: aDevice [
	"The one call that creates a compute pipeline. The driver answers through an out parameter,
	 which is a run of one handle rather than a structure, so it stays a plain block read by
	 pointerAt: and freed whatever the result. The handle is read before the block goes."

	| handleBlock result |
	handleBlock := ExternalAddress allocate:
		               self pipelinesPerCreate * VkContext pointerSize.
	^ [
	  result := Vk
		            createComputePipelines: aDevice handle
		            pipelineCache: ExternalAddress null
		            createInfoCount: self pipelinesPerCreate
		            createInfos: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            pipelines: handleBlock.
	  Vk checkResult: result.
	  VkPipeline_H fromHandle: (handleBlock pointerAt: 1) ] ensure: [
		  handleBlock free ]
]

{ #category : 'constants' }
VkComputePipeline class >> noBasePipelineIndex [
	"Delegates so the value has one home: the index that means a pipeline derives from no other
	 belongs to pipeline creation rather than to compute, and the graphics pipeline asks for the
	 same value."

	^ VkPipelineCreation noBasePipelineIndex
]

{ #category : 'instance creation' }
VkComputePipeline class >> on: aShaderModule layout: aPipelineLayout device: aDevice [
	| p |
	p := self new.
	p shaderModule: aShaderModule.
	p layout: aPipelineLayout.
	p device: aDevice.
	p entryPoint: VkShaderModule defaultEntryPoint.
	p create.
	^ p
]

{ #category : 'constants' }
VkComputePipeline class >> pipelinesPerCreate [
	"Delegates so the value has one home: one request per call is how every pipeline is created
	 here, whatever kind it is, and the graphics pipeline asks for the same value."

	^ VkPipelineCreation pipelinesPerCreate
]

{ #category : 'lifecycle' }
VkComputePipeline >> create [
	"Build the request, create the pipeline from it, give the request back. The request owns the
	 entry point string it points at, so it is freed through the class whatever the creation
	 does."

	| request |
	request := self class
		           createInfoForModule: shaderModule handle
		           entryPoint: entryPoint
		           layout: layout handle.
	handle := [ self class handleForCreateInfo: request on: device ]
		          ensure: [ self class freeCreateInfo: request ]
]

{ #category : 'lifecycle' }
VkComputePipeline >> destroy [

	handle isNil ifTrue: [ ^ self ].
	Vk
		destroyPipeline: device handle
		pipeline: handle
		allocator: ExternalAddress null.
	handle invalidate.
	handle := nil
]

{ #category : 'accessing' }
VkComputePipeline >> device: aDevice [
	device := aDevice
]

{ #category : 'accessing' }
VkComputePipeline >> entryPoint: aString [
	entryPoint := aString
]

{ #category : 'accessing' }
VkComputePipeline >> handle [
	^ handle
]

{ #category : 'accessing' }
VkComputePipeline >> layout: aLayout [
	layout := aLayout
]

{ #category : 'accessing' }
VkComputePipeline >> shaderModule: aSM [
	shaderModule := aSM
]
