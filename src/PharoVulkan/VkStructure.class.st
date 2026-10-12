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
	 Every structure declared field by field answers it, so a layout test and the Layout tab
	 both read what uFFI really compiled."

	| spec |
	spec := self fieldSpec.
	^ spec fieldNames with: spec types collect: [ :fieldName :type |
		  {
			  fieldName.
			  (self classVariableNamed: (self offsetVariableNameFor: fieldName)) value - 1.
			  type externalTypeSize } ]
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
