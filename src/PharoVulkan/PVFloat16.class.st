"
IEEE-754 binary16 on the host side: the encode and decode a f16 storage buffer needs, plus the decoded fields of one half word for reading. The class side is the codec (wordForFloat:, floatFromWord:); an instance wraps one 16-bit word so its sign, exponent, mantissa and classification can be inspected. Rounding is round-to-nearest, ties to even, in the normal and the subnormal range alike, and values beyond the last finite half saturate to infinity.
"
Class {
	#name : 'PVFloat16',
	#superclass : 'Object',
	#instVars : [
		'word'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'constants' }
PVFloat16 class >> binary64ExponentBias [
	^ 1023
]

{ #category : 'constants' }
PVFloat16 class >> binary64ExponentMask [
	^ 16r7FF
]

{ #category : 'constants' }
PVFloat16 class >> binary64MantissaBits [
	^ 52
]

{ #category : 'constants' }
PVFloat16 class >> binary64SignShift [
	^ 63
]

{ #category : 'constants' }
PVFloat16 class >> bytesPerHalf [
	^ 2
]

{ #category : 'examples' }
PVFloat16 class >> exampleHalfOfOneThird [
	"A third is not representable in any binary format, so this half shows the rounding:
	 the Half tab names its fields and re-encodes its own value."

	<sampleInstance>
	^ self fromFloat: 1 / 3
]

{ #category : 'constants' }
PVFloat16 class >> exponentBias [
	^ 15
]

{ #category : 'constants' }
PVFloat16 class >> exponentMask [
	^ 16r1F
]

{ #category : 'codec' }
PVFloat16 class >> floatFromWord: anInteger [
	| biased mantissa magnitude |
	biased := (anInteger bitShift: 0 - self mantissaBits) bitAnd: self exponentMask.
	mantissa := anInteger bitAnd: self mantissaMask.
	magnitude := self magnitudeFromBiased: biased mantissa: mantissa.
	((anInteger bitShift: 0 - self signShift) bitAnd: 1) = 1 ifTrue: [
		^ magnitude negated ].
	^ magnitude
]

{ #category : 'instance creation' }
PVFloat16 class >> fromFloat: aNumber [
	^ self on: (self wordForFloat: aNumber)
]

{ #category : 'constants' }
PVFloat16 class >> infinityWord [
	^ 16r7C00
]

{ #category : 'codec' }
PVFloat16 class >> magnitudeFromBiased: biased mantissa: mantissa [
	biased = self exponentMask ifTrue: [
		^ mantissa = 0
			  ifTrue: [ Float infinity ]
			  ifFalse: [ Float nan ] ].
	biased = 0 ifTrue: [
		^ mantissa asFloat timesTwoPower: 1 - self exponentBias - self mantissaBits ].
	^ (mantissa + (1 bitShift: self mantissaBits)) asFloat timesTwoPower:
		  biased - self exponentBias - self mantissaBits
]

{ #category : 'codec' }
PVFloat16 class >> magnitudeWordForBiased: biased mantissa: mantissa [
	"The 15 low bits of the half word: biased exponent and mantissa, no sign. The
	 subnormal branch shifts the implicit one in by hand, since the half format has no
	 exponent left to borrow from."

	| target significand |
	biased = self binary64ExponentMask ifTrue: [ ^ self infinityWord ].
	biased = 0 ifTrue: [ ^ 0 ].
	target := biased - self binary64ExponentBias + self exponentBias.
	target >= self exponentMask ifTrue: [ ^ self infinityWord ].
	significand := mantissa + (1 bitShift: self binary64MantissaBits).
	target > 0 ifFalse: [
		^ self
			  roundHalfToEven: significand
			  dropping: self binary64MantissaBits - self mantissaBits + 1 - target ].
	^ ((target - 1) bitShift: self mantissaBits)
	  +
	  (self
		   roundHalfToEven: significand
		   dropping: self binary64MantissaBits - self mantissaBits)
]

{ #category : 'constants' }
PVFloat16 class >> mantissaBits [
	^ 10
]

{ #category : 'constants' }
PVFloat16 class >> mantissaMask [
	^ 16r3FF
]

{ #category : 'instance creation' }
PVFloat16 class >> on: anInteger [
	^ self new setWord: anInteger
]

{ #category : 'constants' }
PVFloat16 class >> quietNaNWord [
	"Mantissa high bit set, every other mantissa bit clear: the canonical quiet NaN."

	^ 16r7E00
]

{ #category : 'codec' }
PVFloat16 class >> roundHalfToEven: aValue dropping: shiftCount [
	"Round aValue, whose low shiftCount bits are not representable, to nearest; on an exact
	 tie answer the even neighbour. The carry out of the mantissa is left to the caller,
	 where it lands in the exponent field on its own."

	| truncated dropped half |
	truncated := aValue bitShift: 0 - shiftCount.
	dropped := aValue bitAnd: (1 bitShift: shiftCount) - 1.
	half := 1 bitShift: shiftCount - 1.
	dropped > half ifTrue: [ ^ truncated + 1 ].
	(dropped = half and: [ truncated odd ]) ifTrue: [ ^ truncated + 1 ].
	^ truncated
]

{ #category : 'constants' }
PVFloat16 class >> signShift [
	^ 15
]

{ #category : 'codec' }
PVFloat16 class >> wordForFloat: aNumber [
	"Encode from the binary64 bits rather than through binary32: going via a float would
	 round twice, which moves a tie onto the wrong neighbour."

	| value bits sign biased mantissa |
	value := aNumber asFloat.
	value isNaN ifTrue: [ ^ self quietNaNWord ].
	bits := value asIEEE64BitWord.
	sign := (bits bitShift: 0 - self binary64SignShift) bitAnd: 1.
	biased := (bits bitShift: 0 - self binary64MantissaBits) bitAnd:
		          self binary64ExponentMask.
	mantissa := bits bitAnd: (1 bitShift: self binary64MantissaBits) - 1.
	^ (sign bitShift: self signShift)
	  + (self magnitudeWordForBiased: biased mantissa: mantissa)
]

{ #category : 'accessing' }
PVFloat16 >> biasedExponent [
	^ (word bitShift: 0 - self class mantissaBits) bitAnd: self class exponentMask
]

{ #category : 'accessing' }
PVFloat16 >> classification [
	"Named by calling the predicates, not by re-reading the bits, so the name and the
	 predicate cannot disagree."

	self isNaN ifTrue: [ ^ #notANumber ].
	self isInfinite ifTrue: [ ^ #infinity ].
	self isSubnormal ifTrue: [ ^ #subnormal ].
	self isZero ifTrue: [ ^ #zero ].
	^ #normal
]

{ #category : 'reporting' }
PVFloat16 >> fieldReport [
	"The last row encodes the decoded value again. Anything but the word itself there means
	 encode and decode disagree about this half."

	^ {
		  (self rowNamed: 'Word' value: word printStringHex).
		  (self rowNamed: 'Value' value: self value printString).
		  (self rowNamed: 'Classification' value: self classification).
		  (self rowNamed: 'Sign' value: self sign printString).
		  (self rowNamed: 'Biased exponent' value: self biasedExponent printString).
		  (self rowNamed: 'Mantissa' value: self mantissa printString).
		  (self
			   rowNamed: 'Re-encodes to'
			   value: (self class wordForFloat: self value) printStringHex) }
]

{ #category : 'inspector' }
PVFloat16 >> inspectorFields: aBuilder [
	<inspectorPresentationOrder: 10 title: 'Half'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Field' evaluated: [ :each |
					   each at: #setting ]);
		  addColumn:
			  (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   each at: #value ]);
		  items: self fieldReport;
		  yourself
]

{ #category : 'testing' }
PVFloat16 >> isInfinite [
	^ self biasedExponent = self class exponentMask and: [ self mantissa = 0 ]
]

{ #category : 'testing' }
PVFloat16 >> isNaN [
	^ self biasedExponent = self class exponentMask and: [ self mantissa ~= 0 ]
]

{ #category : 'testing' }
PVFloat16 >> isSubnormal [
	"A zero exponent field with a non-zero mantissa: no implicit one, so the step between
	 neighbours is the same as it is at the smallest normal."

	^ self biasedExponent = 0 and: [ self mantissa ~= 0 ]
]

{ #category : 'testing' }
PVFloat16 >> isZero [
	^ self biasedExponent = 0 and: [ self mantissa = 0 ]
]

{ #category : 'accessing' }
PVFloat16 >> mantissa [
	^ word bitAnd: self class mantissaMask
]

{ #category : 'printing' }
PVFloat16 >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPut: $(;
		nextPutAll: word printStringHex;
		nextPutAll: ' = ';
		print: self value;
		nextPutAll: ', ';
		nextPutAll: self classification;
		nextPut: $)
]

{ #category : 'reporting' }
PVFloat16 >> rowNamed: aString value: anObject [
	^ Dictionary new
		  at: #setting put: aString;
		  at: #value put: anObject asString;
		  yourself
]

{ #category : 'initialization' }
PVFloat16 >> setWord: anInteger [
	word := anInteger
]

{ #category : 'accessing' }
PVFloat16 >> sign [
	^ (word bitShift: 0 - self class signShift) bitAnd: 1
]

{ #category : 'evaluating' }
PVFloat16 >> value [
	^ self class floatFromWord: word
]

{ #category : 'accessing' }
PVFloat16 >> word [
	^ word
]
