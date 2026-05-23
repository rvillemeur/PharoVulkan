Class {
	#name : 'PVSSAConstructor',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'constructing' }
PVSSAConstructor class >> construct: aCFG [
	"Straight-line methods have no back edges, no phi nodes needed."
	^ aCFG
]
