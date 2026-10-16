"
One bound vertex buffer, as the vertex input state of a pipeline describes it: which binding number a shader reads it at, how many bytes one vertex occupies, and whether the buffer advances per vertex or per instance — see VkVertexInputRate. Declared field by field, so uFFI computes all three offsets; twelve bytes with no hole, because three uint32 fields need no padding.

It carries no chain header, because it is an element of the run the state points at rather than a structure the driver is handed on its own, so it stamps no constant field either. VkGraphicsPipeline class >> vertexBindingDescriptions builds the one this project draws with, in object memory; VkGraphicsPipeline class >> runOf: copies it into the contiguous external run the driver reads, because the garbage collector may move a store that lives inside the image. Key methods: bindingRows, class-side exampleBindingOfTheVertexThisProjectDraws.
"
Class {
	#name : 'VkVertexInputBindingDescription',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BINDING',
		'OFFSET_INPUTRATE',
		'OFFSET_STRIDE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkVertexInputBindingDescription class >> fieldsDesc [
	"How wide one vertex is in the buffer bound at a binding number, and whether the buffer
	 advances per vertex or per instance. Three uint32 fields with no chain header: the driver
	 reads it as an element of the run the vertex input state points at."

	^ #( uint32 binding; uint32 stride; uint32 inputRate )
]

{ #category : 'accessing - structure variables' }
VkVertexInputBindingDescription >> binding [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BINDING
]

{ #category : 'accessing - structure variables' }
VkVertexInputBindingDescription >> binding: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BINDING put: anObject
]

{ #category : 'reporting' }
VkVertexInputBindingDescription >> bindingRows [
	"What this description says about one bound buffer: which binding number it is read at, how
	 wide one vertex is, and the rate the buffer advances at, named through VkVertexInputRate.
	 A rate no constant names is shown as its number rather than dropped. Read only, so a view
	 built from this leaves the store alone."

	^ Dictionary new
		  at: #binding put: self binding;
		  at: #stride put: self stride;
		  at: #inputRateName
		  put: ((VkVertexInputRate nameForValue: self inputRate)
				   ifNil: [ self inputRate printString ]
				   ifNotNil: [ :each | each asString ]);
		  yourself
]

{ #category : 'accessing - structure variables' }
VkVertexInputBindingDescription >> inputRate [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_INPUTRATE
]

{ #category : 'accessing - structure variables' }
VkVertexInputBindingDescription >> inputRate: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_INPUTRATE put: anObject
]

{ #category : 'inspector' }
VkVertexInputBindingDescription >> inspectorBinding: aBuilder [
	"What this description says about the buffer, rather than where its three fields sit: the
	 Layout and Fields tabs answer that. The rows come from bindingRows, which only reads, so
	 opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Binding'>
	| rows |
	rows := self bindingRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Describes' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Binding number'. (rows at: #binding) }.
				  { 'Bytes per vertex'. (rows at: #stride) }.
				  { 'Advances'. (rows at: #inputRateName) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkVertexInputBindingDescription >> stride [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STRIDE
]

{ #category : 'accessing - structure variables' }
VkVertexInputBindingDescription >> stride: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STRIDE put: anObject
]
