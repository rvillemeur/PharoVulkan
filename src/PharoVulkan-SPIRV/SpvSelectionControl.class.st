"
The Selection Control operand of OpSelectionMerge, as the SPIR-V specification
numbers it. One class-side method a mask bit, which is what keeps the number out of
the emitting code. SpvBuilder >> emitIf:then: sends none, and a caller who wants a
driver hint sends flatten or dontFlatten instead.
"
Class {
	#name : 'SpvSelectionControl',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV-Constants',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Constants'
}

{ #category : 'constants' }
SpvSelectionControl class >> dontFlatten [
	^ 2
]

{ #category : 'constants' }
SpvSelectionControl class >> flatten [
	^ 1
]

{ #category : 'constants' }
SpvSelectionControl class >> none [
	^ 0
]
