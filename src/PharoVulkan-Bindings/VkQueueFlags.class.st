"
Bitmask constants for queue family capability flags (VkQueueFlagBits).
All methods are class-side and return the bit value.
Key methods: graphicsBit, computeBit, transferBit (class-side).
"
Class {
	#name : 'VkQueueFlags',
	#superclass : 'Object',
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'flags' }
VkQueueFlags class >> computeBit [   ^ 2
]

{ #category : 'flags' }
VkQueueFlags class >> graphicsBit [  ^ 1
]

{ #category : 'flags' }
VkQueueFlags class >> sparseBindingBit [ ^ 8
]

{ #category : 'flags' }
VkQueueFlags class >> transferBit [  ^ 4
]
