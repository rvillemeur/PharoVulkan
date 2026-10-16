"
VkPipelineInputAssemblyStateCreateInfo: how the driver assembles primitives from the vertex run — the topology, and whether an index value restarts the primitive. Declared field by field, so uFFI computes the five offsets; the structure is thirty-two bytes, the uint32 pair at twenty and twenty-four padded out to a pointer boundary.

VkGraphicsPipeline class >> inputAssemblyState is the one writer, and it owns nothing: the state points at nothing and is freed by its own store alone. initializeConstantFields stamps sType, which is the only field fixed by the type. inputAssemblyRows decodes it for the Input assembly tab, naming the topology through VkPrimitiveTopology.
"
Class {
	#name : 'VkPipelineInputAssemblyStateCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_PNEXT',
		'OFFSET_PRIMITIVERESTARTENABLE',
		'OFFSET_STYPE',
		'OFFSET_TOPOLOGY'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPipelineInputAssemblyStateCreateInfo class >> fieldsDesc [
	"The topology and the restart flag are a uint32 pair after the flags, so uFFI puts them at
	 twenty and twenty-four and pads the structure to thirty-two. The topology is an enumeration
	 and so declared signed, as every VkStructureType and VkFormat here is; primitiveRestartEnable
	 is a VkBool32, declared as the uint32 it is."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		int32 topology;
		uint32 primitiveRestartEnable
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkPipelineInputAssemblyStateCreateInfo >> initializeConstantFields [

	self sType: VkStructureType pipelineInputAssemblyStateCreateInfo
]

{ #category : 'accessing' }
VkPipelineInputAssemblyStateCreateInfo >> inputAssemblyRows [
	"What this state asks for, rather than where its fields sit: the topology named through
	 VkPrimitiveTopology rather than shown as a number, and whether primitive restart is asked
	 for. Read only, so a view built from this leaves the store alone."

	^ Dictionary new
		  at: #topologyName
		  put: ((VkPrimitiveTopology nameForValue: self topology)
				   ifNil: [ self topology printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #primitiveRestart put: self primitiveRestartEnable ~= 0;
		  yourself
]

{ #category : 'inspector' }
VkPipelineInputAssemblyStateCreateInfo >> inspectorInputAssembly: aBuilder [
	"What this state asks the driver for, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from inputAssemblyRows, which only reads, so
	 opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Input assembly'>
	| rows |
	rows := self inputAssemblyRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Topology'. (rows at: #topologyName) }.
				  { 'Primitive restart'. (rows at: #primitiveRestart) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> primitiveRestartEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_PRIMITIVERESTARTENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> primitiveRestartEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_PRIMITIVERESTARTENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> topology [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_TOPOLOGY
]

{ #category : 'accessing - structure variables' }
VkPipelineInputAssemblyStateCreateInfo >> topology: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_TOPOLOGY put: anObject
]
