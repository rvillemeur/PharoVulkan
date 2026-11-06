"
I hold the SpvModule a caller fills, and nothing else.

I used to walk a tree of SpvIRNode objects — an intermediate representation with its own blocks, functions, parameters and global references — and turn it into module instructions. That layer was deleted in review point 10: no production code ever built one. The DSL compiler goes straight from Pharo bytecode to SpvBuilder calls through PVSPIRVEmitter, so the IR existed only for the one test that assembled a vector-add module by hand, and that test proved the IR rather than the compiler.

What remains is the module accessor. Build a module with SpvBuilder or with PVSPIRVEmitter; use me when a caller wants an emitter object holding a module it populates itself.
"
Class {
	#name : 'SpvModuleEmitter',
	#superclass : 'Object',
	#instVars : [
		'module'
	],
	#category : 'PharoVulkan-SPIRV-Emitter',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Emitter'
}

{ #category : 'initialization' }
SpvModuleEmitter >> initialize [
	super initialize.
	module := SpvModule new initialize
]

{ #category : 'accessing' }
SpvModuleEmitter >> module [ ^ module
]
