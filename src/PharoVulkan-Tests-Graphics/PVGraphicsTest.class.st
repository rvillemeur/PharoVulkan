"
SUnit test suite for the graphics path. Verifies shader SPIR-V construction (buildVertexShader, buildFragmentShader) and vertex data layout. Integration rendering is exercised via PVHelloTriangleScene.
"
Class {
	#name : 'PVGraphicsTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Graphics',
	#package : 'PharoVulkan-Tests-Graphics'
}

{ #category : 'tests' }
PVGraphicsTest >> testFragmentShaderBuilds [
    | bytes |
    bytes := PVHelloTriangleScene new buildFragmentShader.
    self assert: (bytes isKindOf: ByteArray).
    self assert: bytes size > 20.
    self assert: (bytes at: 1) equals: 3.
    self assert: (bytes at: 2) equals: 2.
    self assert: (bytes at: 3) equals: 35.
    self assert: (bytes at: 4) equals: 7.
]

{ #category : 'tests' }
PVGraphicsTest >> testVertexDataSize [
    | data |
    data := PVHelloTriangleScene new buildVertexData.
    self assert: data size equals: 60.
]

{ #category : 'tests' }
PVGraphicsTest >> testVertexShaderBuilds [
    | bytes |
    bytes := PVHelloTriangleScene new buildVertexShader.
    self assert: (bytes isKindOf: ByteArray).
    self assert: bytes size > 20.
    self assert: (bytes at: 1) equals: 3.
    self assert: (bytes at: 2) equals: 2.
    self assert: (bytes at: 3) equals: 35.
    self assert: (bytes at: 4) equals: 7.
]
