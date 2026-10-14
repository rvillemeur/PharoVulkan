"
Vulkan descriptor set layout. Declares the storage-buffer binding schema used by compute shaders. Key method: initializeDevice:bindingCount:.
"
Class {
	#name : 'VkDescriptorSetLayout',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'bindings'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'examples' }
VkDescriptorSetLayout class >> exampleLayoutForATwoBufferKernelOnThisMachine [
	"One click: the layout a kernel reading one buffer and writing another is created from,
	 built on this machine's device and then destroyed with its context. The bindings live in
	 the instance, so the Bindings tab still answers after the handle and the device have
	 gone."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ self new ].
	^ [
	  | kernelLayout |
	  kernelLayout := self on: context device.
	  0 to: 1 do: [ :binding |
		  kernelLayout
			  addStorageBufferBinding: binding
			  stageFlags: VkShaderStage computeBit ].
	  kernelLayout create.
	  kernelLayout destroy.
	  kernelLayout ] ensure: [ context destroy ]
]

{ #category : 'factory' }
VkDescriptorSetLayout class >> on: aDevice [
    ^ self new initializeOn: aDevice
]

{ #category : 'configuring' }
VkDescriptorSetLayout >> addStorageBufferBinding: aBindingIndex stageFlags: stageFlags [
	bindings add:
		(VkDescriptorSetLayoutBinding
			 storageBufferAt: aBindingIndex
			 stages: stageFlags)
]

{ #category : 'accessing' }
VkDescriptorSetLayout >> bindingRows [
	"The bindings the driver was given, read back out of the declared structures themselves
	 rather than restated from the arguments the caller passed. Each call builds fresh rows
	 over copies of the values, so whatever a view does with a row cannot reach the layout."

	^ bindings collect: [ :each |
		  (Dictionary newFrom: {
				   (#binding -> each binding).
				   (#type -> each descriptorType).
				   (#typeName
				    -> (VkDescriptorType nameForValue: each descriptorType)).
				   (#count -> each descriptorCount).
				   (#stages -> each stageFlags).
				   (#stageNames -> (VkShaderStage nameForFlags: each stageFlags)) })
			  beReadOnlyObject ]
]

{ #category : 'lifecycle' }
VkDescriptorSetLayout >> create [
	"The bindings collected so far are copied into one external run and the layout is created
	 from a request that points at it. The run is freed once the driver has read it: a
	 descriptor set layout keeps no reference to the array it was described by."

	| elements |
	elements := VkDescriptorSetLayoutBinding externalArrayOf: bindings size.
	handle := [ self handleForBindingArray: elements ] ensure: [
		          elements ifNotEmpty: [ :all | all first getHandle free ] ]
]

{ #category : 'lifecycle' }
VkDescriptorSetLayout >> destroy [

	handle ifNotNil: [
			Vk
				destroyDescriptorSetLayout: device handle
				descriptorSetLayout: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkDescriptorSetLayout >> handle [
    ^ handle
]

{ #category : 'private' }
VkDescriptorSetLayout >> handleForBindingArray: someElements [
	"Each collected binding is copied into its element of the external run, and the request
	 names the run by its first element's address. An empty layout names no array at all: a
	 pointer into a block of no bytes is not something to hand a driver."

	| info |
	bindings doWithIndex: [ :each :index |
		each copyBytesInto: (someElements at: index) ].
	info := VkDescriptorSetLayoutCreateInfo externalInstance.
	^ [
	  info
		  bindingCount: bindings size;
		  pBindings: (someElements
				   ifEmpty: [ ExternalAddress null ]
				   ifNotEmpty: [ :all | all first getHandle ]).
	  self handleForCreateInfo: info ] ensure: [ info getHandle free ]
]

{ #category : 'private' }
VkDescriptorSetLayout >> handleForCreateInfo: aCreateInfo [
	"The driver writes the new layout handle into an out parameter, which is read before the
	 block holding it is freed."

	| out result |
	out := ExternalAddress allocate: VkContext pointerSize.
	^ [
	  result := Vk
		            createDescriptorSetLayout: device handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            setLayoutOut: out.
	  Vk checkResult: result.
	  VkDescriptorSetLayout_H fromHandle: (out pointerAt: 1) ] ensure: [
		  out free ]
]

{ #category : 'initialization' }
VkDescriptorSetLayout >> initializeOn: aDevice [
    device := aDevice. bindings := OrderedCollection new
]

{ #category : 'inspector' }
VkDescriptorSetLayout >> inspectorBindings: aBuilder [
	"What this layout declares, read out of the binding structures themselves: the binding
	 number a shader names, the descriptor type and the stages, each decoded by the constants
	 class that owns the value rather than by a table kept here. The rows are read only, so
	 opening the tab cannot change the layout."

	<inspectorPresentationOrder: 30 title: 'Bindings'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Binding' evaluated: [ :each |
				   (each at: #binding) printString ]);
		  addColumn: (SpStringTableColumn title: 'Type' evaluated: [ :each |
				   each at: #typeName ]);
		  addColumn: (SpStringTableColumn title: 'Count' evaluated: [ :each |
				   (each at: #count) printString ]);
		  addColumn: (SpStringTableColumn title: 'Stages' evaluated: [ :each |
				   each at: #stageNames ]);
		  items: self bindingRows;
		  yourself
]
