"
The head of a VkPhysicalDeviceFeatures2 query: the structure vkGetPhysicalDeviceFeatures2 fills, and the entry point for asking a device about a feature that lives in a chained structure. `of: aPhysicalDeviceHandle chainedWith: aStructureClass do: aBlock` builds the two structures outside the image, asks the driver, and hands both to the block, which must copy out anything it means to keep: the memory is freed on the way out. The embedded features block is a VkPhysicalDeviceFeatures, declared member by member, so the driver cannot write past what this image allocated.
"
Class {
	#name : 'VkPhysicalDeviceFeatures2',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FEATURES',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPhysicalDeviceFeatures2 class >> fieldsDesc [
	"pNext is eight byte aligned, so the C layout pads after sType; declaring the pointer as
	 a pointer lets uFFI insert that pad itself. The embedded features block is declared as
	 its own structure, so its size comes from the member list rather than from a count."

	^ #(
		uint32 sType;
		void *pNext;
		VkPhysicalDeviceFeatures features
	)
]

{ #category : 'querying' }
VkPhysicalDeviceFeatures2 class >> of: aVkPhysicalDevice_H chainedWith: aStructureClass do: aBlock [
	"Builds the chain in memory outside the image, because the driver walks pNext and a
	 ByteArray may move under the garbage collector while it holds a pointer into one. Both
	 structures are freed on the way out, so the caller gets them inside a block and copies
	 out whatever it means to keep."

	| head chained |
	head := self externalInstance.
	^ [
	  chained := aStructureClass externalInstance.
	  [
	  head sType: self structureType.
	  head pNext: chained getHandle.
	  chained sType: aStructureClass structureType.
	  Vk getPhysicalDeviceFeatures2: aVkPhysicalDevice_H into: head getHandle.
	  aBlock value: head value: chained ] ensure: [ chained getHandle free ] ]
		  ensure: [ head getHandle free ]
]

{ #category : 'accessing' }
VkPhysicalDeviceFeatures2 class >> structureType [
	^ VkStructureType physicalDeviceFeatures2
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures2 >> features [
	"This method was automatically generated"
	^ VkPhysicalDeviceFeatures fromHandle: (handle referenceStructAt: OFFSET_FEATURES length: VkPhysicalDeviceFeatures byteSize)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures2 >> features: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_FEATURES put: anObject getHandle length: VkPhysicalDeviceFeatures byteSize
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures2 >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures2 >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures2 >> sType [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures2 >> sType: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STYPE put: anObject
]
