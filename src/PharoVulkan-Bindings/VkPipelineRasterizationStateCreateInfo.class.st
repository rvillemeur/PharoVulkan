"
VkPipelineRasterizationStateCreateInfo: how the driver turns triangles into fragments — the polygon mode, which faces it discards, which winding is a front face, the depth bias factors and the line width. Declared field by field, so uFFI computes the thirteen offsets; every field after the flags is four bytes wide and tightly packed, which makes the structure sixty-four bytes.

VkGraphicsPipeline class >> rasterizationState is the one writer, and it owns nothing: the state points at nothing and is freed by its own store alone. It writes the three enumerations and the line width and leaves depth clamp, rasterizer discard and the depth bias fields as the zeroed block left them, which is what disabled reads as. initializeConstantFields stamps sType, the only field fixed by the type. rasterizationRows decodes it for the Rasterization tab, naming the polygon mode through VkPolygonMode, the culling through VkCullMode and the winding through VkFrontFace.
"
Class {
	#name : 'VkPipelineRasterizationStateCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_CULLMODE',
		'OFFSET_DEPTHBIASCLAMP',
		'OFFSET_DEPTHBIASCONSTANTFACTOR',
		'OFFSET_DEPTHBIASENABLE',
		'OFFSET_DEPTHBIASSLOPEFACTOR',
		'OFFSET_DEPTHCLAMPENABLE',
		'OFFSET_FLAGS',
		'OFFSET_FRONTFACE',
		'OFFSET_LINEWIDTH',
		'OFFSET_PNEXT',
		'OFFSET_POLYGONMODE',
		'OFFSET_RASTERIZERDISCARDENABLE',
		'OFFSET_STYPE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPipelineRasterizationStateCreateInfo class >> fieldsDesc [
	"Every field after the flags is four bytes wide and tightly packed, so uFFI lays the three
	 flags, the three enumerations and the four floats out from twenty to fifty-six and the
	 structure runs to sixty-four. The enumerations are declared signed, as every other
	 enumeration field here is; the three enable fields are VkBool32 and so declared as the
	 uint32 they are. The four factors are floats, so a line width is written as 1.0 rather
	 than as the word that bit pattern makes."

	^ #(
		int32 sType;
		void* pNext;
		uint32 flags;
		uint32 depthClampEnable;
		uint32 rasterizerDiscardEnable;
		int32 polygonMode;
		uint32 cullMode;
		int32 frontFace;
		uint32 depthBiasEnable;
		float depthBiasConstantFactor;
		float depthBiasClamp;
		float depthBiasSlopeFactor;
		float lineWidth
	)
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> cullMode [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_CULLMODE
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> cullMode: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_CULLMODE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasClamp [
	"This method was automatically generated"
	^handle floatAt: OFFSET_DEPTHBIASCLAMP
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasClamp: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_DEPTHBIASCLAMP put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasConstantFactor [
	"This method was automatically generated"
	^handle floatAt: OFFSET_DEPTHBIASCONSTANTFACTOR
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasConstantFactor: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_DEPTHBIASCONSTANTFACTOR put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPTHBIASENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPTHBIASENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasSlopeFactor [
	"This method was automatically generated"
	^handle floatAt: OFFSET_DEPTHBIASSLOPEFACTOR
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthBiasSlopeFactor: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_DEPTHBIASSLOPEFACTOR put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthClampEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPTHCLAMPENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> depthClampEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPTHCLAMPENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> frontFace [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_FRONTFACE
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> frontFace: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_FRONTFACE put: anObject
]

{ #category : 'initialization' }
VkPipelineRasterizationStateCreateInfo >> initializeConstantFields [

	self sType: VkStructureType pipelineRasterizationStateCreateInfo
]

{ #category : 'inspector' }
VkPipelineRasterizationStateCreateInfo >> inspectorRasterization: aBuilder [
	"What this state asks the driver for, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from rasterizationRows, which only reads, so
	 opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Rasterization'>
	| rows |
	rows := self rasterizationRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Asks for' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Polygon mode'. (rows at: #polygonModeName) }.
				  { 'Cull mode'. (rows at: #cullModeNames) }.
				  { 'Front face'. (rows at: #frontFaceName) }.
				  { 'Line width'. (rows at: #lineWidth) }.
				  { 'Depth clamp'. (rows at: #depthClamp) }.
				  { 'Rasterization discarded'. (rows at: #rasterizationDiscarded) }.
				  { 'Depth bias'. (rows at: #depthBias) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> lineWidth [
	"This method was automatically generated"
	^handle floatAt: OFFSET_LINEWIDTH
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> lineWidth: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_LINEWIDTH put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> polygonMode [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_POLYGONMODE
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> polygonMode: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_POLYGONMODE put: anObject
]

{ #category : 'accessing' }
VkPipelineRasterizationStateCreateInfo >> rasterizationRows [
	"What this state asks for, rather than where its fields sit: each enumeration named by the
	 constants class that owns the value, the line width, and one entry per feature that can
	 be switched on. Read only, so a view built from this leaves the store alone."

	^ Dictionary new
		  at: #polygonModeName
		  put: ((VkPolygonMode nameForValue: self polygonMode)
				   ifNil: [ self polygonMode printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #cullModeNames put: (VkCullMode nameForFlags: self cullMode);
		  at: #frontFaceName
		  put: ((VkFrontFace nameForValue: self frontFace)
				   ifNil: [ self frontFace printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #lineWidth put: self lineWidth;
		  at: #depthClamp put: self depthClampEnable ~= 0;
		  at: #rasterizationDiscarded put: self rasterizerDiscardEnable ~= 0;
		  at: #depthBias put: self depthBiasEnable ~= 0;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> rasterizerDiscardEnable [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_RASTERIZERDISCARDENABLE
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> rasterizerDiscardEnable: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_RASTERIZERDISCARDENABLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPipelineRasterizationStateCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]
