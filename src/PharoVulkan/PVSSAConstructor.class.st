"
Constructs SSA form using the Braun et al. on-the-fly algorithm. Inserts phi nodes at join points without a separate dominance pass. Stage 5 of the pipeline.
"
Class {
	#name : 'PVSSAConstructor',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'constructing' }
PVSSAConstructor class >> construct: aCFG [
	"Straight-line methods have no back edges, no phi nodes needed."
	^ aCFG
]
