"
Named constants for SPIR-V storage class operands. All methods are class-side.
Generated from spirv.core.grammar.json; Phase 1 subset is hand-written.
Key methods: uniformConstant, input, uniform, output, workgroup, storageBuffer (class-side).
"
Class {
	#name : 'SpvStorageClass',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvStorageClass class >> crossWorkgroup [ ^ 5
]

{ #category : 'constants' }
SpvStorageClass class >> function [       ^ 7
]

{ #category : 'constants' }
SpvStorageClass class >> input [          ^ 1
]

{ #category : 'constants' }
SpvStorageClass class >> output [         ^ 3
]

{ #category : 'constants' }
SpvStorageClass class >> private [        ^ 6
]

{ #category : 'constants' }
SpvStorageClass class >> storageBuffer [  ^ 12
]

{ #category : 'constants' }
SpvStorageClass class >> uniform [        ^ 2
]

{ #category : 'constants' }
SpvStorageClass class >> uniformConstant [ ^ 0
]

{ #category : 'constants' }
SpvStorageClass class >> workgroup [      ^ 4
]
