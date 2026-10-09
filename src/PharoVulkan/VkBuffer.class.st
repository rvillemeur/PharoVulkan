"
Vulkan buffer resource. Allocates a VkBuffer + VkDeviceMemory pair on the device, maps/unmaps host-visible memory, and tracks size and usage flags. Key methods: allocate, copyFromByteArray:, map, unmap, destroy.
"
Class {
	#name : 'VkBuffer',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'memory',
		'size',
		'usage',
		'device',
		'mappedPointer'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan',
	#tag : 'Core'
}

{ #category : 'constants' }
VkBuffer class >> bitsPerByte [
	^ 8
]

{ #category : 'constants' }
VkBuffer class >> byteMask [
	^ 16rFF
]

{ #category : 'constants' }
VkBuffer class >> exampleByteSize [
	"Four floats: small enough that every row of the capacity view reads at a glance."

	^ 16
]

{ #category : 'examples' }
VkBuffer class >> exampleStorageBufferOfFourFloats [
	"One click: a buffer whose capacity rule can be read in the inspector. The size lives in
	 the instance, so the object still answers after its handle and its context have gone."

	<sampleInstance>
	| context buffer |
	context := VkContext computeContext.
	^ [
	  buffer := self
		            on: context device
		            size: self exampleByteSize
		            usage: self storageBufferUsage.
	  buffer destroy.
	  buffer ] ensure: [ context destroy ]
]

{ #category : 'factory' }
VkBuffer class >> on: aDevice size: byteSize usage: usageFlags [
    ^ self new initializeDevice: aDevice size: byteSize usage: usageFlags
]

{ #category : 'instance creation' }
VkBuffer class >> storageBuffer: count of: anElementTypeSymbol on: aDevice [
	"One entry point for both element widths, so a caller that works in either precision
	 holds one branch rather than one per operation."

	anElementTypeSymbol = #f32 ifTrue: [
		^ self storageBuffer: count on: aDevice ].
	anElementTypeSymbol = #f16 ifTrue: [
		^ self storageBufferOfHalves: count on: aDevice ].
	PVTypeError signal: 'Unknown element type: ' , anElementTypeSymbol
]

{ #category : 'factory' }
VkBuffer class >> storageBuffer: count on: aDevice [
	^ self on: aDevice size: count * 4 usage: self storageBufferUsage
]

{ #category : 'factory' }
VkBuffer class >> storageBufferOfHalves: count on: aDevice [
	"Two bytes per element rather than four, which is the whole point of a half buffer."

	^ self
		  on: aDevice
		  size: count * PVFloat16 bytesPerHalf
		  usage: self storageBufferUsage
]

{ #category : 'constants' }
VkBuffer class >> storageBufferUsage [
	^ 32
]

{ #category : 'lifecycle' }
VkBuffer >> allocate [
    "VkBufferCreateInfo: 1:sType 9:pNext 17:flags [pad] 25:size(u64) 33:usage 37:sharing 41:qCount [pad] 49:pQueues"
    | info bufBuf result memReqs memTypeIndex allocInfo memBuf |
    info := ExternalAddress allocate: 56.
    [ info unsignedLongAt: 1 put: VkStructureType bufferCreateInfo.
      info pointerAt: 9 put: ExternalAddress null.
      info unsignedLongAt: 17 put: 0.
      info unsignedLongLongAt: 25 put: size.
      info unsignedLongAt: 33 put: usage.
      info unsignedLongAt: 37 put: 0.
      info unsignedLongAt: 41 put: 0.
      info pointerAt: 49 put: ExternalAddress null.
      bufBuf := ExternalAddress allocate: 8.
      [ result := Vk createBuffer: device handle createInfo: info allocator: ExternalAddress null bufferOut: bufBuf.
        Vk checkResult: result.
        handle := VkBuffer_H fromHandle: (bufBuf pointerAt: 1)
      ] ensure: [ bufBuf free ]
    ] ensure: [ info free ].
    memReqs := ExternalAddress allocate: 24.
    [ Vk getBufferMemoryRequirements: device handle buffer: handle memoryRequirements: memReqs.
      memTypeIndex := device physicalDevice
          findMemoryType: (memReqs unsignedLongAt: 17)
          properties: VkMemoryProperty hostVisibleAndCoherent.
      allocInfo := ExternalAddress allocate: 32.
      [ allocInfo unsignedLongAt: 1 put: VkStructureType memoryAllocateInfo.
        allocInfo pointerAt: 9 put: ExternalAddress null.
        allocInfo unsignedLongLongAt: 17 put: (memReqs unsignedLongLongAt: 1).
        allocInfo unsignedLongAt: 25 put: memTypeIndex.
        memBuf := ExternalAddress allocate: 8.
        [ result := Vk allocateMemory: device handle allocateInfo: allocInfo allocator: ExternalAddress null memory: memBuf.
          Vk checkResult: result.
          memory := VkDeviceMemory_H fromHandle: (memBuf pointerAt: 1)
        ] ensure: [ memBuf free ]
      ] ensure: [ allocInfo free ]
    ] ensure: [ memReqs free ].
    result := Vk bindBufferMemory: device handle buffer: handle memory: memory memoryOffset: 0.
    Vk checkResult: result
]

{ #category : 'accessing' }
VkBuffer >> capacityProbeCounts [
	"Empty, the exact fit and one byte over: the three states the capacity rule distinguishes."

	^ {
		  0.
		  size.
		  size + 1 }
]

{ #category : 'accessing' }
VkBuffer >> copyFromByteArray: aByteArray [
	"Checked before the mapping is touched: the bytes go out through a raw pointer, so a
	 collection longer than the buffer would land outside it rather than fail."

	| ptr |
	(self fitsByteCount: aByteArray size) ifFalse: [
		SizeMismatch signal: aByteArray size printString , ' bytes do not fit a buffer of '
			, size printString , ' bytes' ].
	ptr := self map.
	1 to: aByteArray size do: [ :i | ptr byteAt: i put: (aByteArray at: i) ].
	self unmap
]

{ #category : 'accessing' }
VkBuffer >> copyToByteArray [
	| ptr result |
	result := ByteArray new: size.
	ptr := self map.
	1 to: size do: [:i | result at: i put: (ptr byteAt: i)].
	self unmap.
	^ result
]

{ #category : 'lifecycle' }
VkBuffer >> destroy [

	handle ifNotNil: [
			Vk
				destroyBuffer: device handle
				buffer: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ].
	memory ifNotNil: [
			Vk
				freeMemory: device handle
				memory: memory
				allocator: ExternalAddress null.
			memory invalidate.
			memory := nil ]
]

{ #category : 'accessing' }
VkBuffer >> elementsAs: anElementTypeSymbol [
	"Reads the whole buffer back at the width the element type asks for."

	anElementTypeSymbol = #f32 ifTrue: [ ^ self getF32s ].
	anElementTypeSymbol = #f16 ifTrue: [ ^ self getF16s ].
	PVTypeError signal: 'Unknown element type: ' , anElementTypeSymbol
]

{ #category : 'accessing' }
VkBuffer >> fitsByteCount: aCount [
	"The one capacity rule. The write and the inspector both ask it, so neither can drift from
	 the other."

	^ aCount <= size
]

{ #category : 'accessing' }
VkBuffer >> getF16s [
	| bytes result |
	bytes := self copyToByteArray.
	result := Array new: bytes size // PVFloat16 bytesPerHalf.
	1 to: result size do: [ :i |
		| base word |
		base := (i - 1) * PVFloat16 bytesPerHalf + 1.
		word := (bytes at: base)
		        + ((bytes at: base + 1) bitShift: self class bitsPerByte).
		result at: i put: (PVFloat16 floatFromWord: word) ].
	^ result
]

{ #category : 'accessing' }
VkBuffer >> getF32s [
	| bytes result |
	bytes := self copyToByteArray.
	result := Array new: bytes size // 4.
	1 to: result size do: [:i |
		| base word |
		base := (i - 1) * 4 + 1.
		word := (bytes at: base)
			+ ((bytes at: base + 1) bitShift: 8)
			+ ((bytes at: base + 2) bitShift: 16)
			+ ((bytes at: base + 3) bitShift: 24).
		result at: i put: (Float fromIEEE32Bit: word)].
	^ result
]

{ #category : 'accessing' }
VkBuffer >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkBuffer >> initializeDevice: aDevice size: byteSize usage: usageFlags [
    device := aDevice. size := byteSize. usage := usageFlags.
    self allocate
]

{ #category : 'inspector' }
VkBuffer >> inspectorCapacity: aBuilder [
	"Each row asks the real capacity rule rather than restating it, so the table cannot say
	 something a write would not do."

	<inspectorPresentationOrder: 10 title: 'Capacity'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Bytes written' evaluated: [ :each |
					   each printString ]);
		  addColumn: (SpStringTableColumn title: 'Fits' evaluated: [ :each |
					   (self fitsByteCount: each) printString ]);
		  items: self capacityProbeCounts;
		  yourself
]

{ #category : 'mapping' }
VkBuffer >> map [
    | ptrBuf result |
    ptrBuf := ExternalAddress allocate: 8.
    [ result := Vk mapMemory: device handle memory: memory offset: 0 size: size flags: 0 ppData: ptrBuf.
      Vk checkResult: result.
      mappedPointer := ptrBuf pointerAt: 1.
      ^ mappedPointer
    ] ensure: [ ptrBuf free ]
]

{ #category : 'accessing' }
VkBuffer >> put: aNumberCollection as: anElementTypeSymbol [
	"Writes the values at the width the element type asks for; an unknown type raises
	 rather than guessing, because the wrong width corrupts the whole buffer."

	anElementTypeSymbol = #f32 ifTrue: [ ^ self putF32s: aNumberCollection ].
	anElementTypeSymbol = #f16 ifTrue: [ ^ self putF16s: aNumberCollection ].
	PVTypeError signal: 'Unknown element type: ' , anElementTypeSymbol
]

{ #category : 'accessing' }
VkBuffer >> putF16s: aNumberCollection [
	"Each value is rounded to the nearest half on the way in; PVFloat16 owns that rounding."

	| bytes |
	bytes := ByteArray new: aNumberCollection size * PVFloat16 bytesPerHalf.
	aNumberCollection doWithIndex: [ :each :i |
		| word base |
		word := PVFloat16 wordForFloat: each.
		base := (i - 1) * PVFloat16 bytesPerHalf + 1.
		bytes at: base put: (word bitAnd: self class byteMask).
		bytes
			at: base + 1
			put: ((word bitShift: 0 - self class bitsPerByte) bitAnd: self class byteMask) ].
	self copyFromByteArray: bytes
]

{ #category : 'accessing' }
VkBuffer >> putF32s: aFloatCollection [
	| bytes |
	bytes := ByteArray new: aFloatCollection size * 4.
	aFloatCollection doWithIndex: [:f :i |
		| word base |
		word := f asFloat asIEEE32BitWord.
		base := (i - 1) * 4 + 1.
		bytes at: base     put: (word bitAnd: 16rFF).
		bytes at: base + 1 put: ((word >> 8)  bitAnd: 16rFF).
		bytes at: base + 2 put: ((word >> 16) bitAnd: 16rFF).
		bytes at: base + 3 put: ((word >> 24) bitAnd: 16rFF)].
	self copyFromByteArray: bytes
]

{ #category : 'accessing' }
VkBuffer >> size [
    ^ size
]

{ #category : 'mapping' }
VkBuffer >> unmap [
    Vk unmapMemory: device handle memory: memory.
    mappedPointer := nil
]
