"
Test stub standing in for a machine with no spirv-val installed: its class-side findExecutable always answers nil, so the unavailable branches of PVSpirvValidator can be tested without touching PATH or recompiling production code.
"
Class {
	#name : 'PVMissingToolValidatorStub',
	#superclass : 'PVSpirvValidator',
	#category : 'PharoVulkan-Compiler-Tests-Fixtures',
	#package : 'PharoVulkan-Compiler-Tests',
	#tag : 'Fixtures'
}

{ #category : 'lookup' }
PVMissingToolValidatorStub class >> findExecutable [
	"No spirv-val anywhere, whatever this machine has installed."
	^ nil
]
