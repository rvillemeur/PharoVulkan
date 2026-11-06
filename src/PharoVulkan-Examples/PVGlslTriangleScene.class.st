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
