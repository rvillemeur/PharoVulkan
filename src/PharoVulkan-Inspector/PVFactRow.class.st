"
I am one line of a two-column inspector table: a fact's name and its value, both as strings. Every inspector view of this project that shows a list of named facts builds a collection of me and hands it to `PVFactRow class >> tableOf:nameColumn:valueColumn:in:`, which is the one place the two columns are declared. Before I existed, nine classes carried a `rowNamed:value:` helper of their own and the other views built dictionaries keyed `#name` and `#value` inline, so the row convention was written out sixty-four times. I convert the value with `asString` once, in `name:value:`, because the table column shows strings and the alternative is an `asString` at every call site. I belong to no layer of the project, which is why I live in a package of my own that reaches nothing and that every other package may reach.
"
Class {
	#name : 'PVFactRow',
	#superclass : 'Object',
	#instVars : [
		'name',
		'value'
	],
	#category : 'PharoVulkan-Inspector',
	#package : 'PharoVulkan-Inspector'
}

{ #category : 'instance creation' }
PVFactRow class >> name: aName value: aValue [
	"Both arguments are converted here, so that a view can pass a number, a boolean or nil
	 straight from the object it describes. The row is read only because a table is given it
	 to draw, and drawing a fact must not be able to change it."

	^ (self new setName: aName asString value: aValue asString) beReadOnlyObject
]

{ #category : 'presenting' }
PVFactRow class >> tableOf: aCollectionOfRows nameColumn: aNameTitle valueColumn: aValueTitle in: aBuilder [
	"The one declaration of the two-column fact table this project shows. A view answers
	 this and nothing else, so a change of column behaviour is a change in one method."

	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: aNameTitle evaluated: [ :row | row name ]);
		  addColumn:
			  (SpStringTableColumn title: aValueTitle evaluated: [ :row | row value ]);
		  items: aCollectionOfRows;
		  yourself
]

{ #category : 'inspector' }
PVFactRow >> inspectorRow: aBuilder [
	"The row as a reader meets it everywhere else: one line of the two-column table this
	 class declares. It goes through that declaration rather than restating the columns, so
	 the tab cannot show a shape the sixty-four views do not."

	<inspectorPresentationOrder: 10 title: 'Row'>
	^ self class
		  tableOf: { self }
		  nameColumn: 'Name'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing' }
PVFactRow >> name [
	^ name
]

{ #category : 'printing' }
PVFactRow >> printOn: aStream [
	aStream
		nextPutAll: name;
		nextPutAll: ': ';
		nextPutAll: value
]

{ #category : 'initialization' }
PVFactRow >> setName: aName value: aValue [
	name := aName.
	value := aValue
]

{ #category : 'evaluating' }
PVFactRow >> value [
	^ value
]
