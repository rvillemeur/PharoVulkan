"
Abstract home of the enumeration constant classes, whose values are whole numbers rather than bits: one constant is the whole answer, so a value maps to at most one name.

Subclasses declare their constants in the protocol named by constantProtocol and inherit the reverse lookup, nameForValue:, which derives its answer by reflection rather than from a second table that could drift. Written when a second class needed that lookup; before that VkStructureType carried its own copy.

The bitmask constants are a different shape and live under VkFlagConstants, where a value decodes to several names joined together.
"
Class {
	#name : 'VkValueConstants',
	#superclass : 'Object',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkValueConstants class >> constantProtocol [
	"The protocol every constant of this class is filed under; the reverse lookup selects
	 on it."

	^ self subclassResponsibility
]

{ #category : 'reflecting' }
VkValueConstants class >> constantSelectors [
	"Selected by protocol rather than by evaluating candidates: performing every unary
	 class-side selector would include this one and recurse until the session dies."

	^ (self class selectors select: [ :each |
		   (self class >> each) protocolName = self constantProtocol ])
		asSortedCollection asArray
]

{ #category : 'reflecting' }
VkValueConstants class >> nameForValue: anInteger [
	"Answers nil for a value no constant carries, so callers can show the raw number."

	^ self constantSelectors
		  detect: [ :each | (self perform: each) = anInteger ]
		  ifNone: [ nil ]
]
