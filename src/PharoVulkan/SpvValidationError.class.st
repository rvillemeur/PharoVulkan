"
Raised when spirv-val reports a validation error on a serialized SPIR-V module.
validatorOutput contains the raw validator stderr text.
Treat every SpvValidationError as a compiler bug, not a user error.
"
Class {
	#name : 'SpvValidationError',
	#superclass : 'Error',
	#instVars : [
		'validatorOutput'
	],
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'accessing' }
SpvValidationError >> messageText [
    ^ 'SPIR-V validation failed: ' , (validatorOutput ifNil: ['(no output)'])
]

{ #category : 'accessing' }
SpvValidationError >> validatorOutput [   ^ validatorOutput
]

{ #category : 'accessing' }
SpvValidationError >> validatorOutput: s [ validatorOutput := s
]
