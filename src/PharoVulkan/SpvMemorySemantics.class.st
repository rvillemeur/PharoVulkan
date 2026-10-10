"
Named constants for the SPIR-V Memory Semantics bitmask, which says what a barrier or an atomic makes visible and in which order. All methods are class-side.

The values are single bits and are meant to be combined: a workgroup barrier over shared memory is acquireRelease bitOr: workgroupMemory. Key methods: acquireRelease, workgroupMemory.
"
Class {
	#name : 'SpvMemorySemantics',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvMemorySemantics class >> acquire [
	"Acquire: no read or write after this one can be seen to happen before it."

	^ 16r2
]

{ #category : 'constants' }
SpvMemorySemantics class >> acquireRelease [
	"AcquireRelease: both at once, which is what a barrier in the middle of a tiled loop needs — the tile just written must be visible, and the tile about to be read must not be loaded early."

	^ 16r8
]

{ #category : 'constants' }
SpvMemorySemantics class >> crossWorkgroupMemory [
	"CrossWorkgroupMemory: the semantics apply to memory shared between workgroups."

	^ 16r200
]

{ #category : 'constants' }
SpvMemorySemantics class >> release [
	"Release: every write before this one is visible to whatever acquires."

	^ 16r4
]

{ #category : 'constants' }
SpvMemorySemantics class >> sequentiallyConsistent [
	"SequentiallyConsistent: one total order over all such operations. Stronger than a tile barrier needs."

	^ 16r10
]

{ #category : 'constants' }
SpvMemorySemantics class >> subgroupMemory [
	"SubgroupMemory: the semantics apply to memory shared within a subgroup."

	^ 16r80
]

{ #category : 'constants' }
SpvMemorySemantics class >> uniformMemory [
	"UniformMemory: the semantics apply to uniform and storage buffer memory."

	^ 16r40
]

{ #category : 'constants' }
SpvMemorySemantics class >> workgroupMemory [
	"WorkgroupMemory: the semantics apply to the Workgroup storage class, which is where a shared memory tile lives."

	^ 16r100
]
