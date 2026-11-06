"
One format and colour space pair a surface accepts, as vkGetPhysicalDeviceSurfaceFormatsKHR reports it: eight bytes, the format and the colour space. The driver fills a run of them, which VkSurface >> formats allocates through VkStructure class >> externalArrayOf: and answers as copies in object memory; VkSurface class >> formatPreferredFrom: picks the pair the swapchain is created with.

The driver is the only writer, so there is no chain header and no initializeConstantFields. formatRows is what the Format tab reads, and asks VkSurface whether this is the pair the project renders in rather than keeping a second copy of that preference.
"
Class {
	#name : 'VkSurfaceFormatKHR',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_COLORSPACE',
		'OFFSET_FORMAT'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkSurfaceFormatKHR class >> fieldsDesc [
	"One format and colour space pair the surface accepts. The format is the same
	 VkFormat enumeration an image is created with, so it is declared signed as there."

	^ #( int32 format; int32 colorSpace )
]

{ #category : 'accessing - structure variables' }
VkSurfaceFormatKHR >> colorSpace [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_COLORSPACE
]

{ #category : 'accessing - structure variables' }
VkSurfaceFormatKHR >> colorSpace: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_COLORSPACE put: anObject
]

{ #category : 'accessing - structure variables' }
VkSurfaceFormatKHR >> format [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_FORMAT
]

{ #category : 'accessing - structure variables' }
VkSurfaceFormatKHR >> format: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_FORMAT put: anObject
]

{ #category : 'accessing' }
VkSurfaceFormatKHR >> formatRows [
	"The pair this entry carries, named through the constant classes, and whether it is the
	 pair the project renders in — which is asked of the class that holds that choice rather
	 than compared against a second copy of the preference. A value no constant names is shown
	 as its number rather than dropped. Read only, so a view built from this leaves the store
	 alone."

	^ Dictionary new
		  at: #formatName
		  put: ((VkFormat nameForValue: self format)
				   ifNil: [ self format printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #colorSpaceName
		  put: ((VkColorSpace nameForValue: self colorSpace)
				   ifNil: [ self colorSpace printString ]
				   ifNotNil: [ :each | each asString ]);
		  at: #rendersThisProject put: self format = VkRenderConfig formatRenderedIn;
		  yourself
]

{ #category : 'inspector' }
VkSurfaceFormatKHR >> inspectorFormat: aBuilder [
	"What this entry offers, rather than where its two fields sit: the Layout and Fields tabs
	 answer that. The rows come from formatRows, which only reads, so opening the tab changes
	 nothing."

	<inspectorPresentationOrder: 30 title: 'Format'>
	| rows |
	rows := self formatRows.
	^ PVFactRow
		  tableOf: {
				  (PVFactRow name: 'Format' value: (rows at: #formatName)).
				  (PVFactRow
					   name: 'Colour space'
					   value: (rows at: #colorSpaceName)).
				  (PVFactRow
					   name: 'The format this project renders in'
					   value: (rows at: #rendersThisProject)) }
		  nameColumn: 'Offers'
		  valueColumn: 'Value'
		  in: aBuilder
]
