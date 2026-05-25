"
Top-level SPIR-V module. Owns all sections in the required emission order:
capabilities, extensions, ext-inst-sets, memory model, entry points, execution modes,
annotations, types/constants/globals, functions.
Create via SpvModule new. Serialize via SpvSerializer serialize:.
Key methods: newId, addCapability:, addFunction:, addEntryPoint:executionModel:name:interfaces:,
typeRegistry, constantPool, serialize.
"
Class {
	#name : 'SpvModule',
	#superclass : 'Object',
	#instVars : [
		'nextId',
		'capabilities',
		'extensions',
		'extInstSets',
		'addressingModel',
		'memoryModel',
		'entryPoints',
		'executionModes',
		'decorations',
		'typeRegistry',
		'constantPool',
		'globalVariables',
		'functions'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'building' }
SpvModule >> addCapability: aSymbol [
    (capabilities includes: aSymbol) ifFalse: [ capabilities add: aSymbol ]
]

{ #category : 'building' }
SpvModule >> addDecoration: anId decoration: decorationInt literals: anArray [
    decorations add: {#decorate. anId. decorationInt. anArray}
]

{ #category : 'building' }
SpvModule >> addEntryPoint: anSpvFunction executionModel: modelInt name: aString interfaces: anArray [
    entryPoints add: {anSpvFunction. modelInt. aString. anArray}
]

{ #category : 'building' }
SpvModule >> addExecutionMode: anSpvFunction mode: modeInt literals: anArray [
    executionModes add: {anSpvFunction. modeInt. anArray}
]

{ #category : 'building' }
SpvModule >> addExtension: aString [
    (extensions includes: aString) ifFalse: [ extensions add: aString ]
]

{ #category : 'building' }
SpvModule >> addFunction: anSpvFunction [
    functions add: anSpvFunction
]

{ #category : 'building' }
SpvModule >> addGlobalVariable: anSpvGlobalVariable [
    globalVariables add: anSpvGlobalVariable
]

{ #category : 'building' }
SpvModule >> addMemberDecoration: aStructId member: memberIdx decoration: decorationInt literals: anArray [
    decorations add: {#memberDecorate. aStructId. memberIdx. decorationInt. anArray}
]

{ #category : 'accessing' }
SpvModule >> addressingModel [ ^ addressingModel
]

{ #category : 'accessing' }
SpvModule >> bound [ ^ nextId
]

{ #category : 'accessing' }
SpvModule >> capabilities [    ^ capabilities
]

{ #category : 'accessing' }
SpvModule >> constantPool [    ^ constantPool
]

{ #category : 'accessing' }
SpvModule >> decorations [     ^ decorations
]

{ #category : 'accessing' }
SpvModule >> entryPoints [     ^ entryPoints
]

{ #category : 'accessing' }
SpvModule >> executionModes [  ^ executionModes
]

{ #category : 'accessing' }
SpvModule >> extInstSets [     ^ extInstSets
]

{ #category : 'accessing' }
SpvModule >> extensions [      ^ extensions
]

{ #category : 'accessing' }
SpvModule >> functions [       ^ functions
]

{ #category : 'accessing' }
SpvModule >> globalVariables [ ^ globalVariables
]

{ #category : 'building' }
SpvModule >> importExtInstSet: aName [
	"Import an extended instruction set (e.g. GLSL.std.450). Returns its result id."

	^ extInstSets at: aName ifAbsentPut: [
			  | id |
			  id := self newId.
			  id ]
]

{ #category : 'initialization' }
SpvModule >> initialize [

	super initialize.
	nextId := 1.
	capabilities := OrderedCollection new.
	extensions := OrderedCollection new.
	extInstSets := Dictionary new.
	addressingModel := 0. "Logical"
	memoryModel := 1. "GLSL450"
	entryPoints := OrderedCollection new.
	executionModes := OrderedCollection new.
	decorations := OrderedCollection new.
	globalVariables := OrderedCollection new.
	functions := OrderedCollection new.
	typeRegistry := SpvTypeRegistry on: self.
	constantPool := SpvConstantPool on: self
]

{ #category : 'accessing' }
SpvModule >> memoryModel [     ^ memoryModel
]

{ #category : 'id-allocation' }
SpvModule >> newId [
    "Allocate and return the next fresh SPIR-V result id."
    | id |
    id := nextId.
    nextId := nextId + 1.
    ^ id
]

{ #category : 'serialization' }
SpvModule >> serialize [
    ^ SpvSerializer serialize: self
]

{ #category : 'building' }
SpvModule >> setAddressingModel: addrModel memoryModel: memModel [
    addressingModel := addrModel.
    memoryModel := memModel
]

{ #category : 'accessing' }
SpvModule >> typeRegistry [    ^ typeRegistry
]
