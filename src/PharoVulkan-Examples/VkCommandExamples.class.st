"
Examples of what this project records and submits: the allocation of a command buffer, the begin info of a one-time recording, the barrier and dependency that make a device write readable by the host, the copy region of an image readback, the batch that submits one buffer, the semaphore wait of a frame and the request for a signalled fence.

Read in that order they are one submission from end to end. Each is built in object memory, and every pointer that would lead to a store the example does not own is left null; the live path is covered by the command buffer tests.
"
Class {
	#name : 'VkCommandExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkCommandExamples class >> barrierRecordedBeforeAHostRead [
	"One click: the barrier every compute run in this project records before reading its result
	 back, built by the recorder itself so the masks shown are the masks used."

	<sampleInstance>
	| barrier |
	barrier := VkCommandBuffer hostReadBarrier.
	^ [ barrier copyIntoObjectMemory ] ensure: [ barrier getHandle free ]
]

{ #category : 'examples' }
VkCommandExamples class >> computeBatchOfOneCommandBuffer [
	"One click: the batch the compute path submits, built by the recorder's own builder. No
	 device is touched, so the command buffer info the batch points at is a null handle and
	 neither semaphore side is asked for. The Batch tab never follows a pointer, so the object
	 memory copy is enough to read every row."

	<sampleInstance>
	| batch |
	batch := VkQueue
		         submitInfoFor: ExternalAddress null
		         waitSemaphoreInfo: nil
		         signalSemaphoreInfo: nil.
	^ [ batch copyIntoObjectMemory ] ensure: [ batch getHandle free ]
]

{ #category : 'examples' }
VkCommandExamples class >> dependencyCarryingOneMemoryBarrier [
	"One click: the dependency the recorder hands to vkCmdPipelineBarrier2, carrying one memory
	 barrier and no buffer or image barrier. The barrier it points at is freed with the example,
	 so the pointer is shown for its placement, not to be followed."

	<sampleInstance>
	| barrier |
	barrier := VkCommandBuffer hostReadBarrier.
	^ [
	  | info |
	  info := VkCommandBuffer dependencyForBarrier: barrier.
	  [ info copyIntoObjectMemory ] ensure: [ info getHandle free ] ] ensure: [
		  barrier getHandle free ]
]

{ #category : 'examples' }
VkCommandExamples class >> regionForAWholeImageReadback [
	"One click: the region every image readback in this project records, built by the recorder
	 itself for an example extent, so the Copy tab shows the packing and the aspect the
	 recording really uses."

	<sampleInstance>
	| region |
	region := VkCommandBuffer regionForExtent: VkBufferImageCopy exampleExtent.
	^ [ region copyIntoObjectMemory ] ensure: [ region getHandle free ]
]

{ #category : 'examples' }
VkCommandExamples class >> requestForAOneTimeRecording [
	"One click: the request every recording in this project opens with, the one field a caller
	 writes set to the flag the class names. The inheritance pointer stays null, which is what
	 a primary buffer must present."

	<sampleInstance>
	| info |
	info := VkCommandBufferBeginInfo externalInstance.
	^ [
	  info flags: VkCommandBuffer recordingFlags.
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'examples' }
VkCommandExamples class >> requestForASignalledFence [
	"One click: the request a frame loop's first fence is created from, the one field a caller
	 writes set to the signalled bit. The Layout and Fields tabs show what the driver reads."

	<sampleInstance>
	| info |
	info := VkFenceCreateInfo externalInstance.
	^ [
	  info flags: VkFenceCreateFlag signaledBit.
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'examples' }
VkCommandExamples class >> requestForOnePrimaryBuffer [
	"One click: the request every command buffer in this project is allocated from, with the
	 pool pointer cleared because no pool is made here. The Layout and Fields tabs show what
	 the driver reads; the structure type is the only field a fresh block carries."

	<sampleInstance>
	| info |
	info := VkCommandBufferAllocateInfo externalInstance.
	^ [
	  info
		  level: VkCommandPool allocationLevel;
		  commandBufferCount: VkCommandPool buffersPerAllocation.
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'examples' }
VkCommandExamples class >> waitOnAFrameSemaphore [
	"One click: the semaphore info a frame's batch carries on either side, built by the
	 recorder's own builder. No device is touched, so the semaphore handle is null and the tab
	 says so; the stage mask is the one the window path really waits at."

	<sampleInstance>
	| info |
	info := VkQueue semaphoreSubmitInfoFor: ExternalAddress null.
	^ [ info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]
