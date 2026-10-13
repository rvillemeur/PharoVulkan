"
The VK_KHR_synchronization2 feature flag, chained onto a VkPhysicalDeviceFeatures2 query or onto a VkDeviceCreateInfo feature chain. This project submits every batch of work through `vkQueueSubmit2`, so the flag is not optional here: `VkContext >> buildFeatureChain` enables it on every device it creates, and a device that clears it cannot run anything this project builds. There is no `VkPhysicalDevice` predicate for it precisely because nothing branches on it.
"
Class {
	#name : 'VkPhysicalDeviceSynchronization2Features',
	#superclass : 'VkFeatureStructure',
	#classVars : [
		'OFFSET_PNEXT',
		'OFFSET_STYPE',
		'OFFSET_SYNCHRONIZATION2'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPhysicalDeviceSynchronization2Features class >> exampleSynchronization2OfThisMachine [
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
		  chainedWith: self
		  do: [ :head :features | features copyIntoObjectMemory ] ] ensure: [
		  context destroy ]
]

{ #category : 'field definition' }
VkPhysicalDeviceSynchronization2Features class >> fieldsDesc [
	"VkPhysicalDeviceSynchronization2Features as the C header declares it. VkBool32 is uint32.
	 pNext is void* rather than a typed pointer, because a chained structure's successor is
	 read through VkBaseOutStructure and nothing may run over the structures a walker reads."

	^ #(
		int32 sType;
		void* pNext;
		uint32 synchronization2
	)
]

{ #category : 'constants' }
VkPhysicalDeviceSynchronization2Features class >> structureType [
	"The one VkStructureType constant that names this structure, so a builder and an
	 example both ask the same place for it."

	^ VkStructureType physicalDeviceSynchronization2Features
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSynchronization2Features >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSynchronization2Features >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSynchronization2Features >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSynchronization2Features >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSynchronization2Features >> synchronization2 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SYNCHRONIZATION2
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSynchronization2Features >> synchronization2: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SYNCHRONIZATION2 put: anObject
]
