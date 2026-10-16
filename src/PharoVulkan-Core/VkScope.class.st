"
Named values of VkScopeKHR, the set of invocations a cooperative matrix is shared by.

This is the Vulkan enumeration, not the SPIR-V one: SpvScope carries the values the emitter puts in a module, which are numbered differently.

Key methods: subgroup, workgroup, device, queueFamily, nameOf: and isDefined:.
"
Class {
	#name : 'VkScope',
	#superclass : 'Object',
	#category : 'PharoVulkan-Core-CooperativeMatrix',
	#package : 'PharoVulkan-Core',
	#tag : 'CooperativeMatrix'
}

{ #category : 'constants' }
VkScope class >> isDefined: aValue [
	"Whether a value is one the specification names. A driver answering anything else means
	 the field was read at the wrong offset."

	^ (self nameOf: aValue) notNil
]

{ #category : 'constants' }
VkScope class >> nameOf: aValue [
	"The symbol behind a value a driver reported, or nil where the value is not one the
	 specification names."

	^ self values keyAtValue: aValue ifAbsent: [ nil ]
]

{ #category : 'constants' }
VkScope class >> subgroup [
	^ self valueNamed: #subgroup
]

{ #category : 'constants' }
VkScope class >> valueNamed: aSymbol [
	^ self values at: aSymbol ifAbsent: [ VkError signal: 'No such value: ' , aSymbol printString ]
]

{ #category : 'constants' }
VkScope class >> values [
	"Every VkScopeKHR the specification names. 4 is absent from the enumeration itself."

	^ Dictionary newFrom: {
			  (#device -> 1).
			  (#workgroup -> 2).
			  (#subgroup -> 3).
			  (#queueFamily -> 5) }
]
