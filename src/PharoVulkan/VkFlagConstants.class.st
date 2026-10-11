"
Abstract home of the bitmask constant classes. Subclasses declare namedBits, one
value -> name association per bit they name, and inherit nameForFlags:, which decodes a
flags word the driver reported into those names and surfaces anything left over as raw
hex. Written because two subclasses had grown the same decoder by hand.
"
Class {
	#name : 'VkFlagConstants',
	#superclass : 'Object',
	#category : 'PharoVulkan-Constants',
	#package : 'PharoVulkan',
	#tag : 'Constants'
}

{ #category : 'decoding' }
VkFlagConstants class >> nameForFlags: flags [
	"Joins the names of the bits this class declares; a bit no constant here carries is
	 shown as its raw hex rather than silently dropped, so a view can never hide a
	 property the driver reported."
	| remainder names |
	names := OrderedCollection new.
	remainder := flags.
	self namedBits do: [ :each |
		(flags bitAnd: each key) = each key ifTrue: [
			names add: each value.
			remainder := remainder bitAnd: each key bitInvert ] ].
	remainder ~= 0 ifTrue: [
		names add: (remainder printPaddedWith: $0 to: 1 base: 16) , 'h' ].
	^ String streamContents: [ :s |
		names do: [ :n | s nextPutAll: n ] separatedBy: [ s nextPutAll: '|' ] ]
]

{ #category : 'decoding' }
VkFlagConstants class >> namedBits [
	"Value -> name for every bit this class names, lowest bit first. The decoder reads
	 this list, so naming one more bit never touches the decoding itself."
	^ self subclassResponsibility
]
