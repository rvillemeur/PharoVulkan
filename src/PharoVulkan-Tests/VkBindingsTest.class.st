"
Tests for PharoVulkan-Bindings correctness.
Tests cover result codes, structure types, handle creation, and queue flags
without requiring libvulkan to be installed.
"
Class {
	#name : 'VkBindingsTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Bindings',
	#package : 'PharoVulkan-Tests',
	#tag : 'Bindings'
}

{ #category : 'private' }
VkBindingsTest >> assertHalfOf: aFloat is: anInteger [
	self
		assert: (PVFloat16 wordForFloat: aFloat) = anInteger
		description: aFloat printString , ' encodes to '
			, (PVFloat16 wordForFloat: aFloat) printStringHex , ', expected '
			, anInteger printStringHex
]

{ #category : 'measuring' }
VkBindingsTest >> offsetOf: aFieldName in: aStructureClass [
	"The offset uFFI compiled, shifted to the C offset the driver uses, so a test never hand
	 counts one."

	^ (aStructureClass classVariableNamed:
		   (aStructureClass offsetVariableNameFor: aFieldName)) value - 1
]

{ #category : 'measuring' }
VkBindingsTest >> spanBytesWrittenByDevicePropertiesOf: aPhysicalDeviceHandle [
	"The same query answered into memory outside the image, so the struct's own store can be
	 compared against it byte for byte."

	| capacity probe bytes |
	capacity := 4096.
	probe := ExternalAddress allocate: capacity.
	^ [
	  Vk getPhysicalDeviceProperties: aPhysicalDeviceHandle into: probe.
	  bytes := ByteArray new: capacity.
	  1 to: capacity do: [ :i | bytes at: i put: (probe byteAt: i) ].
	  bytes ] ensure: [ probe free ]
]

{ #category : 'measuring' }
VkBindingsTest >> spanWrittenByDevicePropertiesOf: aPhysicalDeviceHandle sentinel: aByte [
	"Answers how far vkGetPhysicalDeviceProperties writes, measured in a buffer outside object
	 memory so the measurement itself cannot corrupt anything. One sentinel could collide with
	 a byte the driver really wrote, which is why the caller measures twice."

	| capacity probe written |
	capacity := 4096.
	probe := ExternalAddress allocate: capacity.
	^ [
	  1 to: capacity do: [ :i | probe byteAt: i put: aByte ].
	  Vk getPhysicalDeviceProperties: aPhysicalDeviceHandle into: probe.
	  written := 0.
	  1 to: capacity do: [ :i |
		  (probe byteAt: i) = aByte ifFalse: [ written := i ] ].
	  written ] ensure: [ probe free ]
]

{ #category : 'tests' }
VkBindingsTest >> testCreateDestroyInstance [
    | info instance |
    info := VkInstanceCreateInfo new.
    instance := Vk createInstance: info.
    self assert: instance isNotNil.
    Vk destroyInstance: instance allocator: ExternalAddress null
]

{ #category : 'tests' }
VkBindingsTest >> testEnumeratePhysicalDevices [

	| info instance devices |
	info := VkInstanceCreateInfo new.
	instance := Vk createInstance: info.
	[
		devices := Vk enumeratePhysicalDevices: instance.
		self assert: devices isNotEmpty ] ensure: [
		Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16ClassifiesEveryKindOfHalf [
	| expected |
	expected := {
		            (16r0000 -> #zero).
		            (16r8000 -> #zero).
		            (16r0001 -> #subnormal).
		            (16r3C00 -> #normal).
		            (16r7C00 -> #infinity).
		            (16r7E00 -> #notANumber) }.
	expected do: [ :each |
		self assert: (PVFloat16 on: each key) classification equals: each value ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16DecodeInvertsEncodeForRepresentableValues [
	| values |
	values := {
		          0.0.
		          1.0.
		          -2.5.
		          0.5.
		          65504.0.
		          1.0 timesTwoPower: -14.
		          1.0 timesTwoPower: -24.
		          1023.0 timesTwoPower: -24 }.
	values do: [ :each |
		self
			assert: (PVFloat16 floatFromWord: (PVFloat16 wordForFloat: each))
			equals: each ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16EncodesTheBoundariesOfTheFormat [
	"Zero and its sign, one, the smallest normal, both ends of the subnormal range, the
	 largest finite half, and infinity. Every one of these is a boundary a naive shift-and-
	 mask encoder gets wrong."

	self assertHalfOf: 0.0 is: 16r0000.
	self assertHalfOf: 0.0 negated is: 16r8000.
	self assertHalfOf: 1.0 is: 16r3C00.
	self assertHalfOf: -2.0 is: 16rC000.
	self assertHalfOf: (1.0 timesTwoPower: -14) is: 16r0400.
	self assertHalfOf: (1.0 timesTwoPower: -24) is: 16r0001.
	self assertHalfOf: (1023.0 timesTwoPower: -24) is: 16r03FF.
	self assertHalfOf: 65504.0 is: 16r7BFF.
	self assertHalfOf: Float infinity is: 16r7C00.
	self assertHalfOf: Float infinity negated is: 16rFC00
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16FieldReportReEncodesItsOwnWord [
	"The Half tab's last row is evidence, so assert it: decode followed by encode must
	 return the word it started from, including at the subnormal and infinite ends."

	#( 16r0000 16r8000 16r0001 16r03FF 16r0400 16r3555 16r7BFF 16r7C00 16rFC00 )
		do: [ :each |
			| half |
			half := PVFloat16 on: each.
			self
				assert: (half fieldReport last at: #value)
				equals: each printStringHex ]
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16KeepsInfinitiesAndNotANumberApart [
	self assert: (PVFloat16 floatFromWord: 16r7C00) equals: Float infinity.
	self assert: (PVFloat16 floatFromWord: 16rFC00) equals: Float infinity negated.
	self assert: (PVFloat16 floatFromWord: 16r7E00) isNaN.
	self assert: (PVFloat16 wordForFloat: Float nan) = 16r7E00
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16NamesTheFieldsOfOneThird [
	| half |
	half := PVFloat16 exampleHalfOfOneThird.
	self assert: half word equals: 16r3555.
	self assert: half sign equals: 0.
	self assert: half biasedExponent equals: 13.
	self assert: half mantissa equals: 16r155.
	self assert: half classification equals: #normal.
	self assert: half value equals: 0.333251953125
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16RoundsTiesToEven [
	"A value exactly between two halves must go to the one with an even mantissa, in the
	 normal range and in the subnormal range alike. Truncation and round-half-up both fail
	 the first and third of these."

	self assertHalfOf: 1.0 + (1.0 timesTwoPower: -11) is: 16r3C00.
	self
		assertHalfOf: 1.0 + (1.0 timesTwoPower: -11) + (1.0 timesTwoPower: -30)
		is: 16r3C01.
	self assertHalfOf: 1.0 + (3.0 timesTwoPower: -11) is: 16r3C02.
	self assertHalfOf: (3.0 timesTwoPower: -25) is: 16r0002
]

{ #category : 'tests' }
VkBindingsTest >> testFloat16SaturatesOutsideItsRange [
	"Above the last finite half the format has only infinity, and the tie at 65520 goes
	 there because infinity is the even neighbour. Below half the smallest subnormal there
	 is only zero, which keeps its sign."

	self assertHalfOf: 65519.0 is: 16r7BFF.
	self assertHalfOf: 65520.0 is: 16r7C00.
	self assertHalfOf: 70000.0 is: 16r7C00.
	self assertHalfOf: (1.0 timesTwoPower: -25) is: 16r0000.
	self assertHalfOf: (1.0 timesTwoPower: -25) negated is: 16r8000.
	self assertHalfOf: (3.0 timesTwoPower: -26) is: 16r0001
]

{ #category : 'tests' }
VkBindingsTest >> testGeneratorIsIdempotent [
	"Idempotency: generating an existing enum creates no new class."

	| gen desc before after |
	gen := VkBindingGenerator new.
	desc := VkEnumDescriptor new.
	desc name: 'VkResult'.
	desc values: OrderedCollection new.
	before := Smalltalk globals allClasses size.
	gen generateEnum: desc.
	after := Smalltalk globals allClasses size.
	self assert: after - before equals: 0
]

{ #category : 'tests' }
VkBindingsTest >> testLibraryLoads [
    | lib |
    lib := VkLibrary uniqueInstance.
    self assert: lib isNotNil
]

{ #category : 'tests' }
VkBindingsTest >> testNestedPropertiesNameReadsThroughTheOuterStore [
	"deviceNameString read the store directly, which only works where the structure owns it.
	 Nested in a query structure the handle is a reference into the outer store, so the name has
	 to be read through the generated accessor instead. The bytes are written where the driver
	 would write them, at the offsets uFFI compiled. The zero byte ends the name, and a name
	 filling the whole field, which carries no terminator, must still read back whole."

	| query base name fieldSize |
	query := VkPhysicalDeviceProperties2 new.
	base := (self offsetOf: #properties in: VkPhysicalDeviceProperties2)
	        + (self offsetOf: #deviceName in: VkPhysicalDeviceProperties).
	name := 'Probe'.
	1 to: name size do: [ :i |
		query getHandle at: base + i put: (name at: i) asciiValue ].
	self assert: query properties deviceNameString equals: name.
	fieldSize := query properties deviceName size.
	1 to: fieldSize do: [ :i |
		query getHandle at: base + i put: $A asciiValue ].
	self
		assert: query properties deviceNameString
		equals: (String new: fieldSize withAll: $A)
]

{ #category : 'tests' }
VkBindingsTest >> testNumberHalfConversionsAnswerWhatTheDeviceWouldAnswer [
	"The kernel DSL sends asF16 and asF32. The host answers must be the rounding the device
	 performs, so that running a half kernel's body on the host is a check on the kernel and
	 not a different calculation."

	{
		0.0.
		1.0.
		-2.5.
		65504.0.
		(1 / 3).
		(1.0 timesTwoPower: -24) } do: [ :each |
		self
			assert: each asF16
			equals: (PVFloat16 floatFromWord: (PVFloat16 wordForFloat: each)).
		self assert: each asF32 equals: each asFloat ].
	self assert: 3 asF32 equals: 3.0.
	self assert: Float infinity asF16 equals: Float infinity
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDeviceLimitsFillsTheLimitsFieldExactly [
	"The limits block is read through its own structure rather than as a byte blob, so every
	 limit's offset comes from the compiled field specification instead of a hand counted byte
	 count. The facts to state are that the structure is exactly as long as the field holding
	 it, and that the field starts on an eight byte boundary: limits holds VkDeviceSize members,
	 so a missing pad moves it and moves every limit inside it."

	| limitsRow |
	limitsRow := VkPhysicalDeviceProperties layoutRows detect: [ :each |
		             each first = #limits ].
	self assert: limitsRow third equals: VkPhysicalDeviceLimits byteSize.
	self assert: limitsRow second \\ 8 equals: 0
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDeviceLimitsRowsReadTheirOwnAccessors [
	"The Limits view prints one row per member by performing the generated accessor, so a row
	 cannot show a value the structure does not hold. An array member must read as its elements
	 rather than as an opaque FFIArray, which is the degenerate case of the same rule."

	| limits |
	limits := VkPhysicalDeviceLimits new.
	limits maxComputeSharedMemorySize: 48 * 1024.
	self
		assert: (limits printableValueOf: #maxComputeSharedMemorySize)
		equals: (48 * 1024) printString.
	self
		assert: (limits printableValueOf: #maxComputeWorkGroupSize)
		equals: #( 0 0 0 ) printString
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDeviceProperties [
    | info instance devices props name |
    info := VkInstanceCreateInfo new.
    instance := Vk createInstance: info.
    [ devices := Vk enumeratePhysicalDevices: instance.
      props := VkPhysicalDeviceProperties new.
      Vk getPhysicalDeviceProperties: (devices at: 1) into: props.
      name := props deviceNameString.
      self assert: (name isKindOf: String).
      self assert: name isNotEmpty ]
    ensure: [ Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDevicePropertiesFieldHeadReadsTheStore [
	"The layout view prints the first bytes of each field. It must read them from the store the
	 instance really holds, and it must mark a field whose bytes it had to cut, otherwise a row
	 could read as if the field were as short as the text shown."

	| props store |
	props := VkPhysicalDeviceProperties new.
	store := props getHandle.
	1 to: store size do: [ :i | store at: i put: i \\ 256 ].
	self assert: (props headOfFieldAt: 0 size: 4) equals: '01 02 03 04'.
	self
		assert: (props headOfFieldAt: 0 size: VkPhysicalDeviceProperties byteSize)
		equals: '01 02 03 04 05 06 07 08 ...'
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDevicePropertiesHoldsEverythingTheDriverWrites [
	"The struct keeps its bytes in a ByteArray inside object memory, so a declaration shorter
	 than what the driver writes overruns that object and corrupts whatever follows it in the
	 heap. The span is measured from the driver rather than taken from the specification, and
	 the byte comparison pins the field offsets as well as the size: the C layout aligns limits
	 to eight bytes, so a missing pad shifts everything from limits onward."

	| info instance devices device written props |
	info := VkInstanceCreateInfo new.
	instance := Vk createInstance: info.
	[
	devices := Vk enumeratePhysicalDevices: instance.
	device := devices at: 1.
	written := (self spanWrittenByDevicePropertiesOf: device sentinel: 16rAB)
		           max: (self spanWrittenByDevicePropertiesOf: device sentinel: 16r5C).
	self assert: written > 0.
	self assert: VkPhysicalDeviceProperties byteSize >= written.
	props := VkPhysicalDeviceProperties new.
	Vk getPhysicalDeviceProperties: device into: props.
	self
		assert: ((props getHandle first: written) collect: [ :each | each ]) asArray
		equals: (((self spanBytesWrittenByDevicePropertiesOf: device) first: written) collect: [ :each | each ]) asArray ]
		ensure: [ Vk destroyInstance: instance allocator: ExternalAddress null ]
]

{ #category : 'tests' }
VkBindingsTest >> testPhysicalDevicePropertiesLayoutTilesItsWholeStore [
	"The layout the inspector shows is read back from the field specification the class really
	 compiled. The fact to state is that the fields tile the store with no hole and no overlap:
	 the first starts at zero, each one begins where the previous ends, and the last ends at the
	 declared size. An alignment pad removed or put in the wrong place breaks one of the three."

	| rows |
	rows := VkPhysicalDeviceProperties layoutRows.
	self assert: rows first second equals: 0.
	rows overlappingPairsDo: [ :a :b | self assert: b second equals: a second + a third ].
	self
		assert: rows last second + rows last third
		equals: VkPhysicalDeviceProperties byteSize
]

{ #category : 'tests' }
VkBindingsTest >> testQueueFlagsConstants [
    "VkQueueFlags must expose named bit constants."
    self assert: VkQueueFlags graphicsBit equals: 1.
    self assert: VkQueueFlags computeBit equals: 2.
    self assert: VkQueueFlags transferBit equals: 4
]

{ #category : 'tests' }
VkBindingsTest >> testStructureCopyIntoObjectMemoryDetachesFromItsSource [
	"A structure the driver filled in memory outside the image has to be copied before that
	 memory is freed. The copy must hold the same bytes, keep a store of its own so a later
	 write to the source cannot reach it, and drop a pNext that would otherwise point into
	 memory already given back."

	| address source copy |
	address := ExternalAddress allocate: VkPhysicalDeviceSubgroupProperties byteSize.
	[
	source := VkPhysicalDeviceSubgroupProperties fromHandle: address.
	1 to: VkPhysicalDeviceSubgroupProperties byteSize do: [ :i |
		address byteAt: i put: 0 ].
	source subgroupSize: 32.
	source pNext: address.
	copy := source copyIntoObjectMemory.
	self assert: copy subgroupSize equals: 32.
	self assert: copy pNext isNull.
	source subgroupSize: 64.
	self assert: copy subgroupSize equals: 32 ] ensure: [ address free ]
]

{ #category : 'tests' }
VkBindingsTest >> testStructureTypeConstants [
    "VkStructureType must expose named constants — no magic numbers."
    self assert: VkStructureType applicationInfo equals: 0.
    self assert: VkStructureType instanceCreateInfo equals: 1
]

{ #category : 'tests' }
VkBindingsTest >> testSubgroupFeaturePredicateMatchesTheOperationBits [
	"VkPhysicalDevice and the Features view read supportedOperations through one predicate. The
	 device only ever reports the mask it has, so the two degenerate masks are stated here: an
	 empty one supports nothing, and one carrying every named bit supports all of them."

	| block everyBit supported |
	block := VkPhysicalDeviceSubgroupProperties new.
	everyBit := VkSubgroupFeature featureSelectors
		            inject: 0
		            into: [ :mask :each |
			            mask bitOr: (VkSubgroupFeature perform: each) ].
	supported := [ VkSubgroupFeature featureSelectors select: [ :each |
		           block supportsFeature: (VkSubgroupFeature perform: each) ] ].
	self assert: supported value isEmpty.
	block supportedOperations: everyBit.
	self assert: supported value equals: VkSubgroupFeature featureSelectors
]

{ #category : 'tests - constants' }
VkBindingsTest >> testValueConstantsNameEveryConstantTheyDeclare [
	"The reverse lookup is reflective and shared, so for every class that inherits it, and
	 for every constant that class declares, it must answer a name carrying that same value,
	 and nothing for a value no constant carries. Reflecting over the subclasses rather than
	 naming them keeps a class added later covered without editing this test."

	| classes |
	classes := VkValueConstants subclasses.
	self deny: classes isEmpty.
	classes do: [ :each |
		| names |
		names := each constantSelectors.
		self deny: names isEmpty.
		names do: [ :selector |
			| value |
			value := each perform: selector.
			self
				assert: (each perform: (each nameForValue: value))
				equals: value ].
		self assert: (each nameForValue: -1) isNil ]
]

{ #category : 'tests' }
VkBindingsTest >> testVkApplicationInfoSType [
    "VkApplicationInfo initialize must set sType to applicationInfo."
    | info |
    info := VkApplicationInfo new.
    self assert: info sType equals: VkStructureType applicationInfo
]

{ #category : 'tests' }
VkBindingsTest >> testVkHandleIsNull [
    "A freshly created VkHandle with no backing pointer must report isNull."
    | h |
    h := VkHandle new.
    self assert: h isNull
]

{ #category : 'tests' }
VkBindingsTest >> testVkInstanceCreateInfoSType [
    "VkInstanceCreateInfo initialize must set sType to instanceCreateInfo."
    | info |
    info := VkInstanceCreateInfo new.
    self assert: info sType equals: VkStructureType instanceCreateInfo
]

{ #category : 'tests' }
VkBindingsTest >> testVkQueueFamilyNotCompute [
    "supportsCompute must return false when only graphicsBit is set."
    | props |
    props := VkQueueFamilyProperties new.
    props queueFlags: VkQueueFlags graphicsBit.
    self deny: props supportsCompute
]

{ #category : 'tests' }
VkBindingsTest >> testVkQueueFamilySupportsCompute [
    "supportsCompute must return true when computeBit is set."
    | props |
    props := VkQueueFamilyProperties new.
    props queueFlags: VkQueueFlags computeBit.
    self assert: props supportsCompute
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultError [
    "Negative VkResult codes must be errors."
    | r |
    r := VkResult withCode: -1.
    self deny: r isSuccess.
    self assert: r isError.
    self assert: r name equals: 'VK_ERROR_OUT_OF_HOST_MEMORY'
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultNameForUnknownCode [
    "Unknown codes get a fallback name that includes the code value."
    | r |
    r := VkResult withCode: 99999.
    self assert: (r name beginsWith: 'VK_UNKNOWN')
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultSignals [
    "VkResult signal must raise VkError for error codes."
    | r |
    r := VkResult withCode: -1.
    self should: [ r signal ] raise: VkError
]

{ #category : 'tests' }
VkBindingsTest >> testVkResultSuccess [
    "VkResult withCode: 0 must be a success result."
    | r |
    r := VkResult withCode: 0.
    self assert: r isSuccess.
    self deny: r isError.
    self assert: r name equals: 'VK_SUCCESS'
]

{ #category : 'path' }
VkBindingsTest >> vkXmlPath [
    ^ FileLocator image parent parent parent parent / 'sources' / 'PharoVulkan' / 'vk.xml'
]
