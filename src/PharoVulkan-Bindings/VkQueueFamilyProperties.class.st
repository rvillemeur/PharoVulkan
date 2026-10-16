"
Properties of one queue family on a physical device.
queueFlags is a bitmask — use VkQueueFlags computeBit to test for compute support.
Key methods: queueFlags, queueCount, supportsCompute.
"
Class {
	#name : 'VkQueueFamilyProperties',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_MINIMAGETRANSFERGRANULARITYDEPTH',
		'OFFSET_MINIMAGETRANSFERGRANULARITYHEIGHT',
		'OFFSET_MINIMAGETRANSFERGRANULARITYWIDTH',
		'OFFSET_QUEUECOUNT',
		'OFFSET_QUEUEFLAGS',
		'OFFSET_TIMESTAMPVALIDBITS'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'fields' }
VkQueueFamilyProperties class >> fieldsDesc [
    ^ #(
        uint32 queueFlags;
        uint32 queueCount;
        uint32 timestampValidBits;
        uint32 minImageTransferGranularityWidth;
        uint32 minImageTransferGranularityHeight;
        uint32 minImageTransferGranularityDepth
    )
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> minImageTransferGranularityDepth [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MINIMAGETRANSFERGRANULARITYDEPTH
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> minImageTransferGranularityDepth: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MINIMAGETRANSFERGRANULARITYDEPTH put: anObject
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> minImageTransferGranularityHeight [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MINIMAGETRANSFERGRANULARITYHEIGHT
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> minImageTransferGranularityHeight: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MINIMAGETRANSFERGRANULARITYHEIGHT put: anObject
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> minImageTransferGranularityWidth [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MINIMAGETRANSFERGRANULARITYWIDTH
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> minImageTransferGranularityWidth: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MINIMAGETRANSFERGRANULARITYWIDTH put: anObject
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> queueCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUECOUNT
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> queueCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUECOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> queueFlags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUEFLAGS
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> queueFlags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUEFLAGS put: anObject
]

{ #category : 'testing' }
VkQueueFamilyProperties >> supportsCompute [
    "True when this queue family supports compute operations."
    ^ (self queueFlags bitAnd: VkQueueFlags computeBit) ~= 0
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> timestampValidBits [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TIMESTAMPVALIDBITS
]

{ #category : 'accessing - structure variables' }
VkQueueFamilyProperties >> timestampValidBits: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TIMESTAMPVALIDBITS put: anObject
]
