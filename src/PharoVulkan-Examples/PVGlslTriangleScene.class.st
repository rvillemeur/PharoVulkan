"
Second triangle example. Overrides buildVertexShader and buildFragmentShader to use PVKernelCompiler instead of the hand-written SPIR-V in PVHelloTriangleScene. Vertex shader normalizes colors; fragment shader blends 50% toward white. Entry point: PVGlslTriangleScene renderTriangle.
"
Class {
	#name : 'PVGlslTriangleScene',
	#superclass : 'PVHelloTriangleScene',
	#category : 'PharoVulkan-Examples-Graphics',
	#package : 'PharoVulkan-Examples',
	#tag : 'Graphics'
}

{ #category : 'examples' }
PVGlslTriangleScene class >> renderTriangle [
	"Same lifecycle as the superclass; redefined only so the example button shows up
	 on this class too, since the sampleInstance pragma is not looked up in
	 superclasses. windowTitle supplies the only difference."

	<sampleInstance>
	^ super renderTriangle
]

{ #category : 'constants' }
PVGlslTriangleScene class >> windowTitle [
	^ 'GLSL Triangle'
]

{ #category : 'private' }
PVGlslTriangleScene >> buildFragmentShader [
	^ PVGlslTriangleShaders fragmentShaderBytes
]

{ #category : 'private' }
PVGlslTriangleScene >> buildVertexShader [
	^ PVGlslTriangleShaders vertexShaderBytes
]
