"
Loads SPIR-V bytecode into a `VkShaderModule_H` on a device. `fromBytes:device:` copies the words outside object memory, hands them to the driver through a declared `VkShaderModuleCreateInfo` and frees the copy: a module keeps no reference to the code it was created from. The byte count is kept in the instance, because the driver never answers it back, and `moduleRows` reports it with the word count and whether the handle is still live. Must be destroyed explicitly with `destroy` once the pipelines using it are built.

The class side answers `defaultEntryPoint`, the name of the function a module is entered through. It lives here because the name belongs to the compiled module rather than to a kind of pipeline: both the compute and the graphics stage builders ask for it.
"
Class {
	#name : 'VkShaderModule',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'codeSize'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'private' }
VkShaderModule class >> codeOutsideObjectMemory: spirvBytes [
	"The driver reads the words through a pointer, and the garbage collector may move a store
	 that lives inside the image between the pointer being written and the read. The caller
	 frees the block."

	| address |
	address := ExternalAddress allocate: spirvBytes size.
	1 to: spirvBytes size do: [ :i |
		address byteAt: i put: (spirvBytes at: i) ].
	^ address
]

{ #category : 'constants' }
VkShaderModule class >> defaultEntryPoint [
	"The name of the function a compiled shader module is entered through. The SPIR-V this
	 project emits names every entry point main, so every pipeline stage created from one of
	 these modules asks for that name. The name belongs to the module rather than to a kind of
	 pipeline, which is why compute and graphics both read it here."

	^ 'main'
]

{ #category : 'examples' }
VkShaderModule class >> exampleModuleOfTheVectorAddKernelOnThisMachine [
	"One click: the kernel the README's playground builds, compiled to SPIR-V and loaded as a
	 shader module on whichever device is here, then destroyed with its context. The byte
	 count lives in the instance, so the Module tab still answers afterwards. Where no device
	 is available it answers an empty module, which is what the inspector should show on such
	 a machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ self new ].
	^ [
	  | module |
	  module := self
		            fromBytes:
			            (PVKernelCompiler compile:
				             PVComputeKernel exampleKernelMethod)
		            device: context device.
	  module destroy.
	  module ] ensure: [ context destroy ]
]

{ #category : 'factory' }
VkShaderModule class >> fromBytes: spirvBytes device: aDevice [
    ^ self new initializeFromBytes: spirvBytes device: aDevice
]

{ #category : 'private' }
VkShaderModule >> createHandleFrom: spirvBytes [
	"The code is copied outside object memory, handed to the driver and freed once the module
	 holds it: a shader module keeps no reference to the words it was compiled from."

	| code |
	code := self class codeOutsideObjectMemory: spirvBytes.
	handle := [ self handleForCode: code ] ensure: [ code free ]
]

{ #category : 'lifecycle' }
VkShaderModule >> destroy [

	handle ifNotNil: [
			Vk
				destroyShaderModule: device handle
				shaderModule: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkShaderModule >> handle [
    ^ handle
]

{ #category : 'private' }
VkShaderModule >> handleForCode: aCodeAddress [
	"The byte count and the address of the words are all the driver needs; the flags are
	 reserved and stay as the zeroed block left them."

	| info |
	info := VkShaderModuleCreateInfo externalInstance.
	^ [
	  info
		  codeSize: codeSize;
		  pCode: aCodeAddress.
	  self handleForCreateInfo: info ] ensure: [ info getHandle free ]
]

{ #category : 'private' }
VkShaderModule >> handleForCreateInfo: aCreateInfo [
	"The driver writes the new module handle into an out parameter, which is read before the
	 block holding it is freed."

	| out result |
	out := ExternalAddress allocate: VkContext pointerSize.
	^ [
	  result := Vk
		            createShaderModule: device handle
		            createInfo: aCreateInfo getHandle
		            allocator: ExternalAddress null
		            shaderModuleOut: out.
	  Vk checkResult: result.
	  VkShaderModule_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'initialization' }
VkShaderModule >> initialize [
	"A module that has been handed no code carries none, so the byte count reads as zero
	 rather than as nil: the Module tab is opened on such a module when no device is here."

	super initialize.
	codeSize := 0
]

{ #category : 'lifecycle' }
VkShaderModule >> initializeFromBytes: spirvBytes device: aDevice [
	"The byte count is kept, because it is what the module was created from and the driver
	 never answers it back."

	device := aDevice.
	codeSize := spirvBytes size.
	self createHandleFrom: spirvBytes
]

{ #category : 'inspector' }
VkShaderModule >> inspectorModule: aBuilder [
	"What the module was created from: the byte count, the words that makes, whether the count
	 is a whole number of words — asked of the create info's own rule — and whether the handle
	 is still live. The rows are built fresh, so opening the tab cannot change the module."

	<inspectorPresentationOrder: 30 title: 'Module'>
	| rows |
	rows := self moduleRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Bytes'. (rows at: #bytes) }.
				  { 'Words'. (rows at: #words) }.
				  { 'Whole words'. (rows at: #wholeWords) }.
				  { 'Handle live'. (rows at: #live) } };
		  yourself
]

{ #category : 'accessing' }
VkShaderModule >> moduleRows [
	"What the module was created from, kept in the instance because the driver answers none of
	 it back: the byte count, the number of whole 32-bit words that makes, and whether the
	 count is a whole number of words at all — the rule is asked of the structure that
	 declares the field rather than restated here. Each call builds a fresh row."

	| wordBytes |
	wordBytes := VkShaderModuleCreateInfo codeWordByteCount.
	^ (Dictionary newFrom: {
			   (#bytes -> codeSize).
			   (#words -> (codeSize // wordBytes)).
			   (#wholeWords -> (codeSize \\ wordBytes = 0)).
			   (#live -> handle notNil) }) beReadOnlyObject
]
