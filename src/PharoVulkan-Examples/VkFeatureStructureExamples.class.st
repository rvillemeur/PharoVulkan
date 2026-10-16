"
Examples of the structures a driver fills in when asked what the machine can do: the feature structures of each extension this project cares about, the properties and limits of the physical device, and the chained query that reads several of them in one call.

Each example queries whichever device is here, so what it answers is this machine's answer and not a recorded one. Where no Vulkan device is available the example answers an empty structure rather than failing, because an inspector opened on a machine with no driver should still show the fields the structure declares. VkBaseOutStructure and VkFeatureStructure are the two abstract headers, and their examples show what every chained structure carries.
"
Class {
	#name : 'VkFeatureStructureExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkFeatureStructureExamples class >> chainedQueryOfThisMachine [
	"One click: the query head as the driver left it, copied out of the chain before that memory
	 was freed. Its pNext reads as null in the copy, because the block it pointed at is gone."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  VkPhysicalDeviceProperties2
		  of: context physicalDevice handle
		  chainedWith: VkPhysicalDeviceSubgroupProperties
		  do: [ :head :block | head copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> cooperativeMatrixOfThisMachine [
	"One click: whether the device a plain compute context lands on offers the subgroup-wide
	 matrix multiply, copied out of the chain before that memory was freed. A device without
	 the extension answers the query all the same and clears both flags, which is how
	 VkContext decides to leave this structure out of the feature chain."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  VkPhysicalDeviceFeatures2
		  of: context physicalDevice handle
		  chainedWith: VkPhysicalDeviceCooperativeMatrixFeaturesKHR
		  do: [ :head :features | features copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> flagsEveryFeatureStructureDeclares [
	"One click: every feature structure this project declares, with the flags its layout
	 exposes, read out of a freshly zeroed block. No device is asked here, so every flag reads
	 as clear; the shape of the view is the point, not the answer. The rows are copies in
	 object memory, so they outlive the block each one was read from."

	<sampleInstance>
	^ VkFeatureStructure subclasses collect: [ :each |
		  | instance |
		  instance := each externalInstance.
		  [ each name -> instance flagRows ] ensure: [ instance getHandle free ] ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> headerOfAFeatureStructure [
	"One click: the chain header a walker sees when it reaches a synchronization2 feature
	 structure. The header is a view over memory that belongs to that structure, so it is
	 copied into object memory before the block is freed."

	<sampleInstance>
	| features |
	features := VkPhysicalDeviceSynchronization2Features externalInstance.
	^ [ (VkBaseOutStructure fromHandle: features getHandle) copyIntoObjectMemory ] ensure: [
		  features getHandle free ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> limitsOfThisMachine [
	"One click: every limit this machine's driver reports. The block is a member of a properties
	 structure whose store is a ByteArray inside the image, so the limits still read after the
	 context that queried them has gone."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ context physicalDevice limits ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> propertiesOfThisMachine [
	"One click: the properties the local driver writes, with the Layout view beside them. The
	 store is a ByteArray inside the image, so the bytes still read after the context that
	 queried them has gone."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ Vk getPhysicalDeviceProperties: context physicalDevice handle ]
		  ensure: [ context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> shaderArithmeticWidthsOfThisMachine [
	"One click: whether the device a plain compute context lands on can compute with half
	 floats and with eight bit integers, copied out of the chain before that memory was
	 freed. shaderFloat16 is the flag the f16 compute path needs; holding halves in a buffer
	 is a separate feature, over in VkPhysicalDevice16BitStorageFeatures."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  VkPhysicalDeviceFeatures2
		  of: context physicalDevice handle
		  chainedWith: VkPhysicalDeviceShaderFloat16Int8Features
		  do: [ :head :features | features copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> sixteenBitStorageOfThisMachine [
	"One click: the places the device a plain compute context lands on lets a half float
	 live, copied out of the chain before that memory was freed. storageBuffer16BitAccess is
	 the one the f16 compute path needs; a device may well report that one and refuse half
	 floats in uniforms, push constants and interface variables."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  VkPhysicalDeviceFeatures2
		  of: context physicalDevice handle
		  chainedWith: VkPhysicalDevice16BitStorageFeatures
		  do: [ :head :features | features copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> subgroupPropertiesOfThisMachine [
	"One click: the subgroup width and operations this machine's driver reports, with the
	 Features view beside them. The block is copied into object memory by the query, so it still
	 reads after the context has gone."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ context physicalDevice subgroupProperties ]
		  ensure: [ context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> synchronization2OfThisMachine [
	"One click: whether the device a plain compute context lands on reports
	 synchronization2, copied out of the chain before that memory was freed. Every submission
	 in this project goes through vkQueueSubmit2, so a device that clears the flag runs
	 nothing here."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  VkPhysicalDeviceFeatures2
		  of: context physicalDevice handle
		  chainedWith: VkPhysicalDeviceSynchronization2Features
		  do: [ :head :features | features copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]

{ #category : 'examples' }
VkFeatureStructureExamples class >> vulkanMemoryModelOfThisMachine [
	"One click: the memory model flags of the device a plain compute context lands on, copied
	 out of the chain before that memory was freed. A device that reports the model usually
	 reports the device scope and the availability-visibility chains with it."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  VkPhysicalDeviceFeatures2
		  of: context physicalDevice handle
		  chainedWith: VkPhysicalDeviceVulkanMemoryModelFeatures
		  do: [ :head :features | features copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]
