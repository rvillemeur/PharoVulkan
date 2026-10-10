"
Named constants for the SPIR-V GroupOperation enumeration, which says what a group instruction does with the values its lanes hold. All methods are class-side. Key method: reduce, which delivers one total to every lane, as opposed to the scans that deliver a running value per lane.
"
Class {
	#name : 'SpvGroupOperation',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvGroupOperation class >> reduce [
	"GroupOperation Reduce from the SPIR-V GroupOperation enumeration, the first of the four
	 and the neighbour of InclusiveScan 1. Every lane of the group receives the same total."

	^ 0
]
