"
Named constants for SPIR-V execution model operands. All methods are class-side.
Key methods: vertex, fragment, glCompute (class-side).
"
Class {
	#name : 'SpvExecutionModel',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan-SPIRV'
}

{ #category : 'constants' }
SpvExecutionModel class >> fragment [  ^ 4
]

{ #category : 'constants' }
SpvExecutionModel class >> glCompute [ ^ 5
]

{ #category : 'constants' }
SpvExecutionModel class >> vertex [    ^ 0
]
