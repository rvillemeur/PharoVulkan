"
The VkPhysicalDeviceProperties2 query structure: sType, pNext and a VkPhysicalDeviceProperties by value. Built in memory outside the image, because the driver follows the pNext pointer and a ByteArray may move under the garbage collector. Key method: properties.
"
Class {
	#name : 'VkPhysicalDeviceProperties2',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_PNEXT',
		'OFFSET_PROPERTIES',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPhysicalDeviceProperties2 class >> fieldsDesc [
	"pNext is eight byte aligned, so the C layout pads after sType; declaring the pointer as a
	 pointer lets uFFI insert that pad itself."

	^ #(
		uint32 sType;
		void *pNext;
		VkPhysicalDeviceProperties properties
	)
]

{ #category : 'querying' }
VkPhysicalDeviceProperties2 class >> of: aVkPhysicalDevice_H chainedWith: aStructureClass do: aBlock [
	"Builds the chain in memory outside the image, because the driver walks pNext and a
	 ByteArray may move under the garbage collector while it holds a pointer into one. Both
	 structures are freed on the way out, so the caller gets them inside a block and copies out
	 whatever it means to keep."

	| head chained |
	head := self externalInstance.
	^ [
	  chained := aStructureClass externalInstance.
	  [
	  head sType: self structureType.
	  head pNext: chained getHandle.
	  chained sType: aStructureClass structureType.
	  Vk getPhysicalDeviceProperties2: aVkPhysicalDevice_H into: head getHandle.
	  aBlock value: head value: chained ] ensure: [ chained getHandle free ] ]
		  ensure: [ head getHandle free ]
]

{ #category : 'accessing' }
VkPhysicalDeviceProperties2 class >> structureType [
	"The sType every instance of this structure must carry, so a chained query can set it from
	 the class alone."

	^ VkStructureType physicalDeviceProperties2
]

{ #category : 'accessing' }
VkPhysicalDeviceProperties2 >> chainRows [
	"What the Chain view shows, read back from this instance: the structure type is named by the
	 constant class rather than restated here, and the chain row asks the pointer itself, so a
	 copy whose chain was cleared reads as unlinked."

	^ {
		  ('Structure type'
		   -> (VkStructureType nameForValue: self sType) printString).
		  ('Chained block' -> (self pNext isNull
			    ifTrue: [ 'none' ]
			    ifFalse: [ self pNext asInteger printStringBase: 16 ])).
		  ('Device' -> self properties deviceNameString).
		  ('API version' -> self properties apiVersion printString) }
]

{ #category : 'inspector' }
VkPhysicalDeviceProperties2 >> inspectorChain: aBuilder [
	"The rows come from this instance, and the store is only read, so inspecting a query
	 structure cannot change what the driver wrote into it."

	<inspectorPresentationOrder: 10 title: 'Chain'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each key ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each value ]);
		  items: self chainRows;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties2 >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties2 >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties2 >> properties [
	"This method was automatically generated"
	^ VkPhysicalDeviceProperties fromHandle: (handle referenceStructAt: OFFSET_PROPERTIES length: VkPhysicalDeviceProperties byteSize)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties2 >> properties: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_PROPERTIES put: anObject getHandle length: VkPhysicalDeviceProperties byteSize
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties2 >> sType [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties2 >> sType: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STYPE put: anObject
]
