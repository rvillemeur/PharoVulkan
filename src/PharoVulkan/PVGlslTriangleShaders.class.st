"
The one place the hello triangle's DSL-written shaders are named. `vertexShaderBytes` and `fragmentShaderBytes` compile the `PVKernelExamples` methods that stand in for the GLSL vertex and fragment shaders of the usual hello-triangle tutorial.

Two scenes draw with them — `PVGlslTriangleScene` into a window and `PVGlslOffscreenTriangleScene` into a readable target — and both delegate here, so the picture the pixel tests check is compiled from the same source as the picture the window shows.
"
Class {
	#name : 'PVGlslTriangleShaders',
	#superclass : 'Object',
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'compiling' }
PVGlslTriangleShaders class >> fragmentShaderBytes [
	^ PVKernelCompiler compile: (PVKernelExamples >> #glslTriFragment:)
]

{ #category : 'compiling' }
PVGlslTriangleShaders class >> vertexShaderBytes [
	^ PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:)
]

{ #category : 'constants' }
PVGlslTriangleShaders class >> whiteMixFactor [
	"How much white the fragment shader mixes into the interpolated vertex colour. It is the
	 factor PVKernelExamples >> glslTriFragment: passes to mix:factor:, and
	 PVGraphicsTest >> testGlslWhiteMixFactorIsTheOneItsShaderSourceUses ties this constant to
	 that literal, so the pixel comparison cannot keep claiming a mix the shader stopped doing."

	^ 0.5
]
