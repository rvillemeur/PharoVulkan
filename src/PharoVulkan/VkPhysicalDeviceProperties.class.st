"
Core properties of a VkPhysicalDevice. Returned by vkGetPhysicalDeviceProperties.
deviceName is a 256-byte null-terminated UTF-8 string — use deviceNameString.
limits and sparseProperties are opaque blobs; generator will produce typed structs in Phase 2.
Key methods: deviceNameString, apiVersion, deviceType, vendorID.
"
Class {
	#name : 'VkPhysicalDeviceProperties',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_APIVERSION',
		'OFFSET_DEVICEID',
		'OFFSET_DEVICENAME',
		'OFFSET_DEVICETYPE',
		'OFFSET_DRIVERVERSION',
		'OFFSET_LIMITS',
		'OFFSET_LIMITSALIGNMENTPAD',
		'OFFSET_PIPELINECACHEUUID',
		'OFFSET_SPARSEPROPERTIES',
		'OFFSET_TAILALIGNMENTPAD',
		'OFFSET_VENDORID'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkPhysicalDeviceProperties class >> examplePropertiesOfThisMachine [
	"One click: the properties the local driver writes, with the Layout view beside them. The
	 store is a ByteArray inside the image, so the bytes still read after the context that
	 queried them has gone."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ Vk getPhysicalDeviceProperties: context physicalDevice handle ]
		  ensure: [ context destroy ]
]

{ #category : 'field definition' }
VkPhysicalDeviceProperties class >> fieldsDesc [
	"limits is a VkPhysicalDeviceLimits by value, so its own members carry their alignment and
	 every limit is reached through a generated accessor. Two pads a field list alone would miss
	 remain: limits holds VkDeviceSize members, so it is eight byte aligned and starts four
	 bytes after pipelineCacheUUID ends, and the struct itself is eight byte aligned, so it ends
	 four bytes after sparseProperties. Without them the store is 816 bytes while the driver
	 writes 824 into it, and that store is a ByteArray inside object memory."

	^ #(
		uint32    apiVersion;
		uint32    driverVersion;
		uint32    vendorID;
		uint32    deviceID;
		int32     deviceType;
		Uint8_256 deviceName;
		Uint8_16  pipelineCacheUUID;
		uint32    limitsAlignmentPad;
		VkPhysicalDeviceLimits limits;
		Uint8_20  sparseProperties;
		uint32    tailAlignmentPad
	)
]

{ #category : 'constants' }
VkPhysicalDeviceProperties class >> headByteCount [
	"Enough bytes to recognise a field in a table row, few enough that the long array fields do
	 not push the other columns off the view."

	^ 8
]

{ #category : 'accessing' }
VkPhysicalDeviceProperties class >> layoutRows [
	"The layout read back from the field specification the class compiled, never a second copy
	 of the declaration: name, byte offset and byte count per field. uFFI keeps offsets as
	 one based indices into the store, so each one is shifted to the C offset the driver uses."

	| spec |
	spec := self fieldSpec.
	^ spec fieldNames with: spec types collect: [ :fieldName :type |
		  {
			  fieldName.
			  (self classVariableNamed: (self offsetVariableNameFor: fieldName)) value - 1.
			  type externalTypeSize } ]
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> apiVersion [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_APIVERSION
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> apiVersion: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_APIVERSION put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceID [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEVICEID
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceID: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEVICEID put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceName [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt8 size: 256) fromHandle: (handle copyFrom: OFFSET_DEVICENAME to: OFFSET_DEVICENAME + 255)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceName: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_DEVICENAME to: OFFSET_DEVICENAME + 255 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing' }
VkPhysicalDeviceProperties >> deviceNameString [
	"Read through the generated accessor rather than through the store, because this structure
	 can be a member of another one: the handle is then a reference into the outer store, which
	 basicAt: does not reach. Vulkan ends the name with a zero byte, and a name filling the
	 whole field has none."

	| name byte |
	name := self deviceName.
	^ String streamContents: [ :out |
		  1 to: name size do: [ :i |
			  byte := name at: i.
			  byte = 0 ifTrue: [ ^ out contents ].
			  out nextPut: (Character value: byte) ] ]
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_DEVICETYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_DEVICETYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> driverVersion [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DRIVERVERSION
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> driverVersion: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DRIVERVERSION put: anObject
]

{ #category : 'accessing' }
VkPhysicalDeviceProperties >> headOfFieldAt: anOffset size: aSize [
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
VkPhysicalDeviceProperties >> inspectorLayout: aBuilder [
	"Every row is read back from the compiled field specification and from this instance's own
	 store, so the table cannot state a layout the struct does not have. The store is only read,
	 never written, so inspecting a populated struct leaves its bytes alone."

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

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> limits [
	"This method was automatically generated"
	^ VkPhysicalDeviceLimits fromHandle: (handle referenceStructAt: OFFSET_LIMITS length: VkPhysicalDeviceLimits byteSize)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> limits: anObject [
	"This method was automatically generated"
	handle structAt: OFFSET_LIMITS put: anObject getHandle length: VkPhysicalDeviceLimits byteSize
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> limitsAlignmentPad [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LIMITSALIGNMENTPAD
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> limitsAlignmentPad: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LIMITSALIGNMENTPAD put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> pipelineCacheUUID [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt8 size: 16) fromHandle: (handle copyFrom: OFFSET_PIPELINECACHEUUID to: OFFSET_PIPELINECACHEUUID + 15)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> pipelineCacheUUID: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_PIPELINECACHEUUID to: OFFSET_PIPELINECACHEUUID + 15 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> sparseProperties [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt8 size: 20) fromHandle: (handle copyFrom: OFFSET_SPARSEPROPERTIES to: OFFSET_SPARSEPROPERTIES + 19)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> sparseProperties: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_SPARSEPROPERTIES to: OFFSET_SPARSEPROPERTIES + 19 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> tailAlignmentPad [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TAILALIGNMENTPAD
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> tailAlignmentPad: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TAILALIGNMENTPAD put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> vendorID [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VENDORID
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> vendorID: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VENDORID put: anObject
]
