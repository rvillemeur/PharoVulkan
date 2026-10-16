"
VkPipelineDynamicStateCreateInfo: which parts of the pipeline are set while a command buffer is recorded rather than fixed when the pipeline is built, and the run of state values naming them. Declared field by field, so uFFI computes the five offsets; the count at twenty and the run pointer at twenty-four pad the structure out to thirty-two bytes.

The run holds VkDynamicState values rather than structures, so uFFI gives no indexable view of it: dynamicStateByteCount names the stride, and the builder and dynamicStateValues both ask for it instead of counting bytes. VkGraphicsPipeline class >> dynamicState is the one writer; the state owns the run, so freeDynamicState: frees the run and nulls the field before freeing the state's own store. initializeConstantFields stamps sType, the only field fixed by the type. dynamicStateRows decodes it for the Dynamic state tab, naming each state through VkDynamicState.
"
Class {
	#name : 'VkPipelineDynamicStateCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DYNAMICSTATECOUNT',
		'OFFSET_FLAGS',
		'OFFSET_PDYNAMICSTATES',
		'OFFSET_PNEXT',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'constants' }
VkPipelineDynamicStateCreateInfo class >> dynamicStateByteCount [
	"One VkDynamicState is a four-byte enumeration. The run of them is not a run of structures,
	 so uFFI gives no indexable view of it: the stride is named here and both the builder and
	 the reader ask for it rather than counting bytes."

	^ 4
]

{ #category : 'field definition' }
VkPipelineDynamicStateCreateInfo class >> fieldsDesc [
	"A count at twenty and the run of state values at twenty-four, which the pointer pads out
	 to thirty-two. The run holds VkDynamicState values, which are enumerations rather than
	 structures, so the field is a plain pointer and the run is read by the stride this class
	 declares."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 dynamicStateCount;
		void* pDynamicStates
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> dynamicStateCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DYNAMICSTATECOUNT
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> dynamicStateCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DYNAMICSTATECOUNT put: anObject
]

{ #category : 'accessing' }
VkPipelineDynamicStateCreateInfo >> dynamicStateRows [
	"What this state asks for, rather than where its fields sit: how many states are set while
	 recording, whether the run of them is given, and each one named through VkDynamicState
	 rather than shown as a number. Read only, so a view built from this leaves the store
	 alone."

	^ Dictionary new
		  at: #dynamicStateCount put: self dynamicStateCount;
		  at: #stateRunGiven put: self pDynamicStates isNull not;
		  at: #dynamicStateNames
		  put: (', ' join: (self dynamicStateValues collect: [ :each |
					    (VkDynamicState nameForValue: each)
						    ifNil: [ each printString ]
						    ifNotNil: [ :name | name asString ] ]));
		  yourself
]

{ #category : 'accessing' }
VkPipelineDynamicStateCreateInfo >> dynamicStateValues [
	"The state values the run holds, read through the stride this class declares. A state whose
	 run has been given back answers none rather than reading an address that is no longer
	 ours."

	| stride |
	self pDynamicStates isNull ifTrue: [ ^ #(  ) ].
	stride := self class dynamicStateByteCount.
	^ (1 to: self dynamicStateCount) collect: [ :index |
		  self pDynamicStates getHandle unsignedLongAt:
			  index - 1 * stride + 1 ]
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkPipelineDynamicStateCreateInfo >> initializeConstantFields [

	self sType: VkStructureType pipelineDynamicStateCreateInfo
]

{ #category : 'inspector' }
VkPipelineDynamicStateCreateInfo >> inspectorDynamicState: aBuilder [
	"What this state asks the driver for, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from dynamicStateRows, which only reads, so
	 opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Dynamic state'>
	| rows |
	rows := self dynamicStateRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'States'. (rows at: #dynamicStateCount) }.
				  { 'State run given'. (rows at: #stateRunGiven) }.
				  { 'Set while recording'. (rows at: #dynamicStateNames) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> pDynamicStates [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PDYNAMICSTATES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> pDynamicStates: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PDYNAMICSTATES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineDynamicStateCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
