"
The region of a framebuffer the rasteriser maps clip space onto, and the depth range it maps z into. Six floats at four byte stride: the origin, the size and the near and far planes. The project records one viewport covering the whole target at the full depth range, built by VkCommandBuffer class >> viewportForExtent:. Key methods: viewportRows, which the Viewport tab reads, and the inherited layoutRows.
"
Class {
	#name : 'VkViewport',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_HEIGHT',
		'OFFSET_MAXDEPTH',
		'OFFSET_MINDEPTH',
		'OFFSET_WIDTH',
		'OFFSET_X',
		'OFFSET_Y'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkViewport class >> fieldsDesc [
	^ #( float x; float y; float width; float height; float minDepth;
	     float maxDepth )
]

{ #category : 'accessing - structure variables' }
VkViewport >> height [
	"This method was automatically generated"
	^handle floatAt: OFFSET_HEIGHT
]

{ #category : 'accessing - structure variables' }
VkViewport >> height: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_HEIGHT put: anObject
]

{ #category : 'inspector' }
VkViewport >> inspectorViewport: aBuilder [
	"What this viewport maps clip space onto: its origin, its size, whether it starts at the
	 target's own origin, and the depth range it maps z into. The rows are read back through
	 the accessors, so opening the tab cannot change the viewport."

	<inspectorPresentationOrder: 30 title: 'Viewport'>
	| rows |
	rows := self viewportRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Origin'. (rows at: #origin) }.
				  { 'At the target origin'. (rows at: #atTheOrigin) }.
				  { 'Extent'. (rows at: #extent) }.
				  { 'Depth range'. (rows at: #depthRange) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkViewport >> maxDepth [
	"This method was automatically generated"
	^handle floatAt: OFFSET_MAXDEPTH
]

{ #category : 'accessing - structure variables' }
VkViewport >> maxDepth: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_MAXDEPTH put: anObject
]

{ #category : 'accessing - structure variables' }
VkViewport >> minDepth [
	"This method was automatically generated"
	^handle floatAt: OFFSET_MINDEPTH
]

{ #category : 'accessing - structure variables' }
VkViewport >> minDepth: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_MINDEPTH put: anObject
]

{ #category : 'reporting' }
VkViewport >> viewportRows [
	"What this viewport maps clip space onto, read back off the structure's own fields: the
	 origin, the size, whether the origin is the target's own, and the depth range as the pair
	 the rasteriser maps z into. Fresh rows over copied values, so a view built from these
	 cannot reach the structure."

	^ Dictionary new
		  at: #origin put: self x @ self y;
		  at: #extent put: self width @ self height;
		  at: #atTheOrigin put: (self x = 0.0 and: [ self y = 0.0 ]);
		  at: #depthRange put: self minDepth -> self maxDepth;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkViewport >> width [
	"This method was automatically generated"
	^handle floatAt: OFFSET_WIDTH
]

{ #category : 'accessing - structure variables' }
VkViewport >> width: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_WIDTH put: anObject
]

{ #category : 'accessing - structure variables' }
VkViewport >> x [
	"This method was automatically generated"
	^handle floatAt: OFFSET_X
]

{ #category : 'accessing - structure variables' }
VkViewport >> x: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_X put: anObject
]

{ #category : 'accessing - structure variables' }
VkViewport >> y [
	"This method was automatically generated"
	^handle floatAt: OFFSET_Y
]

{ #category : 'accessing - structure variables' }
VkViewport >> y: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_Y put: anObject
]
