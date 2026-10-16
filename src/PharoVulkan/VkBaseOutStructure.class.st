"
The two fields every structure in a Vulkan pNext chain starts with: a `sType` and the pointer to the next structure. It is a read-only view over memory that belongs to some other structure, which is why it deliberately declares no `initializeConstantFields`: `FFIStructure class >> fromHandle:` sends `initialize`, so a constant field here would stamp this class's own type over the type of the structure being read, and that type is the one thing a walker is there to find out. `VkContext` uses it to walk a feature chain: `chain:onto:` finds the last link, `featureChainTypesIn:` collects the types along it, and `freeFeatureChain:` reads the successor out of each block before freeing that block.
"
Class {
	#name : 'VkBaseOutStructure',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkBaseOutStructure class >> fieldsDesc [
	"The two fields every structure in a pNext chain starts with. pNext is declared void*
	 rather than VkBaseOutStructure*, because a typed getter would answer the successor through
	 fromHandle:, and a walker that reads a chain must not have anything run over the
	 structures it reads."

	^ #(
		int32 sType;
		void* pNext
	)
]

{ #category : 'accessing - structure variables' }
VkBaseOutStructure >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkBaseOutStructure >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkBaseOutStructure >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkBaseOutStructure >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
