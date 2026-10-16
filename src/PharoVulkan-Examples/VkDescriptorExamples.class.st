"
Examples of the descriptor structures a compute kernel is described by: the layout binding and the layout request that declare its storage buffers, the pool size and pool request that provide for one set of them, the allocation of that set, and the write that points a binding at a buffer.

Together they are the shape the vector-add kernel of this project uses — one set, three storage buffers — so reading them in order shows how a kernel's bindings reach the driver. Each is built in object memory, with every pointer left null, because an example must not hold a pointer to a store it does not own.
"
Class {
	#name : 'VkDescriptorExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDescriptorExamples class >> allocationForOneSetOfThreeBindings [
	"One click: the allocate info VkDescriptorPool writes for a three-buffer compute kernel,
	 with the structure type, the pool slot and the set count side by side in the Fields tab.
	 The pool handle and the layout array stay null: an example answers an object that outlives
	 the call, and a pointer to a store this example does not own would be read after that
	 store has gone. The live pointers are covered by VkBindingsTest and by
	 VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers."
	<sampleInstance>
	^ VkDescriptorSetAllocateInfo new
		  descriptorSetCount: VkDescriptorPool setAllocationCount;
		  yourself
]

{ #category : 'examples' }
VkDescriptorExamples class >> layoutRequestForTwoStorageBuffers [
	"One click: the request VkDescriptorSetLayout builds for a two-buffer compute kernel. No
	 device is asked, so no layout is created; the count and the array pointer the project
	 fills, and the degenerate state of the rest, can be read in the Layout and Fields tabs.
	 The answer lives in object memory, so it outlives the blocks it was built in — which is
	 also why its array pointer is cleared along with the chain pointer: both named memory
	 that has been given back."

	<sampleInstance>
	| info elements kept |
	info := VkDescriptorSetLayoutCreateInfo externalInstance.
	elements := VkDescriptorSetLayoutBinding externalArrayOf: 2.
	^ [
	  info
		  bindingCount: elements size;
		  pBindings: elements first getHandle.
	  kept := info copyIntoObjectMemory.
	  kept pBindings: ExternalAddress null.
	  kept ] ensure: [
		  elements first getHandle free.
		  info getHandle free ]
]

{ #category : 'examples' }
VkDescriptorExamples class >> poolForOneSetOfThreeDescriptors [
	"One click: the create info VkDescriptorPool writes for a three-buffer compute kernel, with
	 the two counts that used to be one number side by side in the Layout tab. pPoolSizes stays
	 null: an example answers an object that outlives the call, and a pointer to a store this
	 example does not own would be read after that store has gone. The live pointer is covered
	 by VkBindingsTest and by VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers."
	<sampleInstance>
	^ VkDescriptorPoolCreateInfo new
		  maxSets: VkDescriptorPool exampleMaxSets;
		  poolSizeCount: VkDescriptorPool poolSizeCount;
		  yourself
]

{ #category : 'examples' }
VkDescriptorExamples class >> storageBufferAtFirstBinding [
	"One click: the write a compute kernel sends for the storage buffer at its first binding,
	 with the structure type, the binding, the count and the descriptor type side by side in
	 the Fields tab. The counts and the type come from VkDescriptorSet and VkDescriptorPool
	 rather than from literals here, so the example follows the code that writes the real one.
	 dstSet and pBufferInfo stay null, because an example must not hold a pointer to a store it
	 does not own; the live pointers are covered by VkBindingsTest and by
	 VkDescriptorPool class >> exampleStorageBufferPoolForThreeBuffers."
	<sampleInstance>
	^ VkWriteDescriptorSet new
		  dstBinding: VkDescriptorSet firstBinding;
		  descriptorCount: VkDescriptorSet descriptorsPerWrite;
		  descriptorType: VkDescriptorPool descriptorType;
		  yourself
]

{ #category : 'examples' }
VkDescriptorExamples class >> storageBufferBindingsOfATwoBufferKernel [
	"One click: the bindings a kernel reading one buffer and writing another declares, built
	 in object memory and then moved into the external run a layout hands the driver. The
	 answer is the run, read back through the declared accessors and kept in object memory, so
	 the block can be freed and the elements still read."

	<sampleInstance>
	| elements kept |
	elements := VkDescriptorSetLayoutBinding externalArrayOf: 2.
	^ [
	  (0 to: 1) do: [ :index |
		  (VkDescriptorSetLayoutBinding storageBufferAt: index stages: VkShaderStage computeBit)
			  copyBytesInto: (elements at: index + 1) ].
	  kept := elements collect: [ :each | each copyIntoObjectMemory ].
	  kept ] ensure: [ elements first getHandle free ]
]

{ #category : 'examples' }
VkDescriptorExamples class >> threeStorageBufferDescriptors [
	"One click: the pool size a three-buffer compute kernel asks for. Built in object memory,
	 so nothing has to be freed, and rebuilt on every call. The counts come from
	 VkDescriptorPool rather than from literals here, so the example follows the pool."
	<sampleInstance>
	^ VkDescriptorPoolSize new
		  type: VkDescriptorPool descriptorType;
		  descriptorCount: VkDescriptorPool exampleDescriptorCount;
		  yourself
]
