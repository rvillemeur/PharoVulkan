"
States which packages of this project are allowed to name classes of which other packages, and
fails when a method names one outside its own package's allowed set. The sets are declared on the
class side, so adding an edge means writing it down rather than discovering it later.

The scan reads the literals of every method a package owns, and recursively the literals of every
block inside them, because most driver calls in this project sit inside an ensure: block: a scan
of method literals alone missed 86 edges when this split was planned. It asks each package for
its methods rather than for its classes, because a package also owns the methods it adds to
classes it does not define, and those are where unit 8's rename hid two cross-layer references.

Key methods: allowedDependencies, edgesOf:, packagesNamedBy:.
"
Class {
	#name : 'PVArchitectureTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Tests',
	#package : 'PharoVulkan-Tests',
	#tag : 'Tests'
}

{ #category : 'dependencies' }
PVArchitectureTest class >> allowedDependencies [
	"The outgoing package references each package of this project may make, keyed by package
	 name. This table is the agreement: a package missing from it is one nobody has placed in
	 the layering, and an edge missing from a set is a dependency nobody has agreed to. The
	 tests below fail on either, so adding a dependency means stating it here first."

	^ Dictionary newFrom: {
		  'PharoVulkan-Bindings' -> #( 'PharoVulkan-Inspector' ).
		  'PharoVulkan-SPIRV' -> #( 'PharoVulkan-Inspector' ).
		  "The row every two-column inspector view shows belongs to no layer, so it sits in a
		   package that reaches nothing and that every other package may reach. Without it a
		   shared row class would have to live in Bindings or in SPIRV, and the two packages
		   that reach nothing would start reaching each other."
		  'PharoVulkan-Inspector' -> #(  ).
		  'PharoVulkan-Compiler' -> #( 'PharoVulkan-Inspector' 'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Core' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Inspector'
			   'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Compute' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Compiler'
			   'PharoVulkan-Core' 'PharoVulkan-Inspector' 'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Graphics' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Compiler'
			   'PharoVulkan-Compute' 'PharoVulkan-Core' 'PharoVulkan-Inspector'
			   'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Generator' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Examples' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Compiler'
			   'PharoVulkan-Compute' 'PharoVulkan-Core' 'PharoVulkan-Graphics'
			   'PharoVulkan-Inspector' 'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Bindings-Tests' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Compute'
			   'PharoVulkan-Core' 'PharoVulkan-Examples' 'PharoVulkan-Generator'
			   'PharoVulkan-Graphics' 'PharoVulkan-Inspector' ).
		  "No edge to Core here since point 10: SpvEmitterTest built a VkContext to dispatch the
		   module it emitted from the dead IR layer, and it went with that layer."
		  'PharoVulkan-SPIRV-Tests' -> #( 'PharoVulkan-Compute' 'PharoVulkan-Examples'
			   'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Compiler-Tests' -> #( 'PharoVulkan-Compiler' 'PharoVulkan-Compute'
			   'PharoVulkan-Examples' 'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Core-Tests' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Compute'
			   'PharoVulkan-Core' 'PharoVulkan-Examples' 'PharoVulkan-SPIRV' ).
		  "The edge to the compiler tests is the one edge this project allows between two test
		   packages: a compute test reads their control flow fixture rather than keeping a
		   second copy of it."
		  'PharoVulkan-Compute-Tests' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Compiler'
			   'PharoVulkan-Compiler-Tests' 'PharoVulkan-Compute' 'PharoVulkan-Core'
			   'PharoVulkan-Examples' 'PharoVulkan-SPIRV' ).
		  'PharoVulkan-Graphics-Tests' -> #( 'PharoVulkan-Bindings' 'PharoVulkan-Compiler'
			   'PharoVulkan-Compute' 'PharoVulkan-Core' 'PharoVulkan-Examples'
			   'PharoVulkan-Graphics' 'PharoVulkan-Inspector' ).
		  "The aggregate package holds this test and its fixtures. Its edges are the class the
		   planted fixture names and the inspector row, which belongs to no layer and so is
		   covered here rather than in a test package of its own."
		  'PharoVulkan-Tests' -> #( 'PharoVulkan-Core' 'PharoVulkan-Inspector' ) }
]

{ #category : 'reporting' }
PVArchitectureTest class >> dependencyReport [
	"One row per package of this project: its name, the edges allowedDependencies grants it,
	 and the edges it really makes. Both sides are computed here, so a reader of the report and
	 the tests below cannot be looking at different numbers."

	^ self projectPackageNames asSortedCollection asArray collect: [ :each |
		  { 
			  each.
			  (self packageNameSeparator join:
					   (self allowedDependencies at: each ifAbsent: [ #(  ) ])
						   asSortedCollection).
			  (self packageNameSeparator join: (self edgesOf: each) asSortedCollection) } ]
]

{ #category : 'scanning' }
PVArchitectureTest class >> edgesOf: aPackageName [
	"The packages aPackageName's own methods name, itself excluded."

	| package found |
	package := PackageOrganizer default packageNamed: aPackageName.
	found := Set new.
	package methods do: [ :method |
		found addAll: (self packagesNamedBy: method) ].
	^ found copyWithout: aPackageName
]

{ #category : 'inspector' }
PVArchitectureTest class >> inspectorDependencies: aBuilder [
	"Declared and actual outgoing edges side by side, for every package of this project. Reads
	 dependencyReport, so the view states what the table and a live scan say rather than a
	 stored summary, and it mutates nothing it shows."

	<inspectorPresentationOrder: 10 title: 'Dependencies'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Package' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn
				   title: 'Declared'
				   evaluated: [ :each | each second ]);
		  addColumn: (SpStringTableColumn title: 'Actual' evaluated: [ :each | each third ]);
		  items: self dependencyReport;
		  yourself
]

{ #category : 'constants' }
PVArchitectureTest class >> packageNameSeparator [
	"What dependencyReport puts between two package names inside one table cell."

	^ ', '
]

{ #category : 'scanning' }
PVArchitectureTest class >> packagesNamedBy: aCompiledMethod [
	"The packages of this project whose classes aCompiledMethod names, reading the literals of
	 every block inside it as well as its own, to any depth."

	| found scan |
	found := Set new.
	scan := nil.
	scan := [ :compiled |
	        compiled literals do: [ :literal |
		        literal isVariableBinding
			        ifTrue: [
				        literal value isBehavior ifTrue: [
					        literal value instanceSide package ifNotNil: [ :package |
						        (package name beginsWith: self projectPackageNamePrefix)
							        ifTrue: [ found add: package name asString ] ] ] ]
			        ifFalse: [
				        literal class = CompiledBlock ifTrue: [ scan value: literal ] ] ] ].
	scan value: aCompiledMethod.
	^ found
]

{ #category : 'scanning' }
PVArchitectureTest class >> projectPackageNamePrefix [
	^ 'PharoVulkan'
]

{ #category : 'scanning' }
PVArchitectureTest class >> projectPackageNames [
	"Every package of this project, asked of the organiser so that a package added tomorrow is
	 covered by the coverage test below rather than silently unscanned."

	^ ((PackageOrganizer default packages select: [ :each |
		    each name beginsWith: self projectPackageNamePrefix ]) collect: [ :each |
		   each name asString ]) asSet
]

{ #category : 'asserting' }
PVArchitectureTest >> assertEdgesOfPackageNamed: aPackageName [
	"Fail naming every method that makes a reference allowedDependencies does not grant. A bare
	 package name would say that the layering broke without saying where to look for it. The
	 class name is asked for as a string, because a symbol would carry its quoting into the
	 failure message."

	| allowed strays |
	allowed := (self class allowedDependencies at: aPackageName) asSet.
	strays := Set new.
	(PackageOrganizer default packageNamed: aPackageName) methods do: [ :method |
		((self class packagesNamedBy: method) copyWithout: aPackageName) do: [ :each |
			(allowed includes: each) ifFalse: [
				strays add: method methodClass name asString , ' >> '
					, method selector asString , ' -> ' , each ] ] ].
	self assert: strays asSortedCollection asArray equals: #(  )
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testBindingsStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Bindings'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testBindingsTestsStayInsideTheirAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Bindings-Tests'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testCompilerStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Compiler'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testCompilerTestsStayInsideTheirAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Compiler-Tests'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testComputeStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Compute'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testComputeTestsStayInsideTheirAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Compute-Tests'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testCoreStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Core'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testCoreTestsStayInsideTheirAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Core-Tests'
]

{ #category : 'tests - declaring' }
PVArchitectureTest >> testEveryAllowedDependencyIsDeclaredInTheBaseline [
	"A package can load only what the baseline says it needs. An edge the table grants but the
	 baseline leaves out works in this image, where every package is present already, and fails
	 for whoever loads the project one group at a time."

	| declared missing |
	declared := Dictionary new.
	BaselineOfPharoVulkan project version packages do: [ :each |
		declared at: each name put: each requires asSet ].
	missing := Set new.
	self class allowedDependencies keysAndValuesDo: [ :package :allowed |
		allowed do: [ :each |
			((declared at: package ifAbsent: [ Set new ]) includes: each) ifFalse: [
				missing add: package , ' -> ' , each ] ] ].
	self assert: missing asSortedCollection asArray equals: #(  )
]

{ #category : 'tests - declaring' }
PVArchitectureTest >> testEveryAllowedDependencyIsOneThePackageReallyMakes [
	"A dependency that stopped being real has to come out of the table, or the table stops
	 describing the code and starts describing its history."

	| stale |
	stale := Set new.
	self class allowedDependencies keysAndValuesDo: [ :package :allowed |
		| actual |
		actual := self class edgesOf: package.
		allowed do: [ :each |
			(actual includes: each) ifFalse: [ stale add: package , ' -> ' , each ] ] ].
	self assert: stale asSortedCollection asArray equals: #(  )
]

{ #category : 'tests - declaring' }
PVArchitectureTest >> testEveryAllowedDependencyNamesAPackageOfThisProject [
	"A renamed package leaves its old name behind in the table, where it would silently grant
	 nothing and hide the edge that replaced it."

	| strays |
	strays := Set new.
	self class allowedDependencies keysAndValuesDo: [ :package :allowed |
		allowed do: [ :each |
			(self class projectPackageNames includes: each) ifFalse: [
				strays add: package , ' -> ' , each ] ] ].
	self assert: strays asSortedCollection asArray equals: #(  )
]

{ #category : 'tests - conventions' }
PVArchitectureTest >> testEveryClassCommentOfThisProjectIsCrOnly [
	"CLAUDE.md forbids LF in Pharo source, and every method source of the project obeys. A
	 class comment is source too, so a comment holding an LF breaks the same rule — invisibly,
	 because Tonel writes both line endings as LF on disk. The check is therefore in the image
	 and nowhere else."

	| commented offenders |
	commented := OrderedCollection new.
	offenders := OrderedCollection new.
	self class projectPackageNames do: [ :each |
		(PackageOrganizer default packageNamed: each) definedClasses do: [ :cls |
			cls comment ifNotNil: [ :text |
				commented add: cls name.
				(text includes: Character lf) ifTrue: [ offenders add: cls name asString ] ] ] ].
	"A mistyped query would leave nothing to scan and pass in silence."
	self deny: commented isEmpty.
	self assertEmpty: offenders asSortedCollection asArray
]

{ #category : 'tests - declaring' }
PVArchitectureTest >> testEveryPackageOfThisProjectHasADeclaredAllowedSet [
	"A package added tomorrow goes unscanned until it appears in the table, so the table is
	 checked against the organiser rather than against a list written out by hand."

	self
		assert: self class allowedDependencies keys asSortedCollection asArray
		equals: self class projectPackageNames asSortedCollection asArray
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testExamplesStayInsideTheirAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Examples'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testGeneratorStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Generator'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testGraphicsStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Graphics'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testGraphicsTestsStayInsideTheirAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Graphics-Tests'
]

{ #category : 'tests - rules' }
PVArchitectureTest >> testNoProjectMethodWritesTheModulePrologueAsANumber [
	"The project forbids a magic value, and the SPIR-V capability, addressing model and
	 memory model are the case CLAUDE.md names. A method that passes one of them as a bare
	 number has written the specification's value into the emitting code, where nothing says
	 which value it is. A capability named by its symbol, #Shader, is the specification's own
	 name and is allowed."

	| prologue senders offenders |
	prologue := #( #addCapability: #setAddressingModel:memoryModel: #setMemoryModel:memoryModel: ).
	senders := OrderedCollection new.
	offenders := OrderedCollection new.
	self class projectPackageNames do: [ :each |
		((self class environment at: #PackageOrganizer) default packageNamed: each) methods do: [ :method |
			(method ast allChildren select: [ :node |
				 node isMessage and: [ prologue includes: node selector ] ]) do: [ :node |
				senders add: method.
				(node arguments anySatisfy: [ :argument |
					 argument isLiteralNode and: [ argument value isNumber ] ]) ifTrue: [
					offenders add:
						method methodClass name , ' >> ' , method selector ] ] ] ].
	"A mistyped selector would leave nothing to scan and pass in silence."
	self deny: senders isEmpty.
	self assertEmpty: offenders asSortedCollection asArray
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testSpirvStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-SPIRV'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testSpirvTestsStayInsideTheirAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-SPIRV-Tests'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testTheAggregateTestPackageStaysInsideItsAllowedDependencies [

	self assertEdgesOfPackageNamed: 'PharoVulkan-Tests'
]

{ #category : 'tests - layering' }
PVArchitectureTest >> testTheInspectorPackageStaysInsideItsAllowedDependencies [
	"The row every two-column view shows reaches no package of this project, which is what
	 lets every package reach it."

	self assertEdgesOfPackageNamed: 'PharoVulkan-Inspector'
]

{ #category : 'tests - scanning' }
PVArchitectureTest >> testTheScanReadsAReferencePlantedInsideANestedBlock [
	"The scan must read the literals of every block inside a method, at any depth. A scan of a
	 method's own literals alone missed 86 edges when this split was planned, and most driver
	 calls in this project sit inside an ensure: block, so the blind spot would pass exactly the
	 code it is meant to watch. PVNestedBlockReferenceFixture names VkDevice three blocks deep and
	 nowhere else."

	self
		assert: (self class packagesNamedBy:
				 PVNestedBlockReferenceFixture >> #reachThroughThreeBlocks)
		equals: (Set with: VkDevice package name asString)
]
