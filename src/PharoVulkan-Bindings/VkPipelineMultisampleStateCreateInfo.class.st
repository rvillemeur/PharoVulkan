"
VkPipelineMultisampleStateCreateInfo: how many samples a pixel is made of, how much of the shading is done per sample, and the mask that selects which samples are written. Declared field by field, so uFFI computes the nine offsets; the sample mask pointer re-aligns the structure to thirty-two and the two alpha flags after it make forty-eight bytes.

VkGraphicsPipeline class >> multisampleState is the one writer, and it owns nothing: the state names no sample mask and is freed by its own store alone. It writes the sample count and the shading fraction and leaves sample shading and the two alpha flags as the zeroed block left them, which is what disabled reads as. initializeConstantFields stamps sType, the only field fixed by the type. multisampleRows decodes it for the Multisample tab, naming the sample count through VkSampleCount.
"
Class {
	#name : 'VkPipelineMultisampleStateCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ALPHATOCOVERAGEENABLE',
		'OFFSET_ALPHATOONEENABLE',
		'OFFSET_FLAGS',
		'OFFSET_MINSAMPLESHADING',
		'OFFSET_PNEXT',
		'OFFSET_PSAMPLEMASK',
		'OFFSET_RASTERIZATIONSAMPLES',
		'OFFSET_SAMPLESHADINGENABLE',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPipelineMultisampleStateCreateInfo class >> fieldsDesc [
	"The sample count, the shading flag and the shading fraction are four bytes each at twenty,
	 twenty-four and twenty-eight, then the sample mask pointer re-aligns to thirty-two and the
	 two alpha flags follow it, which makes forty-eight. rasterizationSamples is a
	 VkSampleCountFlagBits and carries one bit, declared as the uint32 it is; the three enable
	 fields are VkBool32 and declared the same way. minSampleShading is a float, so it is
	 written as a fraction rather than as the word that bit pattern makes. pSampleMask points
	 at a run of masks, and is one pointer wide whatever it points at."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 rasterizationSamples;
		uint32 sampleShadingEnable;
		float minSampleShading;
		void* pSampleMask;
		uint32 alphaToCoverageEnable;
		uint32 alphaToOneEnable
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> alphaToCoverageEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ALPHATOCOVERAGEENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> alphaToCoverageEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ALPHATOCOVERAGEENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> alphaToOneEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ALPHATOONEENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> alphaToOneEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ALPHATOONEENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkPipelineMultisampleStateCreateInfo >> initializeConstantFields [

	self sType: VkStructureType pipelineMultisampleStateCreateInfo
]

{ #category : 'inspector' }
VkPipelineMultisampleStateCreateInfo >> inspectorMultisample: aBuilder [
	"What this state asks the driver for, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from multisampleRows, which only reads, so
	 opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Multisample'>
	| rows |
	rows := self multisampleRows.
	^ PVFactRow
		  tableOf: {
				  (PVFactRow name: 'Samples' value: (rows at: #sampleCountNames)).
				  (PVFactRow
					   name: 'Sample shading'
					   value: (rows at: #sampleShading)).
				  (PVFactRow
					   name: 'Minimum sample shading'
					   value: (rows at: #minSampleShading)).
				  (PVFactRow
					   name: 'Sample mask given'
					   value: (rows at: #sampleMaskGiven)).
				  (PVFactRow
					   name: 'Alpha to coverage'
					   value: (rows at: #alphaToCoverage)).
				  (PVFactRow name: 'Alpha to one' value: (rows at: #alphaToOne)) }
		  nameColumn: 'Asks for'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> minSampleShading [
	"This method was automatically generated"
	^handle floatAt: OFFSET_MINSAMPLESHADING
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> minSampleShading: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_MINSAMPLESHADING put: anObject
]

{ #category : 'accessing' }
VkPipelineMultisampleStateCreateInfo >> multisampleRows [
	"What this state asks for, rather than where its fields sit: the sample count named by the
	 constants class that owns the bits, whether a sample mask is given, and one entry per
	 feature that can be switched on. Read only, so a view built from this leaves the store
	 alone."

	^ Dictionary new
		  at: #sampleCountNames
		  put: (VkSampleCount nameForFlags: self rasterizationSamples);
		  at: #sampleShading put: self sampleShadingEnable ~= 0;
		  at: #minSampleShading put: self minSampleShading;
		  at: #sampleMaskGiven put: self pSampleMask isNull not;
		  at: #alphaToCoverage put: self alphaToCoverageEnable ~= 0;
		  at: #alphaToOne put: self alphaToOneEnable ~= 0;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> pSampleMask [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSAMPLEMASK) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> pSampleMask: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSAMPLEMASK put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> rasterizationSamples [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_RASTERIZATIONSAMPLES
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> rasterizationSamples: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_RASTERIZATIONSAMPLES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> sampleShadingEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLESHADINGENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineMultisampleStateCreateInfo >> sampleShadingEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLESHADINGENABLE put: anObject
]
