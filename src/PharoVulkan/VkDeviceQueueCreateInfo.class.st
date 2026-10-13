"
A VkDeviceQueueCreateInfo, declared field by field: forty bytes over offsets 0, 8, 16, 20, 24 and 32, with four bytes of padding before pQueuePriorities so that pointer sits on an eight byte boundary. One of these is handed to vkCreateDevice for each queue family the device is asked for; this project asks for one family and VkContext class >> queuesPerFamily queues on it.

The structure type and a cleared pNext are set by initializeConstantFields; the family index, the queue count and the priority array are the caller's, because a zeroed store asks for zero queues on family zero, which is not a legal request. pQueuePriorities points at one float per queue, an array and not a structure, so it carries no field specification of its own and is read through its store by VkContext class >> queuePriorityByteCount.

Key methods: fieldsDesc (class side), initializeConstantFields, VkContext >> buildDeviceQueueCreateInfo: and its pair VkContext >> freeDeviceQueueCreateInfo:, which releases the priority array as well as the store. The Layout and Fields tabs come from VkStructure.
"
Class {
	#name : 'VkDeviceQueueCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_PQUEUEPRIORITIES',
		'OFFSET_QUEUECOUNT',
		'OFFSET_QUEUEFAMILYINDEX',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDeviceQueueCreateInfo class >> exampleOneQueueOnTheFirstFamily [
	"One click: the request the context makes of every device it creates, with the structure
	 type, the family and the queue count side by side in the Fields tab. The count comes from
	 VkContext rather than from a literal here, so the example follows the code that builds the
	 real one. pQueuePriorities stays null, because an example must not hold a pointer to a
	 store it does not own; the live array is covered by
	 VkCoreTest >> testDeviceQueueCreateInfoAsksForOneQueueAtFullPriority."

	<sampleInstance>
	^ self new
		  queueFamilyIndex: self firstQueueFamily;
		  queueCount: VkContext queuesPerFamily;
		  yourself
]

{ #category : 'field definition' }
VkDeviceQueueCreateInfo class >> fieldsDesc [
	"VkDeviceQueueCreateInfo as the C header declares it. VkDeviceQueueCreateFlags is a
	 VkFlags, which is uint32, and pQueuePriorities points at one float per queue."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 queueFamilyIndex;
		uint32 queueCount;
		void* pQueuePriorities
	)
]

{ #category : 'constants' }
VkDeviceQueueCreateInfo class >> firstQueueFamily [
	"Queue families are numbered from zero. The real index is whichever family the context
	 selected; this is only what an example shows when no device has been looked at."

	^ 0
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkDeviceQueueCreateInfo >> initializeConstantFields [
	"Both fields are constant for the type: every instance of this structure is a device queue
	 create info, and nothing in this project chains anything off a queue create info."

	self sType: VkStructureType deviceQueueCreateInfo.
	self pNext: ExternalAddress null
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> pQueuePriorities [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PQUEUEPRIORITIES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> pQueuePriorities: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PQUEUEPRIORITIES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> queueCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUECOUNT
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> queueCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUECOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> queueFamilyIndex [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEX
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> queueFamilyIndex: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUEUEFAMILYINDEX put: anObject
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkDeviceQueueCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
