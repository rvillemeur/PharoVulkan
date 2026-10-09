"
A VkPhysicalDeviceSubgroupProperties block, chained onto VkPhysicalDeviceProperties2 through pNext. Key methods: subgroupSize, supportedOperations, supportedStages; the operation bits are named by VkSubgroupFeature.
"
Class {
	#name : 'VkPhysicalDeviceSubgroupProperties',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_PNEXT',
		'OFFSET_QUADOPERATIONSINALLSTAGES',
		'OFFSET_STYPE',
		'OFFSET_SUBGROUPSIZE',
		'OFFSET_SUPPORTEDOPERATIONS',
		'OFFSET_SUPPORTEDSTAGES'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPhysicalDeviceSubgroupProperties class >> exampleSubgroupPropertiesOfThisMachine [
	"One click: the subgroup width and operations this machine's driver reports, with the
	 Features view beside them. The block is copied into object memory by the query, so it still
	 reads after the context has gone."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ context physicalDevice subgroupProperties ]
		  ensure: [ context destroy ]
]

{ #category : 'field definition' }
VkPhysicalDeviceSubgroupProperties class >> fieldsDesc [
	"quadOperationsInAllStages is a VkBool32, so it is declared as the uint32 it is."

	^ #(
		uint32 sType;
		void *pNext;
		uint32 subgroupSize;
		uint32 supportedStages;
		uint32 supportedOperations;
		uint32 quadOperationsInAllStages
	)
]

{ #category : 'accessing' }
VkPhysicalDeviceSubgroupProperties class >> structureType [
	"The sType every instance of this structure must carry, so a chained query can set it from
	 the class alone."

	^ VkStructureType physicalDeviceSubgroupProperties
]

{ #category : 'inspector' }
VkPhysicalDeviceSubgroupProperties >> inspectorFeatures: aBuilder [
	"One row per named VkSubgroupFeature bit, each answered by the predicate every caller uses,
	 so the table cannot say a feature is present where a caller would find it absent."

	<inspectorPresentationOrder: 10 title: 'Features'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Feature' evaluated: [ :each |
					   each ]);
		  addColumn: (SpStringTableColumn title: 'Supported' evaluated: [ :each |
					   (self supportsFeature: (VkSubgroupFeature perform: each))
						   printString ]);
		  items: VkSubgroupFeature featureSelectors;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> quadOperationsInAllStages [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_QUADOPERATIONSINALLSTAGES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> quadOperationsInAllStages: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_QUADOPERATIONSINALLSTAGES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> sType [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> sType: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> subgroupSize [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUBGROUPSIZE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> subgroupSize: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUBGROUPSIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> supportedOperations [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUPPORTEDOPERATIONS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> supportedOperations: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUPPORTEDOPERATIONS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> supportedStages [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUPPORTEDSTAGES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceSubgroupProperties >> supportedStages: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUPPORTEDSTAGES put: anObject
]

{ #category : 'testing' }
VkPhysicalDeviceSubgroupProperties >> supportsFeature: aBit [
	"The one rule for reading supportedOperations. VkPhysicalDevice and the inspector view both
	 ask it, so neither can drift from the other."

	^ (self supportedOperations bitAnd: aBit) ~= 0
]
