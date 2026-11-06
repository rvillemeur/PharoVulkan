"
End-to-end compute kernel runner. Compiles a Pharo method annotated with <gpu> to SPIR-V, creates a VkComputePipeline, dispatches on the GPU, and reads back results.
"
Class {
	#name : 'PVComputeKernel',
	#superclass : 'Object',
	#instVars : [
		'context',
		'spirvBytes',
		'buffers',
		'commandPool',
		'descriptorPool',
		'shaderModule',
		'pipeline',
		'pipelineLayout',
		'descriptorSetLayout',
		'descriptorSet'
	],
	#category : 'PharoVulkan-Compute-Kernels',
	#package : 'PharoVulkan-Compute',
	#tag : 'Kernels'
}

{ #category : 'labels' }
PVComputeKernel class >> bindingRowPrefix [
	^ 'binding '
]

{ #category : 'constants' }
PVComputeKernel class >> descriptorSetCount [
	"prepare allocates one descriptor set and puts every binding in it, so the pool needs
	 room for exactly one set however many buffers are bound."
	^ 1
]

{ #category : 'constants' }
PVComputeKernel class >> exampleBufferCount [
	"One buffer per storage-buffer parameter of exampleKernelMethod: a, b and the output."
	^ 3
]

{ #category : 'constants' }
PVComputeKernel class >> exampleElementCount [
	"The example dispatches one workgroup, so it sizes the buffers to one workgroup's worth
	 of elements: the local size the module declares."
	^ 64
]

{ #category : 'constants' }
PVComputeKernel class >> exampleKernelMethod [
	^ PVKernelExamples >> #vectorAdd:a:b:out:
]

{ #category : 'factory' }
PVComputeKernel class >> fromMethod: aCompiledMethod on: aContext [
	| spirv |
	spirv := PVKernelCompiler compileMethod: aCompiledMethod.
	^ self on: aContext spirv: spirv
]

{ #category : 'labels' }
PVComputeKernel class >> invocationsRowName [
	^ 'Invocations per group'
]

{ #category : 'labels' }
PVComputeKernel class >> localSizeRowName [
	^ 'Local size'
]

{ #category : 'labels' }
PVComputeKernel class >> moduleBindingRowName [
	^ 'Buffer bindings in the module'
]

{ #category : 'labels' }
PVComputeKernel class >> moduleRowNames [
	"The rows read out of the SPIR-V module, so a kernel with no module names the same rows
	 as one with a module instead of dropping them."
	^ {
		  self moduleBindingRowName.
		  self localSizeRowName.
		  self invocationsRowName }
]

{ #category : 'labels' }
PVComputeKernel class >> noBuffersErrorMessage [
	^ 'A compute kernel with no storage buffer has nothing to bind: send bindBuffer: before prepare'
]

{ #category : 'labels' }
PVComputeKernel class >> noModuleLabel [
	^ 'no module'
]

{ #category : 'instance creation' }
PVComputeKernel class >> on: aContext spirv: bytes [

	| k |
	k := self new.
	k context: aContext.
	k spirvBytes: bytes.
	k buffers: OrderedCollection new.
	^ k
]

{ #category : 'labels' }
PVComputeKernel class >> pipelineAbsentLabel [
	"One label for both kernels without a pipeline, because the instance cannot tell a kernel
	 that was never prepared from one whose pipeline destroy has already released."
	^ 'not built: prepare has not run, or destroy has released it'
]

{ #category : 'labels' }
PVComputeKernel class >> pipelineBuiltLabel [
	^ 'built'
]

{ #category : 'labels' }
PVComputeKernel class >> pipelineRowName [
	^ 'Pipeline'
]

{ #category : 'accessing' }
PVComputeKernel >> bindBuffer: aBuffer [
	buffers add: aBuffer
]

{ #category : 'reporting' }
PVComputeKernel >> bindingRows [
	"The binding index is the position in the bind order, which is what prepare writes into
	 the descriptor set, so the row cannot name a binding the set does not use."
	^ (1 to: (buffers ifNil: [ #(  ) ]) size) collect: [ :index |
		  self
			  rowNamed: self class bindingRowPrefix , (index - 1) printString
			  value: (buffers at: index) size printString , ' bytes' ]
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

	commandPool ifNotNil: [
			commandPool destroy.
			commandPool := nil ].
	descriptorPool ifNotNil: [
			descriptorPool destroy.
			descriptorPool := nil ].
	descriptorSet ifNotNil: [
			descriptorSet handle invalidate.
			descriptorSet := nil ].
	pipeline ifNotNil: [
			pipeline destroy.
			pipeline := nil ].
	pipelineLayout ifNotNil: [
			pipelineLayout destroy.
			pipelineLayout := nil ].
	descriptorSetLayout ifNotNil: [
			descriptorSetLayout destroy.
			descriptorSetLayout := nil ].
	shaderModule ifNil: [ ^ self ].
	shaderModule destroy.
	shaderModule := nil
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

{ #category : 'inspector' }
PVComputeKernel >> inspectorPipeline: aBuilder [
	"What this kernel will dispatch. The rows are built from the kernel's own state and from
	 the emitted module, so the tab cannot claim a binding or a workgroup shape the dispatch
	 would not use."
	<inspectorPresentationOrder: 10 title: 'Pipeline'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Quantity' evaluated: [ :each |
					   each at: #name ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each at: #value ]);
		  items: self pipelineReport;
		  yourself
]

{ #category : 'reporting' }
PVComputeKernel >> moduleRows [
	"Read back out of the emitted SPIR-V rather than from the pragma that asked for it: a
	 local size the compiler did not emit shows here as the shape the dispatch really runs."
	| module localSize |
	spirvBytes ifNil: [
		^ self class moduleRowNames collect: [ :each |
			  self rowNamed: each value: self class noModuleLabel ] ].
	module := PVSpirvValidator on: spirvBytes.
	localSize := module localSizeFromWords.
	^ {
		  (self
			   rowNamed: self class moduleBindingRowName
			   value:
			   (module variableCountInStorageClass: SpvStorageClass storageBuffer)
				   printString).
		  (self rowNamed: self class localSizeRowName value: localSize printString).
		  (self
			   rowNamed: self class invocationsRowName
			   value: (localSize inject: 1 into: [ :all :each | all * each ]) printString) }
]

{ #category : 'reporting' }
PVComputeKernel >> pipelineReport [
	"One row per fact about this dispatch, each asked of the kernel's own state or of the
	 module it will run rather than restated. A buffer bound that the shader does not declare
	 shows up as two different counts."
	^ { self pipelineRow } , self bindingRows , self moduleRows
]

{ #category : 'reporting' }
PVComputeKernel >> pipelineRow [
	^ self
		  rowNamed: self class pipelineRowName
		  value: (pipeline
				   ifNil: [ self class pipelineAbsentLabel ]
				   ifNotNil: [ self class pipelineBuiltLabel ])
]

{ #category : 'pipeline' }
PVComputeKernel >> prepare [
	"Build shader module, DSL, pipeline layout, pipeline, descriptor pool/set, command pool"
	buffers ifEmpty: [ VkError signal: self class noBuffersErrorMessage ].
	shaderModule := VkShaderModule fromBytes: spirvBytes device: context device.
	descriptorSetLayout := VkDescriptorSetLayout on: context device.
	0 to: buffers size - 1 do: [ :i |
		descriptorSetLayout
			addStorageBufferBinding: i
			stageFlags: VkShaderStage computeBit ].
	descriptorSetLayout create.
	pipelineLayout := VkPipelineLayout
		                  on: context device
		                  setLayouts: (Array with: descriptorSetLayout).
	pipeline := VkComputePipeline
		            on: shaderModule
		            layout: pipelineLayout
		            device: context device.
	"One set holds every binding, so the pool holds one set and as many descriptors as there
	 are buffers"
	descriptorPool := VkDescriptorPool
		                  on: context device
		                  maxSets: self class descriptorSetCount
		                  descriptorCount: buffers size.
	descriptorSet := descriptorPool allocateSet: descriptorSetLayout.
	buffers doWithIndex: [ :buf :i |
		descriptorSet updateStorageBuffer: buf atBinding: i - 1 ].
	commandPool := VkCommandPool
		               on: context device
		               queueFamilyIndex: context computeQueueFamily
]

{ #category : 'reporting' }
PVComputeKernel >> rowNamed: aString value: aValueString [
	^ Dictionary newFrom: {
			  (#name -> aString).
			  (#value -> aValueString) }
]

{ #category : 'accessing' }
PVComputeKernel >> spirvBytes: bytes [
	spirvBytes := bytes
]
