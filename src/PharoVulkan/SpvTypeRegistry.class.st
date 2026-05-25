"
Deduplicates SPIR-V type declarations within a module. Every unique type maps to
exactly one result id. Request types via factory methods; existing types are reused.
Key methods: voidType, boolType, intType:signed:, floatType:, vectorType:count:,
pointerType:type:, functionType:paramTypes:, runtimeArrayType:, structType:.
"
Class {
	#name : 'SpvTypeRegistry',
	#superclass : 'Object',
	#instVars : [
		'module',
		'types'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'instance creation' }
SpvTypeRegistry class >> on: aModule [
    ^ self new module: aModule; yourself
]

{ #category : 'accessing' }
SpvTypeRegistry >> allTypes [
	"Sort by SPIR-V id — types are created after their dependencies, so id order = topological order."
	^ types values asSortedCollection: [:a :b | a id <= b id]
]

{ #category : 'type-factories' }
SpvTypeRegistry >> boolType [
    ^ types at: #bool ifAbsent: [ self register: SpvBoolType new ]
]

{ #category : 'type-factories' }
SpvTypeRegistry >> floatType: width [
    | key |
    key := Array with: #float with: width.
    ^ types at: key ifAbsent: [
        self register: (SpvFloatType new width: width; yourself) ]
]

{ #category : 'type-factories' }
SpvTypeRegistry >> functionType: aReturnType paramTypes: aParamArray [
    | key |
    key := Array with: #function with: aReturnType id with: (aParamArray collect: [:t | t id]).
    ^ types at: key ifAbsent: [
        self register: (SpvFunctionType new returnType: aReturnType; paramTypes: aParamArray; yourself) ]
]

{ #category : 'initialization' }
SpvTypeRegistry >> initialize [

	super initialize.
	types := Dictionary new
]

{ #category : 'type-factories' }
SpvTypeRegistry >> intType: width signed: isSigned [
    | key |
    key := Array with: #int with: width with: isSigned.
    ^ types at: key ifAbsent: [
        self register: (SpvIntType new width: width; signed: isSigned; yourself) ]
]

{ #category : 'accessing' }
SpvTypeRegistry >> module: m [  module := m
]

{ #category : 'type-factories' }
SpvTypeRegistry >> pointerType: storageClassInt type: aBaseType [
    | key |
    key := Array with: #pointer with: storageClassInt with: aBaseType id.
    ^ types at: key ifAbsent: [
        self register: (SpvPointerType new storageClass: storageClassInt; baseType: aBaseType; yourself) ]
]

{ #category : 'private' }
SpvTypeRegistry >> register: aSpvType [
    "Assign a fresh id to aSpvType, store it, and return it."
    aSpvType id: module newId.
    aSpvType module: module.
    types at: aSpvType key put: aSpvType.
    ^ aSpvType
]

{ #category : 'type-factories' }
SpvTypeRegistry >> runtimeArrayType: anElementType [
    | key |
    key := Array with: #runtimeArray with: anElementType id.
    ^ types at: key ifAbsent: [
        self register: (SpvRuntimeArrayType new elementType: anElementType; yourself) ]
]

{ #category : 'type-factories' }
SpvTypeRegistry >> structType: aMemberTypeArray [
    | key |
    key := Array with: #struct with: (aMemberTypeArray collect: [:t | t id]).
    ^ types at: key ifAbsent: [
        self register: (SpvStructType new memberTypes: aMemberTypeArray; yourself) ]
]

{ #category : 'private' }
SpvTypeRegistry >> typeForKey: aKey ifAbsent: aBlock [
    ^ types at: aKey ifAbsent: aBlock
]

{ #category : 'type-factories' }
SpvTypeRegistry >> vectorType: aComponentType count: n [
    | key |
    key := Array with: #vector with: aComponentType id with: n.
    ^ types at: key ifAbsent: [
        self register: (SpvVectorType new componentType: aComponentType; count: n; yourself) ]
]

{ #category : 'type-factories' }
SpvTypeRegistry >> voidType [
    ^ types at: #void ifAbsent: [ self register: SpvVoidType new ]
]
