"
Test stub standing in for a machine with no spirv-val installed: its class-side findExecutable always answers nil, so the unavailable branches of PVSpirvValidator can be tested without touching PATH or recompiling production code.
"
Class {
	#name : 'PVMissingToolValidatorStub',
	#superclass : 'PVSpirvValidator',
	#category : 'PharoVulkan-Tests-Compiler',
	#package : 'PharoVulkan-Tests',
	#tag : 'Compiler'
}

{ #category : 'lookup' }
PVMissingToolValidatorStub class >> findExecutable [
	"No spirv-val anywhere, whatever this machine has installed."
	^ nil
]
