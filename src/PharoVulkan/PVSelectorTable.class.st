"
Dispatch table mapping Pharo message sends to SPIR-V operations. Covers i32 and f32 arithmetic (+, -, *, //, \\, <, <=) and comparison ops. Used by PVTypeInferencer at stage 6.
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

{ #category : 'instance creation' }
PVSelectorTable class >> standard [
	^ self new initializeStandardMappings; yourself
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
PVSelectorTable >> initializeStandardMappings [
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
	self at: '\\\\' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpSMod resultType: #i32).
	self at: '<' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpSLessThan resultType: #bool).
	self at: '<=' receiverType: #i32 put: (PVSelectorMapping spirvOp: #OpSLessThanEqual resultType: #bool).
	self at: '+' receiverType: #u32 put: (PVSelectorMapping spirvOp: #OpIAdd resultType: #u32).
	self at: '*' receiverType: #u32 put: (PVSelectorMapping spirvOp: #OpIMul resultType: #u32)
]

{ #category : 'accessing' }
PVSelectorTable >> table [
^ table
]
