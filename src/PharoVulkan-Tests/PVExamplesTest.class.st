"
I hold the examples and the inspector views of this project to their shape. Every view must take
the presenter builder, since Pharo 13 refuses one that does not at the moment a reader opens the
object. Every <sampleInstance> must live in PharoVulkan-Examples, be a class-side method with no
argument so the browser runs it with one click, and sit on a holder with a class comment named
for a class the image holds.

No gate here runs an example. Many of them name the machine in their selector and need a
Vulkan driver, and four open a window, so a gate that ran examples would make this suite report
the machine it runs on rather than the code. An example that opens a window is named open... ,
and the gate below holds the naming both ways so that the ones no gate may run stay recognisable.
"
Class {
	#name : 'PVExamplesTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Tests',
	#package : 'PharoVulkan-Tests',
	#tag : 'Tests'
}

{ #category : 'reporting' }
PVExamplesTest class >> exampleReport [
	"One row per example of the project: its holder, its selector, whether it is one-click, and
	 whether it opens a window. Built by the gate''s own helpers, so the view says what the tests
	 assert; no example is run to build it."

	| gate opening |
	gate := self new.
	opening := gate examplesThatSendAWindowOpener.
	^ ((gate allExampleMethods collect: [ :each | 
		    { 
			    each methodClass instanceSide name.
			    each selector asString.
			    (each numArgs = 0 and: [ each methodClass isMeta ]).
			    (opening includes: each) } ]) asSortedCollection: [ :a :b | 
		   a first , a second <= (b first , b second) ]) asArray
]

{ #category : 'inspector' }
PVExamplesTest class >> inspectorExamples: aBuilder [
	"Every example of the project, its holder, whether the browser runs it with one click and
	 whether it opens a window. Reads exampleReport, which runs no example and mutates nothing."

	<inspectorPresentationOrder: 10 title: 'Examples'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Holder' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn title: 'Example' evaluated: [ :each | each second ]);
		  addColumn: (SpStringTableColumn
				   title: 'One click'
				   evaluated: [ :each | each third ifTrue: [ 'yes' ] ifFalse: [ 'no' ] ]);
		  addColumn: (SpStringTableColumn
				   title: 'Opens a window'
				   evaluated: [ :each | each fourth ifTrue: [ 'yes' ] ifFalse: [ 'no' ] ]);
		  items: self exampleReport;
		  yourself
]

{ #category : 'constants' }
PVExamplesTest class >> selectorsThatOpenAWindow [
	"The sends that put a window on screen. renderTriangle builds an SDL2 window and drives the
	 swapchain, and renderTriangleWith: is the lifecycle it shares with the examples that hand
	 back one object of the chain; open and openInWindow are Spec''s own. Declared here because
	 no predicate of the image answers ''does this open a window'', and read by the gate in both
	 directions, so an example that opens one and is misnamed fails, and a name that promises one
	 and opens none fails too."

	^ #( #renderTriangle #renderTriangleWith: #open #openInWindow #openModal )
]

{ #category : 'private - examples' }
PVExamplesTest >> allExampleMethods [
	"Every method of this project tagged <sampleInstance>, found by the pragma rather than by a
	 list, so an example written anywhere is covered the moment it is written."

	^ self projectPackages flatCollect: [ :package |
		  package methods select: [ :method |
			  method hasPragmaNamed: #sampleInstance ] ]
]

{ #category : 'private - constants' }
PVExamplesTest >> exampleHolderSuffix [
	^ 'Examples'
]

{ #category : 'private - examples' }
PVExamplesTest >> exampleHolders [
	"The classes of the examples package that hold an example, read from the pragma rather than
	 from a naming convention."

	^ (self examplesPackage definedClasses select: [ :each |
		   each class methods anySatisfy: [ :method |
			   method hasPragmaNamed: #sampleInstance ] ]) asArray
]

{ #category : 'private - packages' }
PVExamplesTest >> examplesPackage [
	^ PackageOrganizer default packageNamed: self examplesPackageName
]

{ #category : 'private - constants' }
PVExamplesTest >> examplesPackageName [
	^ 'PharoVulkan-Examples'
]

{ #category : 'private - examples' }
PVExamplesTest >> examplesThatSendAWindowOpener [
	"The examples whose body sends one of the window-opening selectors, read from the compiled
	 method''s messages rather than from its source, so a comment naming one is not counted."

	^ self allExampleMethods select: [ :each |
		  each messages anySatisfy: [ :selector |
			  self class selectorsThatOpenAWindow includes: selector ] ]
]

{ #category : 'private - packages' }
PVExamplesTest >> projectPackages [
	"Every package of this project, tests included: a view or an example written in the wrong
	 package must be found, not skipped."

	^ PackageOrganizer default packages select: [ :each |
		  each name beginsWith: self repositoryName , '-' ]
]

{ #category : 'private - constants' }
PVExamplesTest >> repositoryName [
	^ 'PharoVulkan'
]

{ #category : 'tests - examples' }
PVExamplesTest >> testAnExampleThatOpensAWindowIsNamedForItAndNoGateRunsIt [
	"An example that opens a window cannot run in a suite, so it is named for what it does and no
	 gate here runs it. The naming is held both ways: every example that sends a window opener
	 carries the prefix, and every example carrying the prefix sends one."

	| prefix opening |
	prefix := self windowExamplePrefix.
	opening := self examplesThatSendAWindowOpener.
	self
		assert: (opening allSatisfy: [ :each | each selector beginsWith: prefix ])
		description: 'these examples open a window and are not named for it: '
			, ((opening reject: [ :each | each selector beginsWith: prefix ]) collect: [ :each |
				   each methodClass name , ' >> ' , each selector ]) asArray printString.
	self
		assert: (self windowExampleMethods allSatisfy: [ :each | opening includes: each ])
		description: 'these examples are named for a window and open none: '
			, ((self windowExampleMethods reject: [ :each | opening includes: each ]) collect: [
				   :each | each methodClass name , ' >> ' , each selector ]) asArray printString
]

{ #category : 'tests - examples' }
PVExamplesTest >> testEveryExampleHolderHasAClassComment [
	"A holder is read from the browser, so it must say what its examples show."

	| silent |
	silent := (self exampleHolders reject: [ :each |
		           each hasComment and: [ each comment trimBoth isNotEmpty ] ]) collect: [ :each |
		          each name ].
	self
		assert: silent isEmpty
		description: 'these example holders have no class comment: '
			, silent asSortedCollection asArray printString
]

{ #category : 'tests - examples' }
PVExamplesTest >> testEveryExampleTakesNoArgumentAndIsOnTheClassSide [
	"An example is a class-side method with no argument, so the browser runs it with one click.
	 Anything else is a helper and must not carry the pragma."

	| wrong |
	wrong := (self allExampleMethods reject: [ :each |
		          each numArgs = 0 and: [ each methodClass isMeta ] ]) collect: [ :each |
		         each methodClass name , ' >> ' , each selector ].
	self
		assert: wrong isEmpty
		description: 'these are not one-click class-side examples: '
			, wrong asSortedCollection asArray printString
]

{ #category : 'tests - views' }
PVExamplesTest >> testEveryInspectorViewOfThisProjectTakesAPresenterBuilder [
	"Pharo hands an inspector view the presenter builder it must build with. A view that
	 instantiates a presenter itself is refused -- ''Inspections made without presenter builder
	 are no longer supported'' -- when a reader opens the object. The rule is read from
	 StInspectionContext rather than restated here, so it cannot drift from the inspector, and
	 each package''s own methods are read, so an extension method on a class of another package
	 is read too."

	| wrong |
	wrong := OrderedCollection new.
	self projectPackages do: [ :package |
		package methods do: [ :method |
			((method hasPragmaNamed: #inspectorPresentationOrder:title:) and: [ (
				  StInspectionContext new
					  methodSelector: method selector;
					  yourself) methodSelectorNeedsBuilder not ]) ifTrue: [
				wrong add: method methodClass name , ' >> ' , method selector ] ] ].
	self
		assert: wrong isEmpty
		description: 'these views take no presenter builder: ' , wrong asArray printString
]

{ #category : 'tests - examples' }
PVExamplesTest >> testEverySampleInstanceOfThisProjectLivesInTheExamplesPackage [
	"An example is read and run from the browser, so all of them sit in one package a reader can
	 open. One left on its subject is the drift point 12 found."

	| strays |
	strays := (self allExampleMethods reject: [ :each |
		           each package name = self examplesPackageName ]) collect: [ :each |
		          each methodClass name , ' >> ' , each selector ].
	self
		assert: strays isEmpty
		description: 'these examples live outside ' , self examplesPackageName , ': '
			, strays asSortedCollection asArray printString
]

{ #category : 'tests - reporting' }
PVExamplesTest >> testTheExampleReportTheViewShowsAgreesWithTheGates [
	"The Examples view reads exampleReport. It must hold one row per example, flag as one-click
	 exactly the examples the gate accepts, and flag as window-opening exactly the ones no gate
	 may run."

	| report flagged |
	report := self class exampleReport.
	self assert: report size equals: self allExampleMethods size.
	self assert: (report allSatisfy: [ :each | each third ]).
	flagged := (report select: [ :each | each fourth ]) collect: [ :each | each second ].
	self
		assert: flagged asSortedCollection asArray
		equals: ((self windowExampleMethods collect: [ :each | each selector asString ])
				 asSortedCollection asArray)
]

{ #category : 'tests - gates' }
PVExamplesTest >> testTheGateSeesTheViewsAndTheExamplesOfThisProject [
	"The five gates above all read a collection and assert that the wrong entries of it are none,
	 so a helper answering nothing would pass every one of them. This says the helpers really
	 find the views, the examples and the holders, and that a selector the project does not have
	 is not read as an example. The counts are floors, not equalities: an example added later
	 must not make this fail, an example deleted must. No class of a code package is named here:
	 the gates reach the packages through the organiser, which is what keeps this test package
	 from depending on the packages it reads."

	| views |
	views := self projectPackages inject: 0 into: [ :count :package |
		         count + (package methods count: [ :method |
			          method hasPragmaNamed: #inspectorPresentationOrder:title: ]) ].
	self assert: views >= 74.
	self assert: self allExampleMethods size >= 129.
	self assert: self exampleHolders size >= 21.
	self assert: self windowExampleMethods size equals: 4.
	self assert: (self windowExampleMethods allSatisfy: [ :each |
			 (self exampleHolders includes: each methodClass instanceSide)
				 and: [ each hasPragmaNamed: #sampleInstance ] ]).
	self deny: (self allExampleMethods anySatisfy: [ :each |
			 each selector = #noSuchExampleOfThisProject ])
]

{ #category : 'private - examples' }
PVExamplesTest >> windowExampleMethods [
	"The examples that open a window, which no gate may run: an error inside one opens a
	 debugger and the process serving the call answers nothing."

	^ self allExampleMethods select: [ :each |
		  each selector beginsWith: self windowExamplePrefix ]
]

{ #category : 'private - constants' }
PVExamplesTest >> windowExamplePrefix [
	^ 'open'
]
