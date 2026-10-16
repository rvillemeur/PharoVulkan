"
Named constants for SPIR-V decoration operands. All methods are class-side.
Key methods: block, binding, descriptorSet, builtIn, location (class-side).
"
Class {
	#name : 'SpvDecoration',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV-Constants',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Constants'
}

{ #category : 'constants' }
SpvDecoration class >> arrayStride [      ^ 6
]

{ #category : 'constants' }
SpvDecoration class >> bindingDecoration [
	"The SPIR-V decoration is named Binding, but this method cannot be: Class >> binding answers
	 the global variable that holds a class, and a class-side method of that name hides it, which
	 breaks every tool that reads a class reflectively."

	^ 33
]

{ #category : 'constants' }
SpvDecoration class >> block [            ^ 2
]

{ #category : 'constants' }
SpvDecoration class >> builtIn [          ^ 11
]

{ #category : 'constants' }
SpvDecoration class >> descriptorSet [    ^ 34
]

{ #category : 'constants' }
SpvDecoration class >> location [         ^ 30
]

{ #category : 'constants' }
SpvDecoration class >> offset [
	^ 35
]

{ #category : 'constants' }
SpvDecoration class >> relaxedPrecision [ ^ 0
]
