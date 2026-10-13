"
Base class for all Vulkan struct types. Includes VkTypes shared pool for
fixed-size array field types (Uint8_256, etc.). Subclasses define field layout via fieldsDesc.
Subclasses whose struct has an sType field must override initialize to set it.
Key methods: fieldsDesc (class-side, subclass responsibility), initialize.
"
Class {
	#name : 'VkStructure',
	#superclass : 'FFIExternalStructure',
	#pools : [
		'VkTypes'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'instance creation' }
VkStructure class >> externalInstance [
	"An instance whose store is memory outside the image, so its address is stable while a
	 driver holds a pointer to it. ExternalAddress allocate: is malloc, so the block arrives
	 holding whatever was there and is zeroed: a field the driver never writes must read as
	 zero, or a flag it did not set could look set. The caller frees getHandle."

	| address |
	address := ExternalAddress allocate: self byteSize.
	1 to: self byteSize do: [ :i | address byteAt: i put: 0 ].
	^ self fromHandle: address
]

{ #category : 'layout' }
VkStructure class >> headByteCount [
	"Enough bytes to recognise a field in a table row, few enough that the long array fields do
	 not push the other columns off the view."
	^ 8
]

{ #category : 'layout' }
VkStructure class >> layoutRows [
	"The layout read back from the field specification the class compiled, never a second copy
	 of the declaration: name, byte offset and byte count per field. uFFI keeps offsets as
	 one based indices into the store, so each one is shifted to the C offset the driver uses.
	 A pointer field occupies a pointer, not the thing it points at: FFIExternalStructureType
	 answers the pointed to structure's size for externalTypeSize, which would report a
	 pointer to a twenty four byte struct as twenty four bytes wide and overlap the field after
	 it. Every structure declared field by field answers this, so a layout test and the Layout
	 tab both read what uFFI really compiled."

	| spec |
	spec := self fieldSpec.
	^ spec fieldNames with: spec types collect: [ :fieldName :type |
		  {
			  fieldName.
			  (self classVariableNamed: (self offsetVariableNameFor: fieldName)) value - 1.
			  (type isPointer
				   ifTrue: [ ExternalAddress wordSize ]
				   ifFalse: [ type externalTypeSize ]) } ]
]

{ #category : 'labels' }
VkStructure class >> nullLabel [
	"A pointer field is reported as set or not set rather than as an address: the address tells
	 a reader nothing and differs on every run."
	^ 'not set'
]

{ #category : 'labels' }
VkStructure class >> setLabel [
	^ 'set'
]

{ #category : 'labels' }
VkStructure class >> structureTypeNameFor: aValue [
	"Found by asking VkStructureType which of its own constants answers the value the store
	 holds, so a field report names the type the driver will read rather than restating a
	 constant here. A value no constant answers is shown as the number it is."
	^ (VkStructureType class selectors
		   detect: [ :each |
			   (VkStructureType class >> each) numArgs = 0 and: [
				   (VkStructureType perform: each) = aValue ] ]
		   ifNone: [ ^ aValue printString ]) asString
]

{ #category : 'copying' }
VkStructure >> copyIntoObjectMemory [
	"A copy whose store is a ByteArray inside the image, for a structure the driver filled in
	 memory that is about to be freed. A carried over pNext would point into memory already
	 given back, so a chained structure's chain pointer is cleared; one without pNext has
	 nothing to clear."

	| kept |
	kept := self class new.
	1 to: self class byteSize do: [ :i |
		kept getHandle at: i put: (self getHandle byteAt: i) ].
	(kept respondsTo: #pNext:) ifTrue: [ kept pNext: ExternalAddress null ].
	^ kept
]

{ #category : 'reporting' }
VkStructure >> describeField: aFieldName value: aValue [
	"What a field report shows for one field. A structure type is named by asking
	 VkStructureType, a number is itself, a pointer is reported as set or not set, and anything
	 else — a fixed size array field, for instance — prints itself."

	aFieldName = #sType ifTrue: [
		^ self class structureTypeNameFor: aValue ].
	aValue isNumber ifTrue: [ ^ aValue printString ].
	(aValue respondsTo: #isNull) ifFalse: [ ^ aValue printString ].
	^ aValue isNull
		  ifTrue: [ self class nullLabel ]
		  ifFalse: [ self class setLabel ]
]

{ #category : 'reporting' }
VkStructure >> fieldReport [
	"What this structure says, field by field, read through the accessors uFFI generated for
	 it. The rows come from the compiled field specification rather than from a list kept
	 anywhere, so a field added to fieldsDesc appears by itself and the report cannot name a
	 field the struct does not have. A field whose accessor was never generated is left out
	 rather than failing, because a class may compile its offsets without accessors. Reading
	 only, so a report built on a filled in structure leaves its bytes alone."

	^ (self class layoutRows
		   select: [ :row | self respondsTo: row first ])
		  collect: [ :row |
			  | fieldName |
			  fieldName := row first.
			  {
				  fieldName asString.
				  (self describeField: fieldName value: (self perform: fieldName)) } ]
]

{ #category : 'layout' }
VkStructure >> headOfFieldAt: anOffset size: aSize [
	"The first bytes of a field as this instance's store really holds them. A field longer than
	 the shown head ends in an ellipsis, so a row cannot read as if the field were that short."

	| store shown |
	store := self getHandle.
	shown := aSize min: self class headByteCount.
	^ String streamContents: [ :out |
		  (1 to: shown)
			  do: [ :i |
				  out nextPutAll: ((store at: anOffset + i) printPaddedWith: $0 to: 2 base: 16) ]
			  separatedBy: [ out space ].
		  aSize > shown ifTrue: [ out nextPutAll: ' ...' ] ]
]

{ #category : 'initialization' }
VkStructure >> initialize [
	"FFIStructure class >> fromHandle: sends this after setting the store, and uFFI's generated
	 getter for a field that points at another structure answers that structure through
	 fromHandle:, so initialize runs on every read of such a field — over the pointee's store,
	 or over a null pointer when nobody has set it. Nothing may be written in that case, so the
	 writes live in initializeConstantFields, which runs only over a real store. What goes
	 there must also be constant for the type, such as sType: writing a data field would change
	 a pointee on a read."

	super initialize.
	self getHandle isNull ifTrue: [ ^ self ].
	self initializeConstantFields
]

{ #category : 'initialization' }
VkStructure >> initializeConstantFields [
	"The fields whose value is fixed by the structure's type rather than by a caller, written
	 once over a real store. A structure with no such field — one without sType — needs
	 nothing here. Subclasses override this rather than initialize, so the null store case is
	 handled in one place and a read of a pointer field cannot write."

	^ self
]

{ #category : 'inspector' }
VkStructure >> inspectorFields: aBuilder [
	"What each field says, in Vulkan's terms rather than in bytes: the Layout tab shows where
	 every field sits, this one shows what it holds. Every row is read back through the
	 generated accessors, so the tab cannot claim a value the struct does not hold, and nothing
	 is written. Every structure declared field by field answers it, which is why it lives
	 here and not on one subclass."

	<inspectorPresentationOrder: 20 title: 'Fields'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Field' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Says' evaluated: [ :each |
					   each second ]);
		  items: self fieldReport;
		  yourself
]

{ #category : 'inspector' }
VkStructure >> inspectorLayout: aBuilder [
	"Every row is read back from the compiled field specification and from this instance's own
	 store, so the table cannot state a layout the struct does not have. The store is only read,
	 never written, so inspecting a populated struct leaves its bytes alone. Every structure
	 declared field by field answers it, which is why it lives here and not on one subclass."

	<inspectorPresentationOrder: 10 title: 'Layout'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Field' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Offset' evaluated: [ :each |
					   each second printString ]);
		  addColumn: (SpStringTableColumn title: 'Bytes' evaluated: [ :each |
					   each third printString ]);
		  addColumn: (SpStringTableColumn title: 'Next offset' evaluated: [ :each |
					   (each second + each third) printString ]);
		  addColumn: (SpStringTableColumn title: 'Head' evaluated: [ :each |
					   self headOfFieldAt: each second size: each third ]);
		  items: self class layoutRows;
		  yourself
]
