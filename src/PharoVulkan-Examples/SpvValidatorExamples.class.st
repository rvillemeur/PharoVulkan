"
The example of SpvValidator: the validator itself, which carries no state. spirvValidator answers
one, and its Validator tab names the executable it runs, the temporary file it writes the bytes
into, the exit code it accepts and the exception it raises. No module is validated to show it, so
this example starts no process; PVValidationExamples holds the examples that really run spirv-val,
over the richer PVSpirvValidator of the compiler.
"
Class {
	#name : 'SpvValidatorExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-SPIRV',
	#package : 'PharoVulkan-Examples',
	#tag : 'SPIRV'
}

{ #category : 'examples' }
SpvValidatorExamples class >> spirvValidator [
	"One click: a validator ready to be handed SPIR-V bytes. Open the Validator tab to read the
	 tool it would run and what it raises when that tool refuses a module."

	<sampleInstance>
	^ SpvValidator new
]
