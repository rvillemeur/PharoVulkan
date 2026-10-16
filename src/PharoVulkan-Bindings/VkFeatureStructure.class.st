"
Abstract superclass of the device feature structures: a chain header (`sType`, `pNext`) followed by a run of VkBool32 flags. A concrete subclass declares its fields in `fieldsDesc` and names its one structure type in the class-side `structureType`; it inherits `initializeConstantFields`, which stamps that type into every fresh block, and the `Flags` inspector tab, whose rows are reflected out of the declared layout by `flagRows` so a field added to `fieldsDesc` appears in the view with nothing else touched. `headerFieldNames` names the two fields that describe the chain rather than the device and so stay out of the flag rows. `VkPhysicalDeviceFeatures2 class >> of:chainedWith:do:` queries one of these structures of a device; `VkContext` chains the ones it needs onto the device create info.
"
Class {
	#name : 'VkFeatureStructure',
	#superclass : 'VkStructure',
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'accessing' }
VkFeatureStructure class >> headerFieldNames [
	"The chain header, named once for the whole structure hierarchy."

	^ self chainHeaderFieldNames
]

{ #category : 'inspector' }
VkFeatureStructure class >> inspectorFeatureStructures: aBuilder [
	"The rule the whole hierarchy obeys, asked of the hierarchy itself: one row per feature
	 structure, the structure type that structure stamps into every block it allocates, and
	 the flags its declared layout exposes once the chain header is dropped. A subclass added
	 later shows up here with nothing touched."

	<inspectorPresentationOrder: 40 title: 'Feature structures'>
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Structure' evaluated: [ :each |
					   each name ]);
		  addColumn: (SpStringTableColumn title: 'Type' evaluated: [ :each |
				   each structureType printString ]);
		  addColumn: (SpStringTableColumn title: 'Flags' evaluated: [ :each |
				   ', ' join: (each fieldSpec fieldNames reject: [ :fieldName |
						    self headerFieldNames includes: fieldName ]) ]);
		  items: (self subclasses asSortedCollection: [ :a :b | a name < b name ])
				  asArray;
		  yourself
]

{ #category : 'inspector' }
VkFeatureStructure class >> inspectorFeatureStructuresContext: aContext [
	"The tab explains the hierarchy, not one member of it, so it shows only where there is a
	 hierarchy to explain. A concrete feature structure answers no subclasses and the table
	 would be empty."

	aContext active: self subclasses isNotEmpty
]

{ #category : 'constants' }
VkFeatureStructure class >> structureType [
	^ self subclassResponsibility
]

{ #category : 'accessing' }
VkFeatureStructure >> flagRows [
	"Reflected out of the declared layout and asked of the real accessors, so a member added
	 to fieldsDesc shows up here without this method being touched. The rows are read only:
	 reading a flag cannot change the structure."

	^ (self class fieldSpec fieldNames reject: [ :each |
		   self headerFieldNames includes: each ]) collect: [ :each |
		  (Dictionary newFrom: {
			   (#flag -> each).
			   (#raw -> (self perform: each)).
			   (#enabled -> ((self perform: each) ~= 0)) }) beReadOnlyObject ]
]

{ #category : 'accessing' }
VkFeatureStructure >> headerFieldNames [
	^ self class headerFieldNames
]

{ #category : 'initialization' }
VkFeatureStructure >> initializeConstantFields [
	"Every feature structure carries the one structure type its class names. pNext stays null
	 here: the chain is built by whoever links the structures together, and a fresh block is
	 already zeroed."

	self sType: self class structureType
]

{ #category : 'inspector' }
VkFeatureStructure >> inspectorFlags: aBuilder [
	"Each flag the layout declares, with the raw word the driver wrote and whether it counts
	 as set. VkBool32 is a number, so the answer comes from comparing it, never from reading
	 the word as a boolean."

	<inspectorPresentationOrder: 30 title: 'Flags'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Flag' evaluated: [ :each |
				   each at: #flag ]);
		  addColumn: (SpStringTableColumn title: 'Raw' evaluated: [ :each |
				   (each at: #raw) printString ]);
		  addColumn: (SpStringTableColumn title: 'Set' evaluated: [ :each |
				   (each at: #enabled) printString ]);
		  items: self flagRows;
		  yourself
]
