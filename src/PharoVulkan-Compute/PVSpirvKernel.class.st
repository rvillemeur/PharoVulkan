"
I am the abstract superclass of the kernels of this project whose SPIR-V module is written by
hand against SpvBuilder, rather than compiled from a Pharo method by PharoVulkan-Compiler.

I hold the module in `spirv`, built once on the first send of that message, and the builder
that wrote it in `builder`. `buildSpirv` is the template: it opens the builder, adds the shader
capability every compute module needs, then asks the subclass to declare what its module
contains (`declareModule`) and to write its function (`emitMain`) before serialising. A
subclass states the entry point and the capability on its class side and declares its own
buffers; `newBufferVariableOfType:binding:` here builds one storage buffer variable of the
single descriptor set the compute pipelines of this project use.
"
Class {
	#name : 'PVSpirvKernel',
	#superclass : 'Object',
	#instVars : [
		'spirv',
		'builder'
	],
	#category : 'PharoVulkan-Compute-Kernels',
	#package : 'PharoVulkan-Compute',
	#tag : 'Kernels'
}

{ #category : 'constants' }
PVSpirvKernel class >> entryPointName [
	"The name of the entry point function, which the host side looks the kernel up by."

	^ self subclassResponsibility
]

{ #category : 'constants' }
PVSpirvKernel class >> shaderCapability [
	"The capability buildSpirv adds to every module of this hierarchy."

	^ self subclassResponsibility
]

{ #category : 'building' }
PVSpirvKernel >> buildSpirv [
	"Assemble the module. The builder is opened, the shader capability every compute module of
	 this project needs is added, then the subclass declares what its module contains and writes
	 its function. The declarations run first because a definition has to precede every use of
	 its id."

	builder := SpvBuilder new.
	builder addCapability: self class shaderCapability.
	self declareModule.
	self emitMain.
	^ builder module serialize
]

{ #category : 'building' }
PVSpirvKernel >> declareBuffers [
	"Declare the storage buffer variables of the kernel, one per binding of the descriptor set."

	^ self subclassResponsibility
]

{ #category : 'building' }
PVSpirvKernel >> declareModule [
	"Declare everything the module holds outside the function: the capabilities beyond the
	 shader one, the types, the buffers and whatever else the subclass uses."

	^ self subclassResponsibility
]

{ #category : 'building' }
PVSpirvKernel >> emitMain [
	"Write the entry point function of the kernel, after buildSpirv has declared the module."

	^ self subclassResponsibility
]

{ #category : 'building' }
PVSpirvKernel >> interfaceVariables [
	"The variables the entry point names as its interface, which the module declares before it."

	^ self subclassResponsibility
]

{ #category : 'building' }
PVSpirvKernel >> newBufferVariableOfType: aPointerType binding: anInteger [
	"One storage buffer variable at that binding of the single descriptor set this project's
	 compute pipelines use."

	| variable |
	variable := builder
		            addGlobalVariable: aPointerType
		            storageClass: SpvStorageClass storageBuffer.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration descriptorSet
		literals: { PVSPIRVEmitter computeDescriptorSet }.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration bindingDecoration
		literals: { anInteger }.
	^ variable
]

{ #category : 'accessing' }
PVSpirvKernel >> spirv [
	"The module bytes, built once per instance: the build allocates result ids from one
	 counter, so it is a fresh builder each time or nothing."

	^ spirv ifNil: [ spirv := self buildSpirv ]
]
