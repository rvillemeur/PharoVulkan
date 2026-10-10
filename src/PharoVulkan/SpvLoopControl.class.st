"
Named constants for the loop control mask of OpLoopMerge. All methods are class-side. The mask is a hint: it tells a driver it may unroll or must not, and says nothing about the loop's meaning, so a kernel that has no preference declares none rather than writing a bare zero. Key methods: none, unroll, dontUnroll (class-side).
"
Class {
	#name : 'SpvLoopControl',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvLoopControl class >> dontUnroll [
	"Asks the driver to leave the loop rolled. The sibling bit of unroll, and the two are
	 not meant to be set together."

	^ 16r2
]

{ #category : 'constants' }
SpvLoopControl class >> none [
	"No request either way, which leaves the decision to unroll with the driver."

	^ 16r0
]

{ #category : 'constants' }
SpvLoopControl class >> unroll [
	"Asks the driver to unroll the loop. A request, not an instruction: a driver is free to
	 ignore it."

	^ 16r1
]
