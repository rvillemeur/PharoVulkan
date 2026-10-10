"
One M by N by K shape, with its component types, that a physical device offers for VK_KHR_cooperative_matrix. A cooperative matrix kernel cannot choose its own dimensions: it must name one of the combinations the device reports here, exactly, or the module is invalid on that device. Instances are decoded from the VkCooperativeMatrixPropertiesKHR entries that `VkPhysicalDevice >> cooperativeMatrixConfigurationsOn:` fetches. The byte offsets of those entries are computed from `fieldLayout` rather than written down, because a short or mis-aligned hand-written layout corrupts object memory silently.
"
Class {
	#name : 'VkCooperativeMatrixConfiguration',
	#superclass : 'Object',
	#instVars : [
		'mSize',
		'nSize',
		'kSize',
		'aType',
		'bType',
		'cType',
		'resultType',
		'saturatingAccumulation',
		'scope'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> byteSizeOf: aTypeSymbol [
	^ self memberByteSizes
		  at: aTypeSymbol
		  ifAbsent: [
		  VkError signal: 'No width declared for member type: ' , aTypeSymbol printString ]
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> componentTypeFieldNames [
	"The members whose value is a VkComponentTypeKHR rather than a plain number."
	^ #( aType bType cType resultType )
]

{ #category : 'examples' }
VkCooperativeMatrixConfiguration class >> exampleFirstConfigurationOfferedHere [
	"One click: the first cooperative matrix configuration any device on this machine offers.
	 Answers nil on a machine where no device reports the extension, which is a fact about
	 the machine rather than a failure. The Members tab shows what a kernel would have to
	 match exactly."
	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  ((Vk enumeratePhysicalDevices: context instance)
		   inject: OrderedCollection new
		   into: [ :all :handle |
			   all
				   addAll: ((VkPhysicalDevice on: handle)
						    cooperativeMatrixConfigurationsOn: context instance);
				   yourself ]) ifNotEmpty: [ :all | all first ] ifEmpty: [ nil ] ]
		  ensure: [ context destroy ]
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> fieldLayout [
	"The members of VkCooperativeMatrixPropertiesKHR, in the order vk.xml declares them.
	 Every offset and the total size are derived from this list, so no offset is hand-counted."
	^ {
		  (#sType -> #uint32).
		  (#pNext -> #pointer).
		  (#mSize -> #uint32).
		  (#nSize -> #uint32).
		  (#kSize -> #uint32).
		  (#aType -> #uint32).
		  (#bType -> #uint32).
		  (#cType -> #uint32).
		  (#resultType -> #uint32).
		  (#saturatingAccumulation -> #bool32).
		  (#scope -> #uint32) }
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> fieldOffsets [
	"Each member sits at the next multiple of its own width, which is how the C compiler the
	 driver was built with lays the structure out."
	| offsets next |
	offsets := Dictionary new.
	next := 0.
	self fieldLayout do: [ :each |
		| width |
		width := self byteSizeOf: each value.
		next := next roundUpTo: width.
		offsets at: each key put: next.
		next := next + width ].
	^ offsets
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> headerFieldNames [
	"The two members the caller writes before the query and never reads back: they carry the
	 structure's identity, not part of the configuration."
	^ #( sType pNext )
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> memberByteSizes [
	"For every type this structure uses, the width in bytes, which is also the alignment C
	 gives the member."
	^ Dictionary newFrom: {
			  (#uint32 -> 4).
			  (#bool32 -> 4).
			  (#pointer -> 8) }
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> memberFieldNames [
	"The members that carry the configuration itself, in layout order."
	^ (self fieldLayout reject: [ :each |
		   self headerFieldNames includes: each key ]) collect: [ :each | each key ]
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> offsetOf: aFieldName [
	^ self fieldOffsets
		  at: aFieldName
		  ifAbsent: [
		  VkError signal: 'No such member: ' , aFieldName printString ]
]

{ #category : 'instance creation' }
VkCooperativeMatrixConfiguration class >> prepareEntriesIn: aBuffer count: aCount [
	"The driver fills an entry only when the entry already carries its own sType, and it
	 follows pNext, so the whole block is zeroed first and then each sType word is written."
	| stride |
	stride := self structureByteSize.
	1 to: aCount * stride // 4 do: [ :word |
		aBuffer unsignedLongAt: word - 1 * 4 + 1 put: 0 ].
	0 to: aCount - 1 do: [ :index |
		aBuffer
			unsignedLongAt: index * stride + (self offsetOf: #sType) + 1
			put: VkStructureType cooperativeMatrixPropertiesKHR ]
]

{ #category : 'instance creation' }
VkCooperativeMatrixConfiguration class >> readAllFrom: aBuffer count: aCount [
	^ (1 to: aCount) collect: [ :index |
		  self readFrom: aBuffer at: index - 1 * self structureByteSize ]
]

{ #category : 'instance creation' }
VkCooperativeMatrixConfiguration class >> readFrom: aBuffer at: anOffset [
	"Copies one entry out of the block the driver filled, so the configuration survives the
	 free of that block."
	| configuration |
	configuration := self new.
	self memberFieldNames do: [ :fieldName |
		configuration
			instVarNamed: fieldName
			put: (aBuffer unsignedLongAt: anOffset + (self offsetOf: fieldName) + 1) ].
	^ configuration
]

{ #category : 'layout' }
VkCooperativeMatrixConfiguration class >> structureByteSize [
	"A structure is padded up to the alignment of its widest member, so the stride between
	 two entries in the array the driver fills is larger than the last member's end."
	| widest last |
	widest := (self fieldLayout collect: [ :each | self byteSizeOf: each value ]) max.
	last := self fieldLayout last.
	^ ((self offsetOf: last key) + (self byteSizeOf: last value)) roundUpTo: widest
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> aType [
	^ aType
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> bType [
	^ bType
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> cType [
	^ cType
]

{ #category : 'reporting' }
VkCooperativeMatrixConfiguration >> componentTypeNameOf: aValue [
	^ (VkComponentType nameOf: aValue) ifNil: [ aValue printString ]
]

{ #category : 'reporting' }
VkCooperativeMatrixConfiguration >> configurationRows [
	"Reflects over the layout, so a member added there appears here without this method
	 being touched."
	^ self class memberFieldNames collect: [ :name | self rowNamed: name ]
]

{ #category : 'reporting' }
VkCooperativeMatrixConfiguration >> description [
	^ String streamContents: [ :stream |
		  stream
			  nextPutAll: 'M';
			  print: mSize;
			  nextPutAll: ' N';
			  print: nSize;
			  nextPutAll: ' K';
			  print: kSize;
			  nextPutAll: ', ';
			  nextPutAll: (self componentTypeNameOf: aType);
			  nextPutAll: ' x ';
			  nextPutAll: (self componentTypeNameOf: bType);
			  nextPutAll: ' + ';
			  nextPutAll: (self componentTypeNameOf: cType);
			  nextPutAll: ' into ';
			  nextPutAll: (self componentTypeNameOf: resultType);
			  nextPutAll: ', ';
			  nextPutAll: (self meaningOf: #scope);
			  nextPutAll: ' scope' ]
]

{ #category : 'inspector' }
VkCooperativeMatrixConfiguration >> inspectorMembers: aBuilder [
	"Every member the layout declares, with the raw number the driver wrote beside the name
	 the Vulkan enumerations give it. The rows are reflected out of the layout and are read
	 only, so opening this tab cannot change the configuration."
	<inspectorPresentationOrder: 10 title: 'Members'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Member' evaluated: [ :each |
					   each at: #member ]);
		  addColumn: (SpStringTableColumn title: 'Raw' evaluated: [ :each |
					   (each at: #raw) printString ]);
		  addColumn: (SpStringTableColumn title: 'Meaning' evaluated: [ :each |
					   (each at: #meaning) printString ]);
		  items: self configurationRows;
		  yourself
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> kSize [
	^ kSize
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> mSize [
	^ mSize
]

{ #category : 'reporting' }
VkCooperativeMatrixConfiguration >> meaningOf: aFieldName [
	"The enumeration tables are asked rather than copied here, so a value this image has no
	 name for reads as the raw number instead of as a wrong name."
	aFieldName = #scope ifTrue: [
		^ (VkScope nameOf: scope) ifNil: [ scope printString ] ].
	(self class componentTypeFieldNames includes: aFieldName) ifTrue: [
		^ self componentTypeNameOf: (self instVarNamed: aFieldName) ].
	aFieldName = #saturatingAccumulation ifTrue: [ ^ self saturates ].
	^ nil
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> nSize [
	^ nSize
]

{ #category : 'printing' }
VkCooperativeMatrixConfiguration >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: ' ('; nextPutAll: self description; nextPut: $)
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> resultType [
	^ resultType
]

{ #category : 'reporting' }
VkCooperativeMatrixConfiguration >> rowNamed: aFieldName [
	| row |
	row := Dictionary new.
	row
		at: #member put: aFieldName;
		at: #raw put: (self instVarNamed: aFieldName);
		at: #meaning put: (self meaningOf: aFieldName).
	^ row beReadOnlyObject
]

{ #category : 'testing' }
VkCooperativeMatrixConfiguration >> saturates [
	^ saturatingAccumulation ~= 0
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> saturatingAccumulation [
	^ saturatingAccumulation
]

{ #category : 'accessing' }
VkCooperativeMatrixConfiguration >> scope [
	^ scope
]
