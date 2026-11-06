"
VkPipelineShaderStageCreateInfo: one shader stage of a pipeline — which stage it is, the module the code comes from, the entry point in that module and an optional specialization. Declared field by field, so uFFI computes all seven offsets; the structure is forty-eight bytes, with the padding after the flags and stage pair that puts the module handle on a pointer boundary.

It is used two ways. A compute pipeline carries one stage nested by value inside VkComputePipelineCreateInfo at byte twenty-four, and a graphics pipeline points at a run of two of them, built by VkGraphicsPipeline class >> shaderStagesForVertexModule:fragmentModule:. Because of the nesting it declares no initializeConstantFields even though its sType is fixed by its type: the generated getter for a nested field answers the stage through fromHandle:, which runs initialize on every read of the field, and an initializer would therefore write into the enclosing request each time it is read. Each builder stamps the type along with the rest, and each gives back the C string pName points at — VkComputePipeline class >> freeEntryPointOf: for the nested stage, VkGraphicsPipeline class >> freeShaderStageEntryPointsOf: for the run.

stageRows decodes a stage for the Stage tab, and the compute request reads the same rows for the stage inside it, so the two tabs cannot drift apart. See VkStructure >> initialize.
"
Class {
	#name : 'VkPipelineShaderStageCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FLAGS',
		'OFFSET_MODULE',
		'OFFSET_PNAME',
		'OFFSET_PNEXT',
		'OFFSET_PSPECIALIZATIONINFO',
		'OFFSET_STAGE',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPipelineShaderStageCreateInfo class >> fieldsDesc [
	"One shader stage of a pipeline. flags and stage are a uint32 pair, so uFFI puts them at
	 sixteen and twenty and pads to twenty-four, where module — a handle, and therefore pointer
	 wide — can sit. pName points at a NUL terminated C string naming the entry point in that
	 module; pSpecializationInfo is optional and this project leaves it null, so it is declared
	 void* rather than naming a structure nothing builds."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 stage;
		VkShaderModule_H* module;
		void* pName;
		void* pSpecializationInfo
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'inspector' }
VkPipelineShaderStageCreateInfo >> inspectorStage: aBuilder [
	"What this stage asks the driver for, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from stageRows, which only reads, so opening the tab
	 changes nothing."

	<inspectorPresentationOrder: 30 title: 'Stage'>
	| rows |
	rows := self stageRows.
	^ PVFactRow
		  tableOf: {
				  (PVFactRow name: 'Shader stage' value: (rows at: #stageName)).
				  (PVFactRow name: 'Module given' value: (rows at: #moduleGiven)).
				  (PVFactRow name: 'Entry point' value: (rows at: #entryPoint)).
				  (PVFactRow
					   name: 'Specialization given'
					   value: (rows at: #specializationGiven)) }
		  nameColumn: 'Asks for'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> module [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_MODULE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> module: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_MODULE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pName [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNAME) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pName: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNAME put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pSpecializationInfo [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSPECIALIZATIONINFO) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> pSpecializationInfo: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSPECIALIZATIONINFO put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> stage [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STAGE
]

{ #category : 'accessing - structure variables' }
VkPipelineShaderStageCreateInfo >> stage: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STAGE put: anObject
]

{ #category : 'accessing' }
VkPipelineShaderStageCreateInfo >> stageRows [
	"What this stage asks for, rather than where its fields sit: the stage named through
	 VkShaderStage, the entry point read back out of the C string the stage points at, and
	 whether each optional pointer is there. A freed entry point reads as the null label rather
	 than as a string from memory that has gone. Read only, so a view built from this leaves the
	 store alone."

	^ Dictionary new
		  at: #stageName put: (VkShaderStage nameForFlags: self stage);
		  at: #moduleGiven put: self module isNull not;
		  at: #entryPoint
		  put: (self pName isNull
				   ifTrue: [ self class nullLabel ]
				   ifFalse: [ self pName getHandle readString asString ]);
		  at: #specializationGiven put: self pSpecializationInfo isNull not;
		  yourself
]
