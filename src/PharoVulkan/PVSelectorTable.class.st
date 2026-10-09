"
Dispatch table mapping Pharo message sends to SPIR-V operations. Covers i32, u32, f32 and f16 arithmetic (+, -, *, /, //, \\, <, <=), vector and mat4 operations, the GLSL.std.450 calls, work item queries and buffer indexing. Half precision reuses the float instructions and differs only in result type. Used by PVTypeInferencer at stage 6.
"
Class {
	#name : 'PVSelectorTable',
	#superclass : 'Object',
	#instVars : [
		'table'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'factory' }
PVSelectorTable class >> standard [ ^ self new initializeStandardMappings; initializeVecMappings; initializeGLSLMappings; yourself
]

{ #category : 'lookup' }
PVSelectorTable >> at: selector receiverType: recvType [
	^ table at: selector , ':' , recvType asString ifAbsent: [ nil ]
]

{ #category : 'lookup' }
PVSelectorTable >> at: selector receiverType: recvType ifAbsent: aBlock [
    ^ table at: selector , ':' , recvType asString ifAbsent: aBlock
]

{ #category : 'private' }
PVSelectorTable >> at: selector receiverType: recvType put: mapping [
	table at: selector , ':' , recvType asString put: mapping
]

{ #category : 'initialization' }
PVSelectorTable >> initialize [

	super initialize.
	table := Dictionary new
]

{ #category : 'private' }
PVSelectorTable >> initializeBufferMappings [
self at: 'at:' receiverType: #bufferOf_f32 put: (PVSelectorMapping spirvOp: #bufferLoad resultType: #f32).
self at: 'at:' receiverType: #bufferOf_i32 put: (PVSelectorMapping spirvOp: #bufferLoad resultType: #i32).
self at: 'at:put:' receiverType: #bufferOf_f32 put: (PVSelectorMapping spirvOp: #bufferStore resultType: #void).
self at: 'at:put:' receiverType: #bufferOf_i32 put: (PVSelectorMapping spirvOp: #bufferStore resultType: #void)
]

{ #category : 'private' }
PVSelectorTable >> initializeGLSLMappings [
self at: 'normalize' receiverType: #vec3 put: (PVSelectorMapping spirvOp: #glslNormalize resultType: #vec3).
self at: 'length' receiverType: #vec3 put: (PVSelectorMapping spirvOp: #glslLength resultType: #f32).
self at: 'mix:factor:' receiverType: #vec3 put: (PVSelectorMapping spirvOp: #glslFMix resultType: #vec3).
self at: 'clamp:to:' receiverType: #f32 put: (PVSelectorMapping spirvOp: #glslFClamp resultType: #f32).
self at: 'sqrt' receiverType: #f32 put: (PVSelectorMapping spirvOp: #glslSqrt resultType: #f32)
]

{ #category : 'private' }
PVSelectorTable >> initializeHalfMappings [
	"Half precision arithmetic uses the same instructions as single precision, so only the
	 result type differs; a comparison answers a bool at either width."

	self at: '+' receiverType: #f16 put: (PVSelectorMapping spirvOp: #OpFAdd resultType: #f16).
	self at: '-' receiverType: #f16 put: (PVSelectorMapping spirvOp: #OpFSub resultType: #f16).
	self at: '*' receiverType: #f16 put: (PVSelectorMapping spirvOp: #OpFMul resultType: #f16).
	self at: '/' receiverType: #f16 put: (PVSelectorMapping spirvOp: #OpFDiv resultType: #f16).
	self at: '<' receiverType: #f16 put: (PVSelectorMapping spirvOp: #OpFOrdLessThan resultType: #bool).
	self at: '<=' receiverType: #f16 put: (PVSelectorMapping spirvOp: #OpFOrdLessThanEqual resultType: #bool).
	self at: 'at:' receiverType: #bufferOf_f16 put: (PVSelectorMapping spirvOp: #bufferLoad resultType: #f16).
	self at: 'at:put:' receiverType: #bufferOf_f16 put: (PVSelectorMapping spirvOp: #bufferStore resultType: #void)
]

{ #category : 'private' }
PVSelectorTable >> initializeScalarMappings [
self at: '+' receiverType: #f32 put: (PVSelectorMapping spirvOp: #OpFAdd resultType: #f32).
self at: '-' receiverType: #f32 put: (PVSelectorMapping spirvOp: #OpFSub resultType: #f32).
self at: '*' receiverType: #f32 put: (PVSelectorMapping spirvOp: #OpFMul resultType: #f32).
self at: '/' receiverType: #f32 put: (PVSelectorMapping spirvOp: #OpFDiv resultType: #f32).
self at: '<' receiverType: #f32 put: (PVSelectorMapping spirvOp: #OpFOrdLessThan resultType: #bool).
self at: '<=' receiverType: #f32 put: (PVSelectorMapping spirvOp: #OpFOrdLessThanEqual resultType: #bool).
self at: '+' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpIAdd resultType: #i32).
self at: '-' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpISub resultType: #i32).
self at: '*' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpIMul resultType: #i32).
self at: '//' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpSDiv resultType: #i32).
self at: '\\' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpSMod resultType: #i32).
self at: '<' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpSLessThan resultType: #bool).
self at: '<=' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpSLessThanEqual resultType: #bool).
self at: '+' receiverType: #u32 put: (PVSelectorMapping spirvOp: #OpIAdd resultType: #u32).
self at: '*' receiverType: #u32 put: (PVSelectorMapping spirvOp: #OpIMul resultType: #u32)
]

{ #category : 'private' }
PVSelectorTable >> initializeStandardMappings [
	self initializeScalarMappings.
	self initializeWorkItemMappings.
	self initializeBufferMappings.
	self initializeHalfMappings
]

{ #category : 'initialization' }
PVSelectorTable >> initializeVecMappings [
    "Component-wise arithmetic on vec types"
    #(#vec2 #vec3 #vec4) do: [:t |
        self at: '+' receiverType: t put: (PVSelectorMapping spirvOp: #OpFAdd resultType: t).
        self at: '-' receiverType: t put: (PVSelectorMapping spirvOp: #OpFSub resultType: t).
        self at: '*' receiverType: t put: (PVSelectorMapping spirvOp: #OpFMul resultType: t)].
    "Composite construction via , chaining"
    self at: ',' receiverType: #f32  put: (PVSelectorMapping spirvOp: #compositeConstruct resultType: #vec2).
    self at: ',' receiverType: #vec2 put: (PVSelectorMapping spirvOp: #compositeConstruct resultType: #vec3).
    self at: ',' receiverType: #vec3 put: (PVSelectorMapping spirvOp: #compositeConstruct resultType: #vec4).
    "Component extraction x/y/z/w"
    #(#vec2 #vec3 #vec4) do: [:t |
        self at: 'x' receiverType: t put: (PVSelectorMapping spirvOp: #vecExtractX resultType: #f32).
        self at: 'y' receiverType: t put: (PVSelectorMapping spirvOp: #vecExtractY resultType: #f32)].
    #(#vec3 #vec4) do: [:t |
        self at: 'z' receiverType: t put: (PVSelectorMapping spirvOp: #vecExtractZ resultType: #f32)].
    self at: 'w' receiverType: #vec4 put: (PVSelectorMapping spirvOp: #vecExtractW resultType: #f32).
    "Mat4 * vec4"
    self at: '*' receiverType: #mat4 put: (PVSelectorMapping spirvOp: #OpMatrixTimesVector resultType: #vec4).
    "Dot product"
    self at: 'dot:' receiverType: #vec3 put: (PVSelectorMapping spirvOp: #OpDot resultType: #f32)
]

{ #category : 'private' }
PVSelectorTable >> initializeWorkItemMappings [
self at: 'x' receiverType: #workItem put: (PVSelectorMapping spirvOp: #workItemX resultType: #u32).
self at: 'y' receiverType: #workItem put: (PVSelectorMapping spirvOp: #workItemY resultType: #u32).
self at: 'z' receiverType: #workItem put: (PVSelectorMapping spirvOp: #workItemZ resultType: #u32).
"gridWidth is dispatch geometry, not an invocation index: groupCountX times localSizeX."
self at: 'gridWidth' receiverType: #workItem put: (PVSelectorMapping spirvOp: #workItemGridWidth resultType: #u32)
]

{ #category : 'accessing' }
PVSelectorTable >> table [
^ table
]
