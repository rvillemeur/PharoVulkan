"
Which attachment of a render pass a subpass reads, and the layout it reads it in. Carries no chain header and so has no initializer: a reference is read in place, and it is pointed at from a subpass description, whose getter would otherwise write through the pointer. VkRenderPass class >> colorAttachmentReference is its one writer.
"
Class {
	#name : 'VkAttachmentReference',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ATTACHMENT',
		'OFFSET_LAYOUT'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkAttachmentReference class >> exampleReferenceToTheColourAttachment [
	"One click: the reference every subpass here reads, written by its one writer. The answer
	 is a copy in object memory, so the external block is freed with the example."

	<sampleInstance>
	| reference |
	reference := VkRenderPass colorAttachmentReference.
	^ [ reference copyIntoObjectMemory ] ensure: [ reference getHandle free ]
]

{ #category : 'field definition' }
VkAttachmentReference class >> fieldsDesc [
	"Which attachment of the pass a subpass reads, and the layout it reads it in."

	^ #( uint32 attachment; int32 layout )
]

{ #category : 'accessing - structure variables' }
VkAttachmentReference >> attachment [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ATTACHMENT
]

{ #category : 'accessing - structure variables' }
VkAttachmentReference >> attachment: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ATTACHMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkAttachmentReference >> layout [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_LAYOUT
]

{ #category : 'accessing - structure variables' }
VkAttachmentReference >> layout: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_LAYOUT put: anObject
]
