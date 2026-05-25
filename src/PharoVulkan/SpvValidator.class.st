"
Validates a SPIR-V ByteArray by invoking spirv-val from the system PATH.
Raises SpvValidationError on any validation failure.
Key methods: validate: (class-side), spirvValPath (class-side, override to set custom location).
"
Class {
	#name : 'SpvValidator',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'configuration' }
SpvValidator class >> spirvValPath [
    "Path to the spirv-val binary. Override in a subclass or configure here."
    ^ 'spirv-val'
]

{ #category : 'validation' }
SpvValidator class >> validate: aByteArray [
    "Invoke spirv-val on a temp file. Raises SpvValidationError if validation fails
     or if spirv-val is not installed."
    | path cmd exitCode |
    path := FileReference newTempFilePrefix: 'pharovk-' suffix: '.spv'.
    [
        path binaryWriteStreamDo: [:s | s nextPutAll: aByteArray].
        cmd := self spirvValPath , ' ' , path fullName , ' 2>&1; echo $?'.
        exitCode := [
            | result lines |
            result := LibC resultOfCommand: cmd.
            lines := result lines.
            lines last trimmed asInteger
        ] on: Error do: [:e |
            SpvValidationError new
                validatorOutput: 'spirv-val not found or failed to run: ' , e messageText;
                signal.
            1].
        exitCode = 0 ifFalse: [
            SpvValidationError new
                validatorOutput: 'spirv-val reported errors (exit ' , exitCode printString , ')';
                signal ]
    ] ensure: [ path exists ifTrue: [ path delete ] ]
]

{ #category : 'validation' }
SpvValidator >> validate: aByteArray [
    "Validate SPIR-V bytes using spirv-val. Signals SpvValidationError on failure.
     Uses LibC resultOfCommand: since OSSUnixSubprocess is unavailable in this image."
    | path cmd exitCode |
    path := FileReference newTempFilePrefix: 'pharovk-' suffix: '.spv'.
    [
        path binaryWriteStreamDo: [:s | s nextPutAll: aByteArray].
        cmd := self class spirvValPath , ' ' , path fullName , ' 2>&1; echo $?'.
        exitCode := [
            | result lines |
            result := LibC resultOfCommand: cmd.
            lines := result lines.
            lines last trimmed asInteger
        ] on: Error do: [:e |
            SpvValidationError new
                validatorOutput: 'spirv-val not found or failed to run: ' , e messageText;
                signal.
            1].
        exitCode = 0 ifFalse: [
            SpvValidationError new
                validatorOutput: 'spirv-val reported errors (exit ' , exitCode printString , ')';
                signal ]
    ] ensure: [ path exists ifTrue: [ path delete ] ]
]
