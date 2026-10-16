"
The request vkCreateRenderPass reads: the attachments of the pass, its subpasses and the dependencies between them, each as a count and a pointer. Every pass in this project has one attachment, one subpass and no dependency, so the dependency count and pointer stay as the zeroed block left them. VkRenderPass class >> createInfoForAttachment:subpass: is its one writer, and passRequestRows is what the Request tab reads.
"
Class {
	#name : 'VkRenderPassCreateInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ATTACHMENTCOUNT',
		'OFFSET_DEPENDENCYCOUNT',
		'OFFSET_FLAGS',
		'OFFSET_PATTACHMENTS',
		'OFFSET_PDEPENDENCIES',
		'OFFSET_PNEXT',
		'OFFSET_PSUBPASSES',
		'OFFSET_STYPE',
		'OFFSET_SUBPASSCOUNT'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkRenderPassCreateInfo class >> fieldsDesc [
	"A count and a pointer for each of the three lists the request carries: the attachments,
	 the subpasses and the dependencies between them."

	^ #( int32 sType; void* pNext; uint32 flags; uint32 attachmentCount;
	     void* pAttachments; uint32 subpassCount; void* pSubpasses;
	     uint32 dependencyCount; void* pDependencies )
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> attachmentCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ATTACHMENTCOUNT
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> attachmentCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ATTACHMENTCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> dependencyCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPENDENCYCOUNT
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> dependencyCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPENDENCYCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkRenderPassCreateInfo >> initializeConstantFields [
	"The structure type is the only field fixed by the type. The attachment and subpass
	 counts are one for every pass this project creates, but they are a caller's choice
	 rather than a property of the structure, and a request pointing at nothing must not
	 claim an attachment."

	self sType: VkStructureType renderPassCreateInfo
]

{ #category : 'inspector' }
VkRenderPassCreateInfo >> inspectorRequest: aBuilder [
	"What the driver is asked to build, rather than where the fields sit. The rows come from
	 passRequestRows, which reads this store only and follows no pointer, so opening the tab
	 changes nothing and cannot dereference a request that points nowhere."

	<inspectorPresentationOrder: 30 title: 'Request'>
	| rows |
	rows := self passRequestRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Asks' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Attachments'. (rows at: #attachmentCount) }.
				  { 'Attachment run set'. (rows at: #attachmentsSet) }.
				  { 'Subpasses'. (rows at: #subpassCount) }.
				  { 'Subpass run set'. (rows at: #subpassesSet) }.
				  { 'Dependencies'. (rows at: #dependencyCount) }.
				  { 'Dependency run set'. (rows at: #dependenciesSet) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pAttachments [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PATTACHMENTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pAttachments: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PATTACHMENTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pDependencies [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PDEPENDENCIES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pDependencies: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PDEPENDENCIES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pSubpasses [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSUBPASSES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> pSubpasses: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSUBPASSES put: anObject getHandle.
]

{ #category : 'reporting' }
VkRenderPassCreateInfo >> passRequestRows [
	"What the driver is asked to build: how many attachments, subpasses and dependencies the
	 request names, and whether each run it points at is there. A pointer is reported as set
	 or not rather than followed: its address says nothing to a reader, and a request
	 pointing nowhere must not be dereferenced. Read only, so the tab leaves the store
	 alone."

	^ Dictionary new
		  at: #attachmentCount put: self attachmentCount;
		  at: #attachmentsSet put: self pAttachments isNull not;
		  at: #subpassCount put: self subpassCount;
		  at: #subpassesSet put: self pSubpasses isNull not;
		  at: #dependencyCount put: self dependencyCount;
		  at: #dependenciesSet put: self pDependencies isNull not;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> subpassCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUBPASSCOUNT
]

{ #category : 'accessing - structure variables' }
VkRenderPassCreateInfo >> subpassCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUBPASSCOUNT put: anObject
]
