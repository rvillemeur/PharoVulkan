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
