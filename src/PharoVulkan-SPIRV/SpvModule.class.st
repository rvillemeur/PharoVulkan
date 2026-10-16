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
	#category : 'PharoVulkan-SPIRV-Builder',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Builder'
}

{ #category : 'constants' }
SpvModule class >> glsl450MemoryModel [
	"Memory model GLSL450 = 1, the model a module uses unless it asks for another."

	^ 1
]

{ #category : 'constants' }
SpvModule class >> logicalAddressingModel [
	"Addressing model Logical = 0, the only one a Vulkan shader may use: no physical
	 pointer arithmetic."

	^ 0
]

{ #category : 'constants' }
SpvModule class >> vulkanMemoryModel [
	"Memory model Vulkan = 3. A module declaring the VulkanMemoryModel capability must name
	 this model, which is what a cooperative matrix module needs; the default GLSL450 = 1
	 serves every other kernel in this project."

	^ 3
]

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

{ #category : 'instructions' }
SpvModule >> workgroupBarrierInstruction [
	"The barrier a tiled kernel puts between filling a shared tile and reading it. All three
	 operands are ids of constants, which the pool declares and deduplicates. The semantics
	 name the Workgroup storage class, because a barrier that only synchronised execution
	 would let a lane read a tile slot its neighbour has written but not yet made visible.
	 It lives on the module rather than the builder so that the hand-built and the compiled
	 path share one definition."

	| scopeId semanticsId |
	scopeId := constantPool constantUInt32: SpvScope workgroup.
	semanticsId := constantPool constantUInt32:
		               (SpvMemorySemantics acquireRelease bitOr:
			                SpvMemorySemantics workgroupMemory).
	^ SpvInstruction
		  opcode: SpvOpcode opControlBarrier
		  operands: {
				  scopeId.
				  scopeId.
				  semanticsId }
]
