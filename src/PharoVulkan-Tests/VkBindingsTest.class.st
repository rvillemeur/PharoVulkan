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
VkBindingsTest >> testQueueFlagsConstants [
    "VkQueueFlags must expose named bit constants."
    self assert: VkQueueFlags graphicsBit equals: 1.
    self assert: VkQueueFlags computeBit equals: 2.
    self assert: VkQueueFlags transferBit equals: 4
]

{ #category : 'tests' }
VkBindingsTest >> testStructureTypeConstants [
    "VkStructureType must expose named constants — no magic numbers."
    self assert: VkStructureType applicationInfo equals: 0.
    self assert: VkStructureType instanceCreateInfo equals: 1
]

{ #category : 'tests' }
VkBindingsTest >> testStructureTypeNamesEveryConstantItDefines [
	"The reverse lookup is reflective, so it must answer, for every constant the class declares,
	 a name that carries that same value, and nothing for a value no constant carries."

	| names |
	names := VkStructureType constantSelectors.
	self deny: names isEmpty.
	names do: [ :each |
		| value |
		value := VkStructureType perform: each.
		self
			assert: (VkStructureType perform: (VkStructureType nameForValue: value))
			equals: value ].
	self assert: (VkStructureType nameForValue: -1) isNil
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
