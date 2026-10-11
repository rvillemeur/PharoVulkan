"
The hello triangle rendered into a `PVOffscreenTarget` instead of a window, so the picture can be asserted pixel by pixel. It drives the same construction `PVHelloTriangleScene` drives — the same shaders, vertex data, pipeline and draw sequence, inherited from `PVTriangleScene` — because a separate offscreen copy of that setup would prove only that the copy works.

Build one with `on:extent:`, send `renderOnce`, then ask `pixelAtX:y:`. The target owns the render pass the pipeline is built against, so `destroyPresentation` releases the target and leaves the inherited render pass slot alone.
"
Class {
	#name : 'PVOffscreenTriangleScene',
	#superclass : 'PVTriangleScene',
	#instVars : [
		'target'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'constants' }
PVOffscreenTriangleScene class >> clearedChannelCeiling [
	"A cleared pixel of a black clear colour reads exactly zero on this driver. The ceiling
	 leaves room for a clear colour that rounds up by a unit, without letting a pixel that
	 carries any visible colour pass as cleared."

	^ 8
]

{ #category : 'constants' }
PVOffscreenTriangleScene class >> dominanceRatio [
	"How far above the other two channels a channel must be before the pixel counts as that
	 colour. Measured near a vertex: 203 against 28 and 24, so the factor has wide margin."

	^ 2
]

{ #category : 'testing' }
PVOffscreenTriangleScene class >> dominantChannelOf: aPixel [
	^ self dominantChannelOfColour: (aPixel first: 3)
]

{ #category : 'testing' }
PVOffscreenTriangleScene class >> dominantChannelOfColour: aColour [
	"Answer #red, #green or #blue when one channel of the three stands out by at least
	 dominanceRatio, and nil when none does. The rule is a ratio, so it reads a pixel's bytes
	 and a vertex's 0.0 to 1.0 floats alike, and the tests can compare the two."

	| names strongest index |
	names := #( #red #green #blue ).
	strongest := aColour inject: aColour first into: [ :best :each |
		             best max: each ].
	strongest > 0 ifFalse: [ ^ nil ].
	index := aColour indexOf: strongest.
	^ ((1 to: names size) allSatisfy: [ :other |
		   other = index or: [
			   strongest >= ((aColour at: other) * self dominanceRatio) ] ])
		  ifTrue: [ names at: index ]
		  ifFalse: [ nil ]
]

{ #category : 'constants' }
PVOffscreenTriangleScene class >> exampleExtent [
	"Big enough that a probe a quarter of the way in from a vertex lands two pixels clear of
	 the edge, small enough that reading every pixel in a test stays quick."

	^ 32 @ 32
]

{ #category : 'examples' }
PVOffscreenTriangleScene class >> exampleRenderedTriangleOnThisMachine [
	"One click: the hello triangle drawn once on whatever device this machine offers, with
	 every Vulkan object released before the scene is handed back. The pixels the GPU wrote
	 stay in the instance, so the Expected versus measured tab works on the result."

	<sampleInstance>
	| context scene |
	context := VkContext offscreenGraphicsContext.
	^ [
	  scene := self on: context extent: self exampleExtent.
	  scene renderOnce.
	  scene destroy.
	  scene ] ensure: [ context destroy ]
]

{ #category : 'constants' }
PVOffscreenTriangleScene class >> fullChannel [
	"What an 8-bit unsigned normalised channel reads at 1.0."

	^ 255
]

{ #category : 'testing' }
PVOffscreenTriangleScene class >> isCleared: aPixel [
	"True when the pixel carries no colour, so nothing was drawn over the clear."

	^ (aPixel first: 3) allSatisfy: [ :channel |
		  channel <= self clearedChannelCeiling ]
]

{ #category : 'testing' }
PVOffscreenTriangleScene class >> isEvenlyMixed: aPixel [
	"True when all three channels carry colour and none of them dominates, which is what
	 barycentric interpolation of three different vertex colours gives at the centroid."

	^ ((aPixel first: 3) allSatisfy: [ :channel |
		   channel >= self mixedChannelFloor ]) and: [
		  (self dominantChannelOf: aPixel) isNil ]
]

{ #category : 'testing' }
PVOffscreenTriangleScene class >> isOpaque: aPixel [
	^ (aPixel at: 4) = self opaqueAlpha
]

{ #category : 'constants' }
PVOffscreenTriangleScene class >> mixedChannelFloor [
	"How much of each channel an evenly mixed pixel must carry. The centroid measured 76, 92
	 and 88 of 255, so a third of full brightness each; the floor sits well below that and
	 still excludes a pixel showing one pure vertex colour."

	^ 32
]

{ #category : 'instance creation' }
PVOffscreenTriangleScene class >> on: aVkContext extent: aPoint [
	"Answer a prepared scene, guarded the way prepare:backendWindow: is: a raise part-way
	 through initialisation would strand the Vulkan objects already created on an instance no
	 caller ever receives."

	| scene |
	scene := self new.
	[ scene initializeCtx: aVkContext extent: aPoint ] ifCurtailed: [
		scene destroy ].
	^ scene
]

{ #category : 'constants' }
PVOffscreenTriangleScene class >> opaqueAlpha [
	^ self fullChannel
]

{ #category : 'constants' }
PVOffscreenTriangleScene class >> vertexProbeFraction [
	"How far from a vertex towards the centroid to probe. The vertex's own pixel lies on the
	 triangle's edge, where the rasteriser's fill rule may leave it cleared, so asking for the
	 colour there proves nothing; a quarter of the way in is unambiguously inside and still
	 close enough that one vertex colour dominates."

	^ 0.25
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> centroidPixel [
	^ self pixelAtPosition: self centroidPosition
]

{ #category : 'geometry' }
PVOffscreenTriangleScene >> cornerCoordinates [
	"The four corners of the render, which this triangle never reaches."

	| last |
	last := target extent - (1 @ 1).
	^ {
		  (0 @ 0).
		  (last x @ 0).
		  (0 @ last y).
		  last }
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> cornerPixels [
	^ self cornerCoordinates collect: [ :corner | self pixelAt: corner ]
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> coveredPixelCoordinates [
	"The coordinates of every pixel the draw reached, which is the shape of the picture
	 without its colours. Two renders that cover the same pixels rasterised the same triangle."

	| found |
	found := OrderedCollection new.
	self pixelsDo: [ :pixel :coordinate |
		(self class isCleared: pixel) ifFalse: [ found add: coordinate ] ].
	^ found asArray
]

{ #category : 'releasing' }
PVOffscreenTriangleScene >> destroyPresentation [
	"The target created the render pass the pipeline was built against, so it releases it, and
	 the inherited slot is cleared first or destroy would reach a pass already destroyed. The
	 target itself is kept: its Vulkan objects are gone but the pixels it read back survive, so
	 the comparison view still works on a destroyed scene, which is what the example answers."

	renderPass := nil.
	target ifNotNil: [ target destroy ]
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> dominantChannelNearVertex: anIndex [
	"Which of the three colours the render actually shows near one vertex. Compare it with the
	 colour the vertex data gives that vertex: if they agree, the picture has the orientation
	 the data asks for."

	^ self class dominantChannelOf: (self pixelNearVertex: anIndex)
]

{ #category : 'initialization' }
PVOffscreenTriangleScene >> initializeCtx: aVkContext extent: aPoint [
	"The target builds the render pass, because the pass has to end in the layout the copy
	 out of the image reads from. Everything else is the shared construction."

	target := PVOffscreenTarget on: aVkContext device extent: aPoint.
	self
		initializeCtx: aVkContext
		renderPass: target renderPass
		extent: aPoint
]

{ #category : 'inspector' }
PVOffscreenTriangleScene >> inspectorExpectedVersusMeasured: aBuilder [
	"Every row reads the kept readback bytes through pixelAt:, and asks the same class-side
	 predicate the matching test asserts with, so the verdict column cannot disagree with the
	 suite. Nothing is submitted and no pixel is written, so opening the inspector cannot
	 change what is inspected."

	<inspectorPresentationOrder: 10 title: 'Expected versus measured'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Point'
				   evaluated: [ :rule | rule first printString ]);
		  addColumn: (SpStringTableColumn title: 'R G B A' evaluated: [ :rule |
					   ((self pixelAt: rule first) collect: [ :channel |
						    channel printString ]) inject: '' into: [ :acc :channel |
						   acc isEmpty
							   ifTrue: [ channel ]
							   ifFalse: [ acc , ' ' , channel ] ] ]);
		  addColumn: (SpStringTableColumn
				   title: 'Rule'
				   evaluated: [ :rule | rule second ]);
		  addColumn: (SpStringTableColumn title: 'Verdict' evaluated: [ :rule |
					   (rule third value: (self pixelAt: rule first))
						   ifTrue: [ 'pass' ]
						   ifFalse: [ 'fail' ] ]);
		  items: self pixelRules;
		  yourself
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> nonOpaquePixelCoordinates [
	"The coordinates of every pixel that is not fully opaque, so a failing test can name them
	 rather than only report a count."

	| found |
	found := OrderedCollection new.
	self pixelsDo: [ :pixel :coordinate |
		(self class isOpaque: pixel) ifFalse: [ found add: coordinate ] ].
	^ found asArray
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> pixelAt: aPoint [
	^ self pixelAtX: aPoint x y: aPoint y
]

{ #category : 'geometry' }
PVOffscreenTriangleScene >> pixelAtPosition: aPosition [
	^ self pixelAt: (self pixelCoordinateOfPosition: aPosition)
]

{ #category : 'accessing' }
PVOffscreenTriangleScene >> pixelAtX: x y: y [
	^ target pixelAtX: x y: y
]

{ #category : 'geometry' }
PVOffscreenTriangleScene >> pixelCoordinateOfPosition: aPosition [
	"The pixel a clip space position falls in. Clip space runs from -1 to 1 across the whole
	 target in both axes, with y pointing down, so the arithmetic is the same for both. A
	 position on the far edge would index one past the last pixel, so the result is clamped."

	| sizes coordinates |
	sizes := {
		         target extent x.
		         target extent y }.
	coordinates := (1 to: 2) collect: [ :axis |
		               | size |
		               size := sizes at: axis.
		               ((((aPosition at: axis) + 1) / 2 * size) floor max: 0) min:
			               size - 1 ].
	^ coordinates first @ coordinates second
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> pixelNearVertex: anIndex [
	^ self pixelAtPosition: (self probePositionNearVertex: anIndex)
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> pixelRules [
	"One entry per sampled point: its coordinates, the rule the render must satisfy there, and
	 a block that asks that rule of a pixel. The pixel tests assert the same rules through the
	 same class-side predicates, so a view built from this cannot claim a verdict the suite
	 would not reach. The colour expected near a vertex is read out of the vertex data, not
	 restated here."

	| rules |
	rules := OrderedCollection new.
	self cornerCoordinates do: [ :corner |
		rules add: {
				corner.
				'cleared'.
				[ :pixel | self class isCleared: pixel ] } ].
	rules add: {
			(self pixelCoordinateOfPosition: self centroidPosition).
			'all three vertex colours, none dominant'.
			[ :pixel | self class isEvenlyMixed: pixel ] }.
	1 to: self class vertexCount do: [ :vertex |
		| colour |
		colour := self class dominantChannelOfColour:
			          (self vertexColourAt: vertex).
		rules add: {
				(self pixelCoordinateOfPosition:
					 (self probePositionNearVertex: vertex)).
				'dominated by ' , colour.
				[ :pixel | (self class dominantChannelOf: pixel) = colour ] } ].
	^ rules asArray
]

{ #category : 'measuring' }
PVOffscreenTriangleScene >> pixelsDo: aBlock [
	"Evaluate the block with every pixel of the render and its coordinates, row by row."

	0 to: target extent y - 1 do: [ :y |
		0 to: target extent x - 1 do: [ :x |
			aBlock
				value: (self pixelAtX: x y: y)
				value: x @ y ] ]
]

{ #category : 'geometry' }
PVOffscreenTriangleScene >> probePositionNearVertex: anIndex [
	"A clip space position vertexProbeFraction of the way from one vertex towards the
	 centroid, which is inside the triangle for any triangle and close to that one vertex."

	| vertex centroid fraction |
	vertex := self vertexPositionAt: anIndex.
	centroid := self centroidPosition.
	fraction := self class vertexProbeFraction.
	^ (1 to: 2) collect: [ :axis |
		  (vertex at: axis) + (((centroid at: axis) - (vertex at: axis)) * fraction) ]
]

{ #category : 'rendering' }
PVOffscreenTriangleScene >> renderOnce [
	"Draw the triangle once and read the pixels back. The block records the same five
	 commands, in the same order, that PVHelloTriangleScene >> renderFrame records into a
	 swapchain framebuffer; if the two drift apart the pixel tests stop saying anything about
	 the window path, which is the only reason they are worth asserting."

	target
		renderWith: [ :c |
			c bindGraphicsPipeline: pipeline.
			c setViewport: target extent.
			c setScissor: target extent.
			c bindVertexBuffer: vertexBuffer.
			c draw: 3 ]
		on: ctx computeQueue
		pool: commandPool
]

{ #category : 'accessing' }
PVOffscreenTriangleScene >> target [
	^ target
]
