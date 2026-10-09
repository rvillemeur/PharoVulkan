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
