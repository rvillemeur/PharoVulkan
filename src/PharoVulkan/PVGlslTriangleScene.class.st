"
Second triangle example. Overrides buildVertexShader and buildFragmentShader to use PVKernelCompiler instead of the hand-written SPIR-V in PVHelloTriangleScene. Vertex shader normalizes colors; fragment shader blends 50% toward white. Entry point: PVGlslTriangleScene renderTriangle.
"
Class {
	#name : 'PVGlslTriangleScene',
	#superclass : 'PVHelloTriangleScene',
	#category : 'PharoVulkan-Example',
	#package : 'PharoVulkan',
	#tag : 'Example'
}

{ #category : 'examples' }
PVGlslTriangleScene class >> renderTriangle [
	<sampleInstance>
	| attrs win backendWin ctx scene |
	PVVulkanDriver install.
	attrs := PVWindowAttributes newVulkan.
	attrs title: 'GLSL Triangle'; extent: 800 @ 600; windowCentered: true.
	win := OSWindow createWithAttributes: attrs.
	backendWin := win backendWindow.
	ctx := VkContext graphicsContextForExtensions: backendWin requiredInstanceExtensions.
	scene := self prepare: ctx backendWindow: backendWin.
	1 to: 300 do: [ :i | scene renderFrame ].
	ctx computeQueue waitIdle.
	scene destroy.
	ctx destroy.
	win destroy.
	PVVulkanDriver uninstall.
	^ scene
]

{ #category : 'private' }
PVGlslTriangleScene >> buildFragmentShader [
	^ PVKernelCompiler compile: (PVKernelExamples >> #glslTriFragment:)
]

{ #category : 'private' }
PVGlslTriangleScene >> buildVertexShader [
	^ PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:)
]
