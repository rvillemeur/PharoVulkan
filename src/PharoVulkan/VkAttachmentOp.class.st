"
Named constants for VkAttachmentLoadOp and VkAttachmentStoreOp values used in render-pass attachment descriptions. Key methods: loadClear, loadDontCare, storeStore, storeDiscard, and the reverse lookups nameForLoadOp: and nameForStoreOp:. The two enumerations are numbered independently of each other — clearing on load and discarding on store are both one — so this class is not a VkValueConstants subclass: a single reverse lookup over its constants would answer the wrong half. The lookups select on the prefix of the selector instead, asked of the system rather than listed.
"
Class {
	#name : 'VkAttachmentOp',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkAttachmentOp class >> constantProtocol [
	"Where this class files its constants, for the prefixed reverse lookup."

	^ 'constants'
]

{ #category : 'constants' }
VkAttachmentOp class >> loadClear [
	^ 1
]

{ #category : 'constants' }
VkAttachmentOp class >> loadDontCare [
	^ 2
]

{ #category : 'reflecting' }
VkAttachmentOp class >> nameForLoadOp: anInteger [
	^ self nameForOpPrefixed: 'load' value: anInteger
]

{ #category : 'reflecting' }
VkAttachmentOp class >> nameForOpPrefixed: aPrefix value: anInteger [
	"A load operation and a store operation are numbered independently, so a lookup over
	 every constant here would answer the wrong half: clearing on load and discarding on
	 store are both one. The prefix of a selector says which half it belongs to, and it is
	 asked of the system rather than listed, so a constant added to the protocol is found
	 too. Selected by protocol as well, because performing every unary class-side selector
	 would include this one. Answers nil for a value no constant carries."

	^ ((self class selectors select: [ :each |
		    (each beginsWith: aPrefix) and: [
			    (self class >> each) numArgs = 0 and: [
				    (self class >> each) protocolName = self constantProtocol ] ] ])
		   asSortedCollection detect: [ :each | (self perform: each) = anInteger ]
		   ifNone: [ nil ]) ifNotNil: [ :each | each asString ]
]

{ #category : 'reflecting' }
VkAttachmentOp class >> nameForStoreOp: anInteger [
	^ self nameForOpPrefixed: 'store' value: anInteger
]

{ #category : 'constants' }
VkAttachmentOp class >> storeDiscard [
	^ 1
]

{ #category : 'constants' }
VkAttachmentOp class >> storeStore [
	^ 0
]
