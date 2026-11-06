"
I hold the architecture document to the image. Every name doc/architecture.md writes between
backticks is read as a claim: a capitalised word must name a class, a class variable of a code
package of this project or a package; a Class >> selector form must be understood by that class; a
bare keyword selector must be implemented somewhere; and a <...> token is read as a pragma, which
passes when a method of the project carries it. A fenced block holds a drawing, not a claim, so
the tokeniser skips it.

The document is a file of the repository, not of the image, so an image that loaded the project
from Metacello has none and every gate here skips rather than fails. The ten names the document
writes for things the image must not hold -- a SPIR-V mnemonic, five classes point 4 removed and
four Vulkan C names this project renames -- are listed by namesTheImageNeedNotHold, and a gate
asserts each is still absent, so an entry cannot outlive its reason.
"
Class {
	#name : 'PVDocumentationTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Tests',
	#package : 'PharoVulkan-Tests',
	#tag : 'Tests'
}

{ #category : 'reporting' }
PVDocumentationTest class >> documentReport [
	"Every backticked token of the document with what this gate reads it as and its verdict, or
	 an empty list when there is no checkout. Built by the gate''s own predicates, so the view
	 cannot drift from what the tests assert."

	| gate contents |
	gate := self new.
	contents := gate architectureDocumentContents ifNil: [ ^ #( ) ].
	^ ((gate backtickedTokensOf: contents) collect: [ :each | 
		   (gate isQualifiedSelectorToken: each)
			   ifTrue: [ 
				   { each. 'method'. (gate isImplementedMethodToken: each) } ]
			   ifFalse: [ 				   (gate isKeywordSelectorToken: each)
					   ifTrue: [ 
						   { each. 'selector'. (gate isImplementedSelectorToken: each) } ]
					   ifFalse: [ 
						   (gate isClassNameToken: each)
							   ifTrue: [ 
								   { each. 'name'. (gate architectureDocumentMayName: each) } ]
							   ifFalse: [ { each. 'not a claim'. true } ] ] ] ]) asArray
]

{ #category : 'inspector' }
PVDocumentationTest class >> inspectorDocumentClaims: aBuilder [
	"Every backticked token of the architecture document, what the gate reads it as, and whether
	 the image bears it out. Reads documentReport, so it shows what the gates assert and mutates
	 nothing."

	<inspectorPresentationOrder: 10 title: 'Document claims'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Token' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn title: 'Read as' evaluated: [ :each | each second ]);
		  addColumn: (SpStringTableColumn
				   title: 'Borne out'
				   evaluated: [ :each | each third ifTrue: [ 'yes' ] ifFalse: [ 'no' ] ]);
		  items: self documentReport;
		  yourself
]

{ #category : 'constants' }
PVDocumentationTest class >> namesTheImageNeedNotHold [
	"The names the document writes for things this image must not hold. Three reasons, and no
	 fourth is accepted: OpPhi is a SPIR-V mnemonic the emitter writes and no class of this
	 project; the five PV names are the SSA stage point 4 removed, which the document records as
	 removed; the four Vk names are Vulkan C enum names in the renaming table, whose whole point
	 is that this project does not use them. testEveryExemptedNameIsStillAbsentFromTheImage
	 asserts each is still absent, so an entry cannot outlive its reason."

	^ #( 'OpPhi' 'PVSSAConstructor' 'PVSSAVar' 'PVPhiNode' 'PVControlFlowGraph'
	     'PVBasicBlock' 'VkShaderStageFlagBits' 'VkMemoryPropertyFlagBits'
	     'VkImageUsageFlagBits' 'VkPipelineStageFlags2' )
]

{ #category : 'private - document' }
PVDocumentationTest >> architectureDocumentContents [
	"Answer the text of the architecture document, or nil when there is none to read."

	| file |
	file := self architectureDocumentFile ifNil: [ ^ nil ].
	^ file exists ifTrue: [ file contents ] ifFalse: [ nil ]
]

{ #category : 'private - document' }
PVDocumentationTest >> architectureDocumentFile [
	"Answer the architecture document, or nil when this image has no checkout of the project.
	 The document is a file of the repository, not of the image, so an image that loaded the
	 packages from Metacello has no copy of it and the gates here skip rather than fail."

	| repository |
	repository := IceRepository registry
		detect: [ :each | each name = self repositoryName ]
		ifNone: [ ^ nil ].
	^ repository location / self documentDirectoryName / self architectureDocumentName
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> architectureDocumentMayName: aToken [
	"A capitalised name of the document is held to one of four things: a class of the image, a
	 class variable of a documented package, a package, or one of the names the class side says
	 the image need not hold."

	(Smalltalk includesKey: aToken asSymbol) ifTrue: [ ^ true ].
	(self classVariableNamesOfTheDocumentedPackages includes: aToken) ifTrue: [ ^ true ].
	(PackageOrganizer default packageNamed: aToken ifAbsent: [ nil ]) ifNotNil: [ ^ true ].
	^ self class namesTheImageNeedNotHold includes: aToken
]

{ #category : 'private - constants' }
PVDocumentationTest >> architectureDocumentName [
	^ 'architecture.md'
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> backtickedTokensOf: aString [
	"Answer every piece of aString written between two backticks, outside a fenced code block.
	 A fence is skipped because the diagram inside it is a drawing, not a claim about a name."

	| tokens insideAFence |
	tokens := OrderedCollection new.
	insideAFence := false.
	aString lines do: [ :line |
		(line beginsWith: '```')
			ifTrue: [ insideAFence := insideAFence not ]
			ifFalse: [ insideAFence ifFalse: [ self backtickedTokensOf: line into: tokens ] ] ].
	^ tokens
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> backtickedTokensOf: aLine into: aCollection [
	"Add every backticked piece of one line to aCollection. An unclosed backtick ends the line."

	| index |
	index := 1.
	[ (index := aLine indexOf: $` startingAt: index) > 0 ] whileTrue: [
		| closing |
		closing := aLine indexOf: $` startingAt: index + 1.
		closing = 0
			ifTrue: [ index := aLine size + 1 ]
			ifFalse: [
				aCollection add: (aLine copyFrom: index + 1 to: closing - 1).
				index := closing + 1 ] ]
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> behaviourNamedBy: aString [
	"Answer the class or metaclass aString names, or nil. ''Foo class'' names the metaclass."

	| isClassSide name class |
	isClassSide := aString endsWith: self classSideSuffix.
	name := isClassSide
		ifTrue: [ (aString allButLast: self classSideSuffix size) trimmed ]
		ifFalse: [ aString trimmed ].
	class := Smalltalk at: name asSymbol ifAbsent: [ ^ nil ].
	class isBehavior ifFalse: [ ^ nil ].
	^ isClassSide ifTrue: [ class class ] ifFalse: [ class ]
]

{ #category : 'private - constants' }
PVDocumentationTest >> classSideSuffix [
	^ ' class'
]

{ #category : 'private - packages' }
PVDocumentationTest >> classVariableNamesOfTheDocumentedPackages [
	"Answer the names of every class variable declared by a class of the documented packages, so
	 the document may name one: a session-wide handle cache is a class variable, not a class."

	| names |
	names := Set new.
	self documentedPackages do: [ :package |
		package definedClasses do: [ :each |
			names addAll: (each classVariables collect: [ :variable | variable name asString ]) ] ].
	^ names
]

{ #category : 'private - constants' }
PVDocumentationTest >> documentDirectoryName [
	^ 'doc'
]

{ #category : 'private - packages' }
PVDocumentationTest >> documentedPackages [
	"Every code package of this project: the packages whose names begin with the repository name
	 and do not end in -Tests. Read from the organiser rather than listed, so a package added
	 later is documented from the day it exists."

	^ (PackageOrganizer default packages
		   select: [ :each | each name beginsWith: self repositoryName , '-' ])
		  reject: [ :each | each name endsWith: self suffixOfATestPackage ]
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> isClassNameToken: aToken [
	"A backticked token is read as a name of the image when it is one word beginning with a
	 capital. An expression, an instance variable, a selector, a file extension and a hexadecimal
	 literal are all claims this gate cannot check, and it leaves them alone."

	^ aToken notEmpty
		and: [ aToken first isUppercase
		and: [ aToken allSatisfy: [ :each | each isAlphaNumeric ] ] ]
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> isImplementedMethodToken: aToken [
	"The named class must answer the named selector. Inherited counts: the document speaks of
	 what a class does, not of which class in the hierarchy holds the method. The separator is
	 found as a substring rather than with substrings:, which would also split on each $> alone."

	| separator index behaviour selector |
	separator := self qualifiedSelectorSeparator.
	index := aToken indexOfSubCollection: separator.
	index = 0 ifTrue: [ ^ false ].
	behaviour := self behaviourNamedBy: (aToken first: index - 1).
	behaviour ifNil: [ ^ false ].
	selector := (aToken allButFirst: index - 1 + separator size) trimmed.
	^ behaviour canUnderstand: selector asSymbol
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> isImplementedSelectorToken: aToken [
	"A bare keyword selector is implemented when some class of the image answers it. A token
	 written between angle brackets is a pragma, not a message: the DSL declares <param:named:>
	 on a kernel method and no class implements it, so a pragma passes when a method of a
	 documented package carries it."

	| selector |
	selector := self pragmaSelectorOf: aToken.
	selector ifNotNil: [ ^ self isPragmaOfADocumentedPackage: selector ].
	^ (SystemNavigation default allImplementorsOf: aToken asSymbol) notEmpty
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> isKeywordSelectorToken: aToken [
	"A token holding a colon and no space is read as a keyword selector on its own. A unary
	 selector cannot be told from an instance variable name, so this gate says nothing about one."

	^ (aToken includes: $:)
		and: [ (aToken includes: Character space) not ]
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> isPragmaOfADocumentedPackage: aSelector [
	"A pragma exists when a method of a code package of this project carries it, or when some
	 class answers it: the compiler reads a pragma, it does not implement one."

	(self documentedPackages anySatisfy: [ :package |
		 package methods anySatisfy: [ :method |
			 method pragmas anySatisfy: [ :pragma |
				 pragma selector = aSelector asSymbol ] ] ]) ifTrue: [ ^ true ].
	^ (SystemNavigation default allImplementorsOf: aSelector asSymbol) notEmpty
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> isQualifiedSelectorToken: aToken [
	"A token of the form Class >> selector, or Class class >> selector, names one method."

	^ aToken includesSubstring: self qualifiedSelectorSeparator
]

{ #category : 'private - tokenising' }
PVDocumentationTest >> pragmaSelectorOf: aToken [
	"Answer the selector a token written <like:this:> names, or nil when it is not a pragma."

	^ ((aToken beginsWith: '<') and: [ aToken endsWith: '>' ])
		  ifTrue: [ aToken allButFirst allButLast ]
		  ifFalse: [ nil ]
]

{ #category : 'private - constants' }
PVDocumentationTest >> qualifiedSelectorSeparator [
	^ ' >> '
]

{ #category : 'private - constants' }
PVDocumentationTest >> repositoryName [
	^ 'PharoVulkan'
]

{ #category : 'private - document' }
PVDocumentationTest >> skipTheDocumentIsAbsent [
	"The document is a file of the repository; an image that loaded the project from Metacello
	 has none, and these gates say nothing there."

	^ self skip: 'there is no checkout of ' , self repositoryName , ' in this image'
]

{ #category : 'private - constants' }
PVDocumentationTest >> suffixOfATestPackage [
	"Not named testPackageSuffix: SUnit collects every zero-argument selector beginning with
	 'test' as a test, so that name made this constant a phantom test case."

	^ '-Tests'
]

{ #category : 'tests - names' }
PVDocumentationTest >> testEveryExemptedNameIsStillAbsentFromTheImage [
	"An exemption says the image must not hold the name. Once the image holds it, the exemption
	 hides a real check, so the list is held to its own reason."

	| present |
	present := self class namesTheImageNeedNotHold select: [ :each |
		          Smalltalk includesKey: each asSymbol ].
	self
		assert: present isEmpty
		description: 'exempted, but the image holds them now: ' , present asArray printString
]

{ #category : 'tests - names' }
PVDocumentationTest >> testEveryMethodTheArchitectureDocumentNamesIsImplementedByThatClass [
	| contents missing |
	contents := self architectureDocumentContents ifNil: [ ^ self skipTheDocumentIsAbsent ].
	missing := ((self backtickedTokensOf: contents)
		select: [ :each | self isQualifiedSelectorToken: each ])
			reject: [ :each | self isImplementedMethodToken: each ].
	self
		assert: missing isEmpty
		description: 'named by the document, not answered by that class: '
			, missing asSet asSortedCollection asArray printString
]

{ #category : 'tests - names' }
PVDocumentationTest >> testEveryNameTheArchitectureDocumentBackticksExists [
	| contents unknown |
	contents := self architectureDocumentContents ifNil: [ ^ self skipTheDocumentIsAbsent ].
	unknown := ((self backtickedTokensOf: contents)
		select: [ :each | self isClassNameToken: each ])
			reject: [ :each | self architectureDocumentMayName: each ].
	self
		assert: unknown isEmpty
		description: 'named by the document, absent from the image: '
			, unknown asSet asSortedCollection asArray printString
]

{ #category : 'tests - names' }
PVDocumentationTest >> testEverySelectorTheArchitectureDocumentNamesOnItsOwnIsImplemented [
	| contents missing |
	contents := self architectureDocumentContents ifNil: [ ^ self skipTheDocumentIsAbsent ].
	missing := ((self backtickedTokensOf: contents)
		select: [ :each |
			(self isKeywordSelectorToken: each)
				and: [ (self isQualifiedSelectorToken: each) not ] ])
			reject: [ :each | self isImplementedSelectorToken: each ].
	self
		assert: missing isEmpty
		description: 'named by the document, implemented nowhere: '
			, missing asSet asSortedCollection asArray printString
]

{ #category : 'tests - reporting' }
PVDocumentationTest >> testTheDocumentReportTheViewShowsAgreesWithTheGates [
	"The Document claims view reads documentReport. It must hold one row per backticked token and
	 no row the gates above would call a failure, or the view would say the document is sound
	 where a gate says it is not."

	| contents report |
	contents := self architectureDocumentContents ifNil: [ ^ self skipTheDocumentIsAbsent ].
	report := self class documentReport.
	self assert: report size equals: (self backtickedTokensOf: contents) size.
	self
		assert: (report allSatisfy: [ :each | each third ])
		description: 'these rows contradict the gates: '
			, (report reject: [ :each | each third ]) printString
]

{ #category : 'tests - names' }
PVDocumentationTest >> testTheGateRejectsANameAndAMethodTheImageDoesNotHave [
	"The gates above pass; this says they can fail, which is what makes them worth running."

	self deny: (self architectureDocumentMayName: 'PVNoSuchClassOfThisProject').
	self deny: (self isImplementedMethodToken: 'VkContext >> noSuchSelectorHere').
	self deny: (self isImplementedMethodToken: 'PVNoSuchClassOfThisProject >> spirv').
	self deny: (self isImplementedSelectorToken: 'noSuchSelector:ofThisProject:').
	self deny: (self isImplementedSelectorToken: '<noSuchPragma:ofThisProject:>').
	self deny: (self isClassNameToken: 'PharoVulkan-Compute').
	self assert: (self architectureDocumentMayName: 'VkContext').
	self assert: (self architectureDocumentMayName: 'PharoVulkan-Compute').
	self assert: (self isImplementedMethodToken: 'PVSpirvKernel >> spirv').
	self assert: (self isImplementedSelectorToken: '<param:named:>')
]

{ #category : 'tests - tokeniser' }
PVDocumentationTest >> testTheTokeniserReadsBackticksOutsideAFenceAndNothingInsideOne [
	| document |
	document := String cr join: #(
		'Text naming `VkContext` and `nothing closed here'
		'```'
		'`InsideAFence` is a drawing, not a claim'
		'```'
		'and `SpvBuilder` after it' ).
	self
		assert: (self backtickedTokensOf: document) asArray
		equals: #( 'VkContext' 'SpvBuilder' )
]
