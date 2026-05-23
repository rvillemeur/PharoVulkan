"
Two-pass emitter: assigns result ids to IR nodes (pass 1) then emits SpvInstructions (pass 2). Use module to configure capabilities, types, globals, and decorations before calling emitFunction:.
"
Class {
	#name : 'SpvModuleEmitter',
	#superclass : 'Object',
	#instVars : [
		'module',
		'idMap'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'instance creation' }
SpvModuleEmitter class >> new [
	^ super new initialize
]

{ #category : 'private' }
SpvModuleEmitter >> assignIds: anIRFunction [
	"Pass 1: assign result ids to all parameters, block labels, and result-producing nodes."
	anIRFunction parameters do: [:p |
		p id: module newId.
		idMap at: p put: p id].
	anIRFunction blocks do: [:b |
		b id: module newId.
		b nodes do: [:n |
			n hasResult ifTrue: [
				n id: module newId.
				idMap at: n put: n id]].
		b terminator ifNotNil: [:t |
			t hasResult ifTrue: [
				t id: module newId.
				idMap at: t put: t id]]]
]

{ #category : 'emitting' }
SpvModuleEmitter >> emitFunction: anIRFunction [
	"Pass 2: emit SpvFunction with blocks and instructions."
	| funcType spvFunc |
	self assignIds: anIRFunction.
	funcType := module typeRegistry
		functionType: anIRFunction returnType
		paramTypes: anIRFunction parameterTypes asArray.
	spvFunc := SpvFunction new
		id: module newId;
		returnType: anIRFunction returnType;
		functionType: funcType;
		module: module;
		initialize;
		yourself.
	anIRFunction parameters do: [:p |
		spvFunc parameters add: (SpvInstruction
			opcode: SpvOpcode opFunctionParameter
			resultType: p type id
			resultId: p id
			operands: #())].
	anIRFunction blocks do: [:irBlk |
		| spvBlk |
		spvBlk := SpvBlock new
			id: irBlk id;
			function: spvFunc;
			initialize;
			yourself.
		spvFunc blocks add: spvBlk.
		irBlk nodes do: [:n | n emitInto: spvBlk idMap: idMap module: module].
		irBlk terminator emitInto: spvBlk idMap: idMap module: module].
	module addFunction: spvFunc.
	^ spvFunc
]

{ #category : 'building' }
SpvModuleEmitter >> globalRef: anId type: aType [
	"Register an existing global variable id for use as an IR operand."
	| ref |
	ref := SpvIRGlobalRef id: anId type: aType.
	idMap at: ref put: anId.
	^ ref
]

{ #category : 'initialization' }
SpvModuleEmitter >> initialize [
	module := SpvModule new initialize.
	idMap := Dictionary new
]

{ #category : 'accessing' }
SpvModuleEmitter >> module [ ^ module
]
