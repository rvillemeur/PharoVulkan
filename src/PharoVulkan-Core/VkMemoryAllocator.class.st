"
Helper that selects the right device memory type index for given Vulkan memory requirements and property flags. Used internally by VkBuffer>>allocate.
"
Class {
	#name : 'VkMemoryAllocator',
	#superclass : 'Object',
	#instVars : [
		'device',
		'physicalDevice'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan-Core'
}
