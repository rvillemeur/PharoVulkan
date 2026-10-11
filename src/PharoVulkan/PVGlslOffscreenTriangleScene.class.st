"
The offscreen triangle drawn with the DSL-written shaders of `PVGlslTriangleShaders` instead of the hand-built SPIR-V. Everything else — vertex data, pipeline, draw sequence, readback — is inherited from `PVOffscreenTriangleScene`, so a difference between the two renders can only come from the shaders.

That comparison is the point of the class: it turns the DSL's claim from ""emits SPIR-V the validator accepts"" into ""draws the same picture"".
"
Class {
	#name : 'PVGlslOffscreenTriangleScene',
	#superclass : 'PVOffscreenTriangleScene',
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'testing' }
PVGlslOffscreenTriangleScene class >> channel: aMeasuredChannel matchesMixOf: aHandBuiltChannel [
	^ (aMeasuredChannel - (self channelExpectedFromHandBuilt: aHandBuiltChannel))
		  abs <= self comparisonTolerance
]

{ #category : 'testing' }
PVGlslOffscreenTriangleScene class >> channelExpectedFromHandBuilt: aChannel [
	"What a channel of this render must read where the hand-built render reads aChannel. The
	 DSL vertex shader normalises each vertex colour, which leaves the three pure vertex
	 colours of the triangle unchanged, and the fragment shader mixes white in, so the whole
	 difference between the two pictures is that one mix."

	^ aChannel
	  + ((self fullChannel - aChannel) * PVGlslTriangleShaders whiteMixFactor)
]

{ #category : 'constants' }
PVGlslOffscreenTriangleScene class >> comparisonTolerance [
	"One channel step. The two renders are produced by different shaders, so a channel can
	 land either side of the half-way point by a rounding unit; measured, the difference was
	 never more than one."

	^ 1
]

{ #category : 'private' }
PVGlslOffscreenTriangleScene >> buildFragmentShader [
	^ PVGlslTriangleShaders fragmentShaderBytes
]

{ #category : 'private' }
PVGlslOffscreenTriangleScene >> buildVertexShader [
	^ PVGlslTriangleShaders vertexShaderBytes
]
