"
Named constants for SPIR-V built-in variable decorations. All methods are class-side.
Key methods: position, globalInvocationId, localInvocationId, workgroupId (class-side).
"
Class {
	#name : 'SpvBuiltIn',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvBuiltIn class >> globalInvocationId [  ^ 28
]

{ #category : 'constants' }
SpvBuiltIn class >> instanceId [          ^ 6
]

{ #category : 'constants' }
SpvBuiltIn class >> localInvocationId [   ^ 27
]

{ #category : 'constants' }
SpvBuiltIn class >> localInvocationIndex [ ^ 29
]

{ #category : 'constants' }
SpvBuiltIn class >> pointSize [           ^ 1
]

{ #category : 'constants' }
SpvBuiltIn class >> position [            ^ 0
]

{ #category : 'constants' }
SpvBuiltIn class >> vertexId [            ^ 5
]

{ #category : 'constants' }
SpvBuiltIn class >> vertexIndex [         ^ 42
]

{ #category : 'constants' }
SpvBuiltIn class >> workgroupId [         ^ 26
]
