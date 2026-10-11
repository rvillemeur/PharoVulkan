"
Test stub standing in for a device with an arbitrary queue family layout: withQueueFlags:
takes the flags words a driver would report, so the queue family rules of VkPhysicalDevice
can be tested against layouts this machine does not have — no family at all, graphics and
compute on separate families, a family carrying a flag bit no constant names — without
touching production code or needing a device that reports them.
"
Class {
	#name : 'PVQueueFamilyStub',
	#superclass : 'VkPhysicalDevice',
	#category : 'PharoVulkan-Tests-Core',
	#package : 'PharoVulkan-Tests',
	#tag : 'Core'
}

{ #category : 'factory' }
PVQueueFamilyStub class >> withQueueFlags: anArrayOfFlagWords [
	^ self new setQueueFlags: anArrayOfFlagWords
]

{ #category : 'initialization' }
PVQueueFamilyStub >> setQueueFlags: anArrayOfFlagWords [
	"One flags word per family, in the order the driver would report them. No handle is
	 set, so only the selectors that read the family list may be asked of this object."
	queueFamilyProps := anArrayOfFlagWords
]
