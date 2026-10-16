"
Named values of VkComponentTypeKHR, the element type of a cooperative matrix.

Key methods: the class-side value accessors (float16, float32, sint8, …), nameOf: for the symbol behind a value a driver reported, and isDefined: which answers whether a value is one the specification names.
"
Class {
	#name : 'VkComponentType',
	#superclass : 'Object',
	#category : 'PharoVulkan-Core-CooperativeMatrix',
	#package : 'PharoVulkan-Core',
	#tag : 'CooperativeMatrix'
}

{ #category : 'constants' }
VkComponentType class >> float16 [
	^ self valueNamed: #float16
]

{ #category : 'constants' }
VkComponentType class >> float32 [
	^ self valueNamed: #float32
]

{ #category : 'constants' }
VkComponentType class >> isDefined: aValue [
	"Whether a value is one the specification names. A driver answering anything else means
	 the field was read at the wrong offset."

	^ (self nameOf: aValue) notNil
]

{ #category : 'constants' }
VkComponentType class >> nameOf: aValue [
	"The symbol behind a value a driver reported, or nil where the value is not one the
	 specification names."

	^ self values keyAtValue: aValue ifAbsent: [ nil ]
]

{ #category : 'constants' }
VkComponentType class >> valueNamed: aSymbol [
	^ self values at: aSymbol ifAbsent: [ VkError signal: 'No such value: ' , aSymbol printString ]
]

{ #category : 'constants' }
VkComponentType class >> values [
	"Every VkComponentTypeKHR the specification names, in value order. One table, so a
	 name and a value cannot drift apart."

	^ Dictionary newFrom: {
			  (#float16 -> 0).
			  (#float32 -> 1).
			  (#float64 -> 2).
			  (#sint8 -> 3).
			  (#sint16 -> 4).
			  (#sint32 -> 5).
			  (#sint64 -> 6).
			  (#uint8 -> 7).
			  (#uint16 -> 8).
			  (#uint32 -> 9).
			  (#uint64 -> 10) }
]
