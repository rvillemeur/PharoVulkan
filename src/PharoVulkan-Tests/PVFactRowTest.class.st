"
I cover PVFactRow, the row every two-column inspector view of this project shows, and the table it builds from a collection of rows. I live in the aggregate test package because the class I cover belongs to no layer: Bindings, SPIR-V, the compiler, the lifecycle, the compute path and the graphics path all build rows.
"
Class {
	#name : 'PVFactRowTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Tests',
	#package : 'PharoVulkan-Tests',
	#tag : 'Tests'
}

{ #category : 'tests' }
PVFactRowTest >> testAFactRowAnswersAValueThatIsNotAStringAsOne [
	"The table column shows strings, so the row converts once instead of every view writing
	 asString at the point it builds the row."

	self assert: (PVFactRow name: 'Words' value: 256) value equals: '256'.
	self assert: (PVFactRow name: 'Handle' value: nil) value equals: 'nil'.
	self assert: (PVFactRow name: #Live value: true) name equals: 'Live'
]

{ #category : 'tests' }
PVFactRowTest >> testAFactRowAnswersTheNameAndTheValueItWasBuiltWith [
	| row |
	row := PVFactRow name: 'Bytes written' value: '1024'.
	self assert: row name equals: 'Bytes written'.
	self assert: row value equals: '1024'
]

{ #category : 'tests' }
PVFactRowTest >> testAFactRowRefusesToBeChanged [
	"A view must not change the object it describes, and the rows it shows are read by a
	 table that could write to them. The dictionaries this class replaced carried
	 beReadOnlyObject for that reason, so the row keeps the guarantee. The attempt goes
	 through the initialiser, because the row publishes no setter to try."

	| row |
	row := PVFactRow name: 'Scope' value: 3.
	self assert: row isReadOnlyObject.
	self
		should: [ row setName: 'Scope' value: 'four' ]
		raise: ModificationForbidden
]

{ #category : 'tests' }
PVFactRowTest >> testATableOfFactRowsTitlesItsColumnsAndReadsTheRows [
	"A column block runs once per drawn row, so the test sends it a row itself rather than
	 waiting for a window to draw."

	| rows table |
	rows := {
		        (PVFactRow name: 'Words' value: 7).
		        (PVFactRow name: 'Whole words' value: true) }.
	table := PVFactRow
		         tableOf: rows
		         nameColumn: 'Property'
		         valueColumn: 'Value'
		         in: (SpPresenterBuilder newApplication: SpApplication new).
	self
		assert: (table columns collect: [ :each | each title ])
		equals: #( 'Property' 'Value' ).
	self assert: table items equals: rows.
	self
		assert: ((table columns collect: [ :each |
				  each evaluation value: rows first ]) asArray)
		equals: #( 'Words' '7' )
]

{ #category : 'tests' }
PVFactRowTest >> testTheViewOfARowDrawsThatRowInTheTableTheProjectDeclares [
	"A row is a table line, so its own tab must show it the way every other tab shows one:
	 through the project's single table declaration, with the row itself as the only item."

	| row table |
	row := PVFactRow name: 'Words' value: 7.
	table := row inspectorRow: (SpPresenterBuilder newApplication: SpApplication new).
	self assert: table items asArray equals: { row }.
	self
		assertCollection: (table columns collect: [ :each | each title ])
		hasSameElements: #( 'Name' 'Value' )
]
