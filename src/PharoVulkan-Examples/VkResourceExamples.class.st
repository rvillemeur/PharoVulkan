"
Examples of the resources a kernel is dispatched through, each created on the device of this machine: a storage buffer of four floats, a command pool on the compute queue and a buffer allocated from it, a descriptor pool and the set layout of a two-buffer kernel, and a colour attachment image.

These own driver objects. Each example creates what it answers and destroys everything it created but the object it hands back, so the inspector has something live to open and the rest is given back before the click ends.
"
Class {
	#name : 'VkResourceExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Compute',
	#package : 'PharoVulkan-Examples',
	#tag : 'Compute'
}

{ #category : 'examples' }
VkResourceExamples class >> bufferFromTheComputePoolOnThisMachine [
	"One click: the primary command buffer a compute dispatch here records into, cut from a
	 pool on this machine's compute queue family. The pool is destroyed with its context, which
	 frees the buffer with it, so the Buffer tab shows the level and the family it was
	 allocated with over a handle it reports as dead. Where no device is available it answers
	 an unallocated buffer, which is what the inspector should show on such a machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ VkCommandBuffer new ].
	^ [
	  | pool |
	  pool := context device createCommandPool: context computeQueueFamily.
	  [ pool allocateBuffer ] ensure: [ pool destroy ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkResourceExamples class >> colorAttachmentOnThisMachine [
	"One click: the colour attachment an offscreen render would draw into on whatever device
	 this image finds, with its view created, then destroyed before it is handed back. Format,
	 extent, usage and the memory size the driver asked for live in the instance, so the
	 object still answers them after its handles and its context have gone."

	<sampleInstance>
	| context image |
	context := VkContext offscreenGraphicsContext.
	^ [
	  image := VkImage
		           on: context device
		           format: VkFormat b8g8r8a8Unorm
		           extent: VkImage exampleExtent
		           usage:
		           (VkImageUsage colorAttachmentBit bitOr: VkImageUsage transferSrcBit).
	  image createView.
	  image destroy.
	  image ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkResourceExamples class >> layoutForATwoBufferKernelOnThisMachine [
	"One click: the layout a kernel reading one buffer and writing another is created from,
	 built on this machine's device and then destroyed with its context. The bindings live in
	 the instance, so the Bindings tab still answers after the handle and the device have
	 gone."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ VkDescriptorSetLayout new ].
	^ [
	  | kernelLayout |
	  kernelLayout := VkDescriptorSetLayout on: context device.
	  0 to: 1 do: [ :binding |
		  kernelLayout
			  addStorageBufferBinding: binding
			  stageFlags: VkShaderStage computeBit ].
	  kernelLayout create.
	  kernelLayout destroy.
	  kernelLayout ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkResourceExamples class >> poolForTheComputeQueueOnThisMachine [
	"One click: the pool every compute dispatch here allocates its command buffer from, created
	 for this machine's compute queue family and then destroyed with its context. The family
	 and the flags live in the instance, so the Pool tab still answers afterwards. Where no
	 device is available it answers an unmade pool, which is what the inspector should show on
	 such a machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ VkCommandPool new ].
	^ [
	  | pool |
	  pool := context device createCommandPool: context computeQueueFamily.
	  pool destroy.
	  pool ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkResourceExamples class >> storageBufferOfFourFloats [
	"One click: a buffer whose capacity rule can be read in the inspector. The size lives in
	 the instance, so the object still answers after its handle and its context have gone."

	<sampleInstance>
	| context buffer |
	context := VkContext computeContext.
	^ [
	  buffer := VkBuffer
		            on: context device
		            size: VkBuffer exampleByteSize
		            usage: VkBuffer storageBufferUsage.
	  buffer destroy.
	  buffer ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkResourceExamples class >> storageBufferPoolForThreeBuffers [
	"One click: the pool a three-buffer compute kernel allocates, with one set allocated out
	 of it, then released with its context. The two counts and the allocation count live in
	 the instance, so the pool still answers after its handle and its device have gone, which
	 is what the Pool tab shows."
	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ VkDescriptorPool new ].
	^ [
	  | pool setLayout set |
	  setLayout := VkDescriptorSetLayout on: context device.
	  0 to: VkDescriptorPool exampleDescriptorCount - 1 do: [ :binding |
		  setLayout
			  addStorageBufferBinding: binding
			  stageFlags: VkShaderStage computeBit ].
	  setLayout create.
	  pool := VkDescriptorPool
		          on: context device
		          maxSets: VkDescriptorPool exampleMaxSets
		          descriptorCount: VkDescriptorPool exampleDescriptorCount.
	  set := pool allocateSet: setLayout.
	  set handle invalidate.
	  pool destroy.
	  setLayout destroy.
	  pool ] ensure: [ context destroy ]
]
