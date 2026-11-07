"
Validates a SPIR-V ByteArray by invoking spirv-val from the system PATH.
Raises SpvValidationError on any validation failure.
Key methods: validate: (class-side), spirvValPath (class-side, override to set custom location).
"
Class {
	#name : 'SpvValidator',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV-Validator',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Validator'
}

{ #category : 'constants' }
SpvValidator class >> failureExitCode [
	"What the handler answers when spirv-val could not be run at all. It is only reached after
	 the error has been signalled, so it stands for 'not a success' and nothing more."

	^ 1
]

{ #category : 'constants' }
SpvValidator class >> spirvFileExtension [
	"What a SPIR-V binary is named for, which is what spirv-val expects to be handed."

	^ '.spv'
]

{ #category : 'configuration' }
SpvValidator class >> spirvValPath [
    "Path to the spirv-val binary. Override in a subclass or configure here."
    ^ 'spirv-val'
]

{ #category : 'constants' }
SpvValidator class >> successExitCode [
	"What spirv-val answers when the module is valid. Anything else is a validation failure."

	^ 0
]

{ #category : 'constants' }
SpvValidator class >> temporaryFilePrefix [
	"spirv-val reads a file, so the bytes are written to one named for this project and
	 deleted again. The prefix is what identifies a leftover file as ours."

	^ 'pharovk-'
]

{ #category : 'validation' }
SpvValidator class >> validate: aByteArray [
	"Invoke spirv-val on a temporary file. Raises SpvValidationError if validation fails or if
	 spirv-val is not installed. The work is the instance's, so the two entry points cannot
	 drift apart."

	^ self new validate: aByteArray
]

{ #category : 'inspector' }
SpvValidator >> inspectorValidator: aBuilder [
	"What this validator will do when it is handed bytes: the tool it runs, the file it writes,
	 the exit code it accepts and the exception it raises. Nothing is run to show it, so opening
	 a validator never starts a process."

	<inspectorPresentationOrder: 10 title: 'Validator'>
	^ PVFactRow
		  tableOf: self validatorRows
		  nameColumn: 'Property'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'reflection' }
SpvValidator >> signalledErrorName [
	"The exception validate: raises, read from that method's own syntax tree: the one class it
	 instantiates before sending signal. Asking the code means the tab cannot name an exception
	 the validator stopped raising."

	^ (((self class >> #validate:) ast allChildren select: [ :each |
		    each isMessage and: [ each receiver isVariable ] ]) detect: [ :each |
		   each receiver name first isUppercase and: [
			   each selector = #new ] ]) receiver name
]

{ #category : 'validation' }
SpvValidator >> validate: aByteArray [
	"Validate SPIR-V bytes using spirv-val. Signals SpvValidationError on failure.
	 Uses LibC resultOfCommand: since OSSUnixSubprocess is unavailable in this image."

	| path cmd exitCode |
	path := FileReference
		        newTempFilePrefix: self class temporaryFilePrefix
		        suffix: self class spirvFileExtension.
	[
	path binaryWriteStreamDo: [ :s | s nextPutAll: aByteArray ].
	cmd := self class spirvValPath , ' ' , path fullName , ' 2>&1; echo $?'.
	exitCode := [
	            | result lines |
	            result := LibC resultOfCommand: cmd.
	            lines := result lines.
	            lines last trimmed asInteger ]
		            on: Error
		            do: [ :e |
			            SpvValidationError new
				            validatorOutput:
					            'spirv-val not found or failed to run: ' , e messageText;
				            signal.
			            self class failureExitCode ].
	exitCode = self class successExitCode ifFalse: [
		SpvValidationError new
			validatorOutput:
				'spirv-val reported errors (exit ' , exitCode printString , ')';
			signal ] ] ensure: [ path exists ifTrue: [ path delete ] ]
]

{ #category : 'inspector' }
SpvValidator >> validatorRows [
	"The contract of a validator, which is all a reader can ask of an object with no state: the
	 executable, the file the bytes are written into, the exit code accepted and the exception
	 raised. The exception is read from the syntax tree of validate: rather than named here, so
	 a change of exception shows in the tab by itself."

	^ {
		  (PVFactRow name: 'executable' value: self class spirvValPath).
		  (PVFactRow
			   name: 'temporary file'
			   value: self class temporaryFilePrefix , '…'
				   , self class spirvFileExtension).
		  (PVFactRow
			   name: 'accepted exit code'
			   value: self class successExitCode).
		  (PVFactRow name: 'signals' value: self signalledErrorName) }
]
