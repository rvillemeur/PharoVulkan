"
Examples of what this project asks of device memory: the buffer request, the requirements a driver answers for a buffer and for a colour attachment, the allocation that satisfies them, and the descriptor info that names a whole buffer.

The two requirements examples ask a real device, because what a driver demands for a given usage is the point of reading them; the request and the descriptor info are built in object memory and name no store they do not own.
"
Class {
	#name : 'VkMemoryExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkMemoryExamples class >> allocationForAStorageBufferOnThisMachine [
	"One click: the allocation request a small storage buffer leads to on this machine. Both
	 numbers are answers, not choices: the size is what the driver demanded for the buffer, and
	 the memory type index is the first type on this device that both suits the buffer and is
	 host visible and coherent."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  | buffer requirements info |
	  buffer := VkBuffer
		            on: context device
		            size: VkBuffer exampleByteSize
		            usage: VkBuffer storageBufferUsage.
	  requirements := [ buffer memoryRequirements ] ensure: [ buffer destroy ].
	  info := VkMemoryAllocateInfo externalInstance.
	  [
	  info
		  allocationSize: requirements size;
		  memoryTypeIndex: (context device physicalDevice
				   findMemoryType: requirements memoryTypeBits
				   properties: VkMemoryProperty hostVisibleAndCoherent).
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkMemoryExamples class >> requirementsOfAColorAttachmentOnThisMachine [
	"One click: what this machine's driver demands to back a 64 by 64 colour attachment, next
	 to the arithmetic size of its pixels. The driver's number is the larger of the two here,
	 which is why VkImage binds what it is told and never width * height * 4."

	<sampleInstance>
	| context |
	context := VkContext offscreenGraphicsContext.
	^ [
	  | image requirements |
	  image := VkImage
		           on: context device
		           format: VkFormat b8g8r8a8Unorm
		           extent: 64 @ 64
		           usage: VkImageUsage colorAttachmentBit.
	  requirements := [ image memoryRequirements ] ensure: [ image destroy ].
	  {
		  (#requirements -> requirements).
		  (#arithmeticSize -> (64 * 64 * 4)) } ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkMemoryExamples class >> requirementsOfAStorageBufferOnThisMachine [
	"One click: what this machine's driver demands to back a small storage buffer. The numbers
	 are the device's, not the project's — the request is for four floats, and the driver is
	 free to ask for more bytes and for an alignment of its choosing."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  | buffer |
	  buffer := VkBuffer
		            on: context device
		            size: VkBuffer exampleByteSize
		            usage: VkBuffer storageBufferUsage.
	  [ buffer memoryRequirements ] ensure: [ buffer destroy ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkMemoryExamples class >> storageBufferRequest [
	"One click: the request VkBuffer builds for a small storage buffer. No device is asked, so
	 nothing is created here; the two fields the project fills, and the degenerate state of the
	 rest, can be read in the Layout and Fields tabs. The answer lives in object memory, so it
	 outlives the external block it was built in."

	<sampleInstance>
	| info |
	info := VkBufferCreateInfo externalInstance.
	^ [
	  info
		  size: VkBuffer exampleByteSize;
		  usage: VkBuffer storageBufferUsage.
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'examples' }
VkMemoryExamples class >> wholeStorageBuffer [
	"One click: the buffer info a compute kernel writes for one of its storage buffers, which
	 is the whole buffer from its start. Built in object memory, so nothing has to be freed,
	 and rebuilt on every call. The buffer handle stays null: an example answers an object that
	 outlives the call, and a handle to a buffer this example does not own would be read after
	 that buffer has gone."
	<sampleInstance>
	^ VkDescriptorBufferInfo new
		  range: VkDescriptorBufferInfo wholeSize;
		  yourself
]
