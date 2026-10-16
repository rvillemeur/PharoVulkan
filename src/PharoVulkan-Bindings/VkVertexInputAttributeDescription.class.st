"
One value a vertex shader reads, as the vertex input state of a pipeline describes it: the location it arrives at, the binding whose buffer holds it, its VkFormat and its byte offset within one vertex. Declared field by field, so uFFI computes all four offsets; sixteen bytes with no hole. format is declared signed, as it is wherever this project declares a VkFormat.

It carries no chain header, because it is an element of the run the state points at rather than a structure the driver is handed on its own, so it stamps no constant field either. VkGraphicsPipeline class >> vertexAttributeDescriptions builds the two this project draws with — a two-float position at the start of a vertex and a three-float colour after it — in object memory, and VkGraphicsPipeline class >> runOf: copies them into the contiguous external run the driver reads. Key methods: attributeRows, class-side examplePositionAttributeOfTheVertexThisProjectDraws.
"
Class {
	#name : 'VkVertexInputAttributeDescription',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BINDING',
		'OFFSET_FORMAT',
		'OFFSET_LOCATION',
		'OFFSET_OFFSET'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkVertexInputAttributeDescription class >> fieldsDesc [
	"Where one value a vertex shader reads sits inside a vertex: the location it arrives at, the
	 binding whose buffer holds it, its format and its byte offset within the vertex. format is
	 the same VkFormat enumeration an image is created with, so it is declared signed as there."

	^ #( uint32 location; uint32 binding; int32 format; uint32 offset )
]

{ #category : 'reporting' }
VkVertexInputAttributeDescription >> attributeRows [
	"What this description says about one value a vertex shader reads: the location it arrives
	 at, the binding whose buffer holds it, its format named through VkFormat, and where it sits
	 inside a vertex. A format no constant names is shown as its number rather than dropped.
	 Read only, so a view built from this leaves the store alone."

	^ Dictionary new
		  at: #location put: self location;
		  at: #binding put: self binding;
		  at: #formatName
		  put: ((VkFormat nameForValue: self format)
				   ifNil: [ self format printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #offset put: self offset;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> binding [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_BINDING
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> binding: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_BINDING put: anObject
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> format [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_FORMAT
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> format: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_FORMAT put: anObject
]

{ #category : 'inspector' }
VkVertexInputAttributeDescription >> inspectorAttribute: aBuilder [
	"What this description says about one attribute, rather than where its four fields sit: the
	 Layout and Fields tabs answer that. The rows come from attributeRows, which only reads, so
	 opening the tab changes nothing."

	<inspectorPresentationOrder: 30 title: 'Attribute'>
	| rows |
	rows := self attributeRows.
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Describes' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Shader location'. (rows at: #location) }.
				  { 'Read from binding'. (rows at: #binding) }.
				  { 'Format'. (rows at: #formatName) }.
				  { 'Byte offset in the vertex'. (rows at: #offset) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> location [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LOCATION
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> location: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LOCATION put: anObject
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> offset [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_OFFSET
]

{ #category : 'accessing - structure variables' }
VkVertexInputAttributeDescription >> offset: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_OFFSET put: anObject
]
