"
VkComputePipelineCreateInfo: the request vkCreateComputePipelines is given — one shader stage, the pipeline layout it runs against, and the pipeline it derives from. Declared field by field, so uFFI computes all seven offsets; the stage is nested by value rather than pointed at, so the forty-eight bytes of VkPipelineShaderStageCreateInfo sit inside this structure from byte twenty-four and the whole is ninety-six bytes. basePipelineIndex is a signed int32, which is why no base pipeline is minus one — see VkComputePipeline class >> noBasePipelineIndex — rather than the unsigned value with every bit set.

VkComputePipeline class >> createInfoForModule:entryPoint:layout: is the one writer: it writes the nested stage through the generated field accessor, which answers a view on this request's own bytes. The request owns the NUL terminated entry point string pName points at, so it is freed through VkComputePipeline class >> freeCreateInfo: and the field nulled as it goes. computePipelineRows is what the Pipeline tab reads; it names the stage through VkShaderStage and reports a freed entry point as the null label rather than reading memory that has gone. Key methods: computePipelineRows, class-side exampleRequestForAComputeShader.
"
Class {
	#name : 'VkComputePipelineCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BASEPIPELINEHANDLE',
		'OFFSET_BASEPIPELINEINDEX',
		'OFFSET_FLAGS',
		'OFFSET_LAYOUT',
		'OFFSET_PNEXT',
		'OFFSET_STAGE',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkComputePipelineCreateInfo class >> fieldsDesc [
	"One compute pipeline to create. The stage is nested by value, not pointed at, so the
	 forty-eight bytes of VkPipelineShaderStageCreateInfo sit inside this structure from byte
	 twenty-four; layout and basePipelineHandle are handles and therefore pointer wide, and
	 basePipelineIndex is a signed int32, which is why the sentinel for no base pipeline is
	 minus one rather than the unsigned value with every bit set."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		VkPipelineShaderStageCreateInfo stage;
		VkPipelineLayout_H* layout;
		VkPipeline_H* basePipelineHandle;
		int32 basePipelineIndex
	)
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> basePipelineHandle [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_BASEPIPELINEHANDLE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> basePipelineHandle: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_BASEPIPELINEHANDLE put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> basePipelineIndex [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_BASEPIPELINEINDEX
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> basePipelineIndex: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_BASEPIPELINEINDEX put: anObject
]

{ #category : 'accessing' }
VkComputePipelineCreateInfo >> computePipelineRows [
	"What this request asks for, rather than where its fields sit: the rows of the stage nested
	 inside it, followed by what the request itself adds. The stage decodes its own fields, so
	 the Pipeline tab here and the Stage tab of a graphics stage cannot drift apart. Read only,
	 so a view built from this leaves the store alone."

	^ self stage stageRows
		  at: #layoutGiven put: self layout isNull not;
		  at: #derivesFromAPipeline put: self basePipelineHandle isNull not;
		  at: #basePipelineIndex put: self basePipelineIndex;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkComputePipelineCreateInfo >> initializeConstantFields [
	"The structure type is the only field fixed by this type. The nested stage's type is just as
	 fixed but may not be written here: the generated getter for a nested field answers the stage
	 through fromHandle:, so an initializer on the stage would write into this request on every
	 read of the field. The builder writes it instead."

	self sType: VkStructureType computePipelineCreateInfo
]

{ #category : 'inspector' }
VkComputePipelineCreateInfo >> inspectorComputePipeline: aBuilder [
	"What this request asks the driver to create, rather than where the fields sit: the Layout
	 and Fields tabs answer that. The rows come from computePipelineRows, which only reads,
	 so opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Pipeline'>
	| rows |
	rows := self computePipelineRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Creates' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Shader stage'. (rows at: #stageName) }.
				  { 'Module given'. (rows at: #moduleGiven) }.
				  { 'Entry point'. (rows at: #entryPoint) }.
				  { 'Specialization given'. (rows at: #specializationGiven) }.
				  { 'Pipeline layout given'. (rows at: #layoutGiven) }.
				  { 'Derives from a pipeline'. (rows at: #derivesFromAPipeline) }.
				  { 'Base pipeline index'. (rows at: #basePipelineIndex) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> layout [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_LAYOUT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> layout: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_LAYOUT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> stage [
	"This method was automatically generated"
	^ VkPipelineShaderStageCreateInfo fromHandle: (handle referenceStructAt: OFFSET_STAGE length: VkPipelineShaderStageCreateInfo byteSize)
]

{ #category : 'accessing - structure variables' }
VkComputePipelineCreateInfo >> stage: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_STAGE put: anObject getHandle length: VkPipelineShaderStageCreateInfo byteSize
]
