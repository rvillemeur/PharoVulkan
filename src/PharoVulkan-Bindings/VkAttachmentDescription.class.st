"
One attachment of a render pass, as the driver reads it: its format and sample count, what happens to its contents on load and on store, the same for its stencil half, and the layouts it enters and leaves the pass in. Carries no chain header, because the driver reads a description in place rather than through a chain, which is also why it has no initializer. VkAttachmentOp names the load and store operations and VkImageLayout the layouts. VkRenderPass class >> attachmentDescriptionForFormat:finalLayout: is its one writer, and attachmentRows is what the Attachment tab reads.
"
Class {
	#name : 'VkAttachmentDescription',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_FINALLAYOUT',
		'OFFSET_FLAGS',
		'OFFSET_FORMAT',
		'OFFSET_INITIALLAYOUT',
		'OFFSET_LOADOP',
		'OFFSET_SAMPLES',
		'OFFSET_STENCILLOADOP',
		'OFFSET_STENCILSTOREOP',
		'OFFSET_STOREOP'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkAttachmentDescription class >> fieldsDesc [
	"Nine words, no chain header: the driver reads an attachment description in place rather
	 than through a chain. The stencil halves are declared because the C structure has them,
	 even though no pass here uses a stencil."

	^ #( uint32 flags; int32 format; uint32 samples; int32 loadOp; int32 storeOp;
	     int32 stencilLoadOp; int32 stencilStoreOp; int32 initialLayout;
	     int32 finalLayout )
]

{ #category : 'reporting' }
VkAttachmentDescription >> attachmentRows [
	"What this attachment asks of the driver, named through the constant classes rather than
	 restated here: its format, what happens to its contents on load and on store, and the
	 layouts it enters and leaves the pass in. The load and store operations are numbered
	 independently of each other, so each is named by the half it belongs to. usesStencil
	 asks the store whether either stencil half was given anything to do, so a pass that
	 grows a stencil attachment reports one without this method changing. Read only, so the
	 tab leaves the store alone."

	^ Dictionary new
		  at: #formatName put: ((VkFormat nameForValue: self format)
				   ifNil: [ self format printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #loadOpName put: ((VkAttachmentOp nameForLoadOp: self loadOp)
				   ifNil: [ self loadOp printString ]);
		  at: #storeOpName put: ((VkAttachmentOp nameForStoreOp: self storeOp)
				   ifNil: [ self storeOp printString ]);
		  at: #initialLayoutName
		  put: ((VkImageLayout nameForValue: self initialLayout)
				   ifNil: [ self initialLayout printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #finalLayoutName put: ((VkImageLayout nameForValue: self finalLayout)
				   ifNil: [ self finalLayout printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #usesStencil
		  put: (self stencilLoadOp ~= VkAttachmentOp loadDontCare or: [
				   self stencilStoreOp ~= VkAttachmentOp storeDiscard ]);
		  yourself
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> finalLayout [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_FINALLAYOUT
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> finalLayout: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_FINALLAYOUT put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> format [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_FORMAT
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> format: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_FORMAT put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> initialLayout [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_INITIALLAYOUT
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> initialLayout: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_INITIALLAYOUT put: anObject
]

{ #category : 'inspector' }
VkAttachmentDescription >> inspectorAttachment: aBuilder [
	"What the attachment asks of the driver, rather than where its fields sit: the Layout and
	 Fields tabs answer that. The rows come from attachmentRows, which names every value
	 through the constant classes and reads nothing but this store, so opening the tab
	 changes nothing and follows no pointer."

	<inspectorPresentationOrder: 30 title: 'Attachment'>
	| rows |
	rows := self attachmentRows.
	^ PVFactRow
		  tableOf: {
				  (PVFactRow name: 'Format' value: (rows at: #formatName)).
				  (PVFactRow name: 'On load' value: (rows at: #loadOpName)).
				  (PVFactRow name: 'On store' value: (rows at: #storeOpName)).
				  (PVFactRow
					   name: 'Layout on entry'
					   value: (rows at: #initialLayoutName)).
				  (PVFactRow
					   name: 'Layout on exit'
					   value: (rows at: #finalLayoutName)).
				  (PVFactRow name: 'Uses stencil' value: (rows at: #usesStencil)) }
		  nameColumn: 'Asks'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> loadOp [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_LOADOP
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> loadOp: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_LOADOP put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> samples [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLES
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> samples: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLES put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> stencilLoadOp [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STENCILLOADOP
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> stencilLoadOp: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STENCILLOADOP put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> stencilStoreOp [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STENCILSTOREOP
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> stencilStoreOp: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STENCILSTOREOP put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> storeOp [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STOREOP
]

{ #category : 'accessing - structure variables' }
VkAttachmentDescription >> storeOp: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STOREOP put: anObject
]
