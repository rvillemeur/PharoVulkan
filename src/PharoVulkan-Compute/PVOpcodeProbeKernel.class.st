"
A hand-built SPIR-V module whose body sends every opcode the tiled fill rasteriser of the VectorGraphics engine needs and that nothing in this project emitted before: the two conversions out of a float, unsigned division and remainder, the four bit operations, the three logical operations, the selection without a branch, the two extended instructions for a minimum and a maximum, and the vector-times-matrix multiply.

The constants of SpvOpcode and of GlslStd450 are numbers, and only the device and the validator can tell whether a number names the instruction its selector claims. Three of them named another instruction, and each was accepted by spirv-val because the wrong instruction took the same operand kinds, so this kernel dispatches the whole vocabulary and compares the result with a formula in Pharo. The formula is valueOf:at: on the class side, which mirrors the module step for step: a constant holding another opcode's number answers another number there than on the device.

One workgroup of elementCount invocations, one invocation an element, two storage buffers and no control flow at all. Key methods: spirv, instructionRows, and the class-side valueOf:at:.
"
Class {
	#name : 'PVOpcodeProbeKernel',
	#superclass : 'Object',
	#instVars : [
		'spirv',
		'builder',
		'types',
		'ids',
		'results'
	],
	#category : 'PharoVulkan-Compute-Kernels',
	#package : 'PharoVulkan-Compute',
	#tag : 'Kernels'
}

{ #category : 'constants' }
PVOpcodeProbeKernel class >> bonusValue [
	"What the float selection adds where neither predicate holds."

	^ 1000.0
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> channelMask [
	"The low byte of the packed word, which the index fills."

	^ 255
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> channelShift [
	"Where the clamped byte sits in the packed word, which is also the shift that reads it
	 back."

	^ 8
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> clampCeiling [
	"The upper bound of the clamp. The conversion out of a float is undefined on a negative
	 value, so the clamp holds the value inside a byte before it is converted."

	^ 255.0
]

{ #category : 'oracle' }
PVOpcodeProbeKernel class >> columnOf: aValue [
	"The one component of the vector-times-matrix product the module keeps: the dot product
	 of the vector with the column at componentRead, which is where a multiply that took its
	 operands the other way round answers another number."

	^ (({ aValue } , self vectorTail)
		   with: (self matrixColumns at: self componentRead + 1)
		   collect: [ :each :weight | each * weight ]) sum
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> componentRead [
	"The component of the product the probe keeps, counted from zero as OpCompositeExtract
	 counts."

	^ 1
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> elementCount [
	"One invocation an element, and one workgroup covers the whole probe."

	^ 64
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> elementStride [
	"A f32 element of a storage buffer is four bytes wide."

	^ 4
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> entryPointName [
	^ 'main'
]

{ #category : 'formula' }
PVOpcodeProbeKernel class >> flagsOf: aValue at: anIndex [
	"The predicate nibble of valueOf:at:, computed here in Pharo in the order
	 predicateSelectors emits it, so a device that disagrees disagrees by one bit."

	| lane signed predicates |
	lane := anIndex \\ self groupWidth.
	signed := aValue truncated.
	predicates := {
		              lane >= self laneSplit.
		              aValue > 0.0.
		              aValue >= self halfThreshold.
		              signed ~= 0 }.
	^ (predicates with: self predicateFlagWeights collect: [ :holds :weight |
		   holds
			   ifTrue: [ weight ]
			   ifFalse: [ 0 ] ]) sum
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> groupWidth [
	"The divisor of the unsigned division and of the unsigned remainder: the index of an
	 invocation divided by this is its group and the remainder is its lane."

	^ 8
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> halfThreshold [
	"One input is exactly this value, which is what tells a greater-than from a
	 greater-than-or-equal: the two answer different flags on that one element and nowhere else."

	^ 0.5
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> indexComponent [
	"The dispatch is one workgroup along x, so the x component of the invocation id alone
	 names the element an invocation owns."

	^ 0
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> inputBinding [
	^ 0
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> invocationIdComponents [
	"A global invocation id is three unsigned components wide, whichever of them a kernel
	 reads."

	^ 3
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> laneSplit [
	"Lanes below this one take the first arm of the selection."

	^ 4
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> localSize [
	"One workgroup of elementCount invocations along x."

	^ { self elementCount. 1. 1 }
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> matrixColumns [
	"Column major, as SPIR-V stores a matrix. The columns differ from the rows, so a multiply
	 that took its operands the other way round answers another number, and the two columns
	 of zeroes leave the component the probe reads a dot product of one column alone."

	^ #( #( 1.0 2.0 3.0 4.0 ) #( 5.0 6.0 7.0 8.0 ) #( 0.0 0.0 0.0 0.0 )
	     #( 0.0 0.0 0.0 0.0 ) )
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> opcodeSelectorPrefix [
	"Asked of SpvOpcode, which is where the naming rule lives, so the two cannot drift."

	^ SpvOpcode instructionSelectorPrefix
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> outputBinding [
	^ 1
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> predicateFlagWeights [
	"One bit a predicate, in the order emitPredicateFlags sends them, so a constant that
	 names another comparison than its selector claims changes the number by that bit alone."

	^ #( 1 2 4 8 )
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> predicateSelectors [
	"The predicates emitPredicateFlags folds, in the order predicateFlagWeights weights them."

	^ #( #emitIsHigh #emitIsPositive #emitAtLeastHalf #emitSignedDiffers )
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> sampleInputs [
	"The inputs the probe is dispatched on, which the tests and the example share. Half of
	 them are negative, so the comparison the kernel sends is straddled, and every one of
	 them carries a fraction, so a conversion that truncates can be told from one that
	 rounds."

	^ (0 to: self elementCount - 1) asArray collect: [ :each |
		  each - (self elementCount // 2) + 0.5 ]
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> scalarBitWidth [
	"Every scalar of this kernel is 32 bits wide: the buffers hold floats of that width and
	 an index is an unsigned integer of the same."

	^ 32
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> shaderCapability [
	"The serializer maps this symbol to the Shader capability number, so the module names the
	 capability rather than repeating its value."

	^ #Shader
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> unwrittenMarker [
	"What the output buffer holds before the dispatch, so a lane that wrote nothing is told
	 from one that wrote a zero."

	^ -1.0
]

{ #category : 'formula' }
PVOpcodeProbeKernel class >> valueOf: aValue at: anIndex [
	"What the kernel computes for one element, written as the plain Pharo the module is a
	 translation of: the test compares the two and a wrong opcode constant shows up here."

	| byte signed packed high group lane isLow nonPositive chosen bonus |
	byte := ((aValue max: 0.0) min: self clampCeiling) truncated.
	signed := aValue truncated.
	packed := (byte bitShift: self channelShift) bitOr: (anIndex bitAnd: self channelMask).
	high := packed bitShift: self channelShift negated.
	group := anIndex // self groupWidth.
	lane := anIndex \\ self groupWidth.
	isLow := lane < self laneSplit.
	nonPositive := aValue <= 0.0.
	chosen := isLow and: [ nonPositive ].
	bonus := (isLow or: [ nonPositive ])
		         ifTrue: [ 0.0 ]
		         ifFalse: [ self bonusValue ].
	^ (chosen
		   ifTrue: [ high ]
		   ifFalse: [ group ]) + signed + bonus + (self columnOf: aValue)
	  + (self flagsOf: aValue at: anIndex)
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> vectorTail [
	"The three components that follow the loaded value in the vector of the multiply."

	^ #( 1.0 2.0 3.0 )
]

{ #category : 'constants' }
PVOpcodeProbeKernel class >> vectorWidth [
	"The loaded value and the tail together, which is also the number of rows of the matrix."

	^ self vectorTail size + 1
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> add: aLeftId to: aRightId [
	^ self
		  binary: SpvOpcode opFAdd
		  left: aLeftId
		  right: aRightId
		  type: (self typeAt: #f32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> binary: anOpcode left: aLeftId right: aRightId type: aType [
	^ builder
		  emitBinaryOp: anOpcode
		  left: aLeftId
		  right: aRightId
		  type: aType
]

{ #category : 'building' }
PVOpcodeProbeKernel >> buildSpirv [
	"Assemble the module. The types, the buffers and the extended instruction set are
	 declared before the function, because a definition has to precede every use of its id.
	 The module's own defaults state the addressing and the memory model."

	builder := SpvBuilder new.
	builder module addCapability: self class shaderCapability.
	ids := Dictionary new.
	self declareTypes.
	self declareBuffers.
	self emitMain.
	^ builder module serialize
]

{ #category : 'reporting' }
PVOpcodeProbeKernel >> comparisonRows [
	"One row an invocation: what it was given, what the device answered and what the formula
	 answers for the same input. The difference is computed here rather than stated, so a
	 wrong opcode constant shows as a number in the last column."

	^ (1 to: self class sampleInputs size) collect: [ :each |
		  | input device expected |
		  input := self class sampleInputs at: each.
		  device := results at: each.
		  expected := self class valueOf: input at: each - 1.
		  Dictionary new
			  at: #index put: each - 1;
			  at: #input put: input;
			  at: #device put: device;
			  at: #expected put: expected;
			  at: #difference put: (device - expected) abs;
			  yourself ]
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> constantFloat: aNumber [
	^ builder constants constantFloat32: aNumber
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> constantInt: anInteger [
	^ builder constants constantInt32: anInteger
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> constantUInt: anInteger [
	^ builder constants constantUInt32: anInteger
]

{ #category : 'building' }
PVOpcodeProbeKernel >> declareBuffers [
	"Two Block-decorated structs, each holding one runtime array of floats, and the
	 invocation id. The registry hands back the same array and struct for both bindings, and
	 a type carries each decoration once, so the type is decorated here and the variables are
	 decorated one by one."

	| arrayType structType pointerType |
	ids at: #glsl put: builder importGLSL.
	arrayType := builder types runtimeArrayType: (self typeAt: #f32).
	structType := builder types structType: { arrayType }.
	pointerType := builder types
		               pointerType: SpvStorageClass storageBuffer
		               type: structType.
	types
		at: #elementPointer
		put: (builder types
				 pointerType: SpvStorageClass storageBuffer
				 type: (self typeAt: #f32)).
	builder module
		addDecoration: arrayType id
		decoration: SpvDecoration arrayStride
		literals: { self class elementStride }.
	builder module
		addDecoration: structType id
		decoration: SpvDecoration block
		literals: #(  ).
	builder module
		addMemberDecoration: structType id
		member: PVSPIRVEmitter bufferMemberIndex
		decoration: SpvDecoration offset
		literals: { PVSPIRVEmitter bufferMemberOffset }.
	ids
		at: #input
		put:
		(self newBufferVariableOfType: pointerType binding: self class inputBinding);
		at: #output
		put:
			(self
				 newBufferVariableOfType: pointerType
				 binding: self class outputBinding);
		at: #invocationId put: self newInvocationIdVariable
]

{ #category : 'building' }
PVOpcodeProbeKernel >> declareTypes [
	"Every type the body needs, kept by name. The registry deduplicates, so a type asked for
	 twice is one declaration, but naming them here keeps the emitting methods short enough
	 to read."

	types := Dictionary new.
	types
		at: #f32 put: (builder types floatType: self class scalarBitWidth);
		at: #u32
		put: (builder types intType: self class scalarBitWidth signed: false);
		at: #i32
		put: (builder types intType: self class scalarBitWidth signed: true);
		at: #bool put: builder types boolType;
		at: #void put: builder types voidType.
	types
		at: #vector
		put: (builder types
				 vectorType: (self typeAt: #f32)
				 count: self class vectorWidth).
	types
		at: #matrix
		put: (builder types
				 matrixType: (self typeAt: #vector)
				 columns: self class matrixColumns size).
	types
		at: #invocationId
		put: (builder types
				 vectorType: (self typeAt: #u32)
				 count: self class invocationIdComponents)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitAtLeastHalf [
	"Compared against halfThreshold and not against zero: one input is that value exactly, so
	 this flag differs from emitIsPositive on that element if either constant is the other one."

	^ self
		  binary: SpvOpcode opFOrdGreaterThanEqual
		  left: (self idAt: #value)
		  right: (self constantFloat: self class halfThreshold)
		  type: (self typeAt: #bool)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitBonus [
	"The negation of the disjunction, which is the only place the three logical instructions
	 can be told apart: a conjunction here would answer the same number as the negation of
	 the disjunction for half the inputs."

	^ builder
		  emitSelect: (self
				   unary: SpvOpcode opLogicalNot
				   operand: (self
						    binary: SpvOpcode opLogicalOr
						    left: (self idAt: #isLow)
						    right: (self idAt: #nonPositive)
						    type: (self typeAt: #bool))
				   type: (self typeAt: #bool))
		  ifTrue: (self constantFloat: self class bonusValue)
		  ifFalse: (self constantFloat: 0.0)
		  type: (self typeAt: #f32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitByte [
	^ self
		  unary: SpvOpcode opConvertFToU
		  operand: self emitClampedValue
		  type: (self typeAt: #u32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitChoice [
	"A selection without a branch, on the conjunction of the two predicates."

	^ builder
		  emitSelect: (self
				   binary: SpvOpcode opLogicalAnd
				   left: (self idAt: #isLow)
				   right: (self idAt: #nonPositive)
				   type: (self typeAt: #bool))
		  ifTrue: self emitHigh
		  ifFalse: self emitGroup
		  type: (self typeAt: #u32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitClampedValue [
	"The clamp is the reason both extended instructions are here, and it is also what makes
	 the conversion that follows defined: converting a negative float to an unsigned integer
	 is undefined behaviour in SPIR-V."

	^ self
		  extInst: GlslStd450 fMin
		  operands: {
				  (self
					   extInst: GlslStd450 fMax
					   operands: {
							   (self idAt: #value).
							   (self constantFloat: 0.0) }).
				  (self constantFloat: self class clampCeiling) }
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitColumn [
	"One component of the vector-times-matrix product. The multiply is here because the
	 constant that named it answered OpVectorTimesScalar, and the one its sibling named
	 answered this instruction."

	^ builder
		  emitCompositeExtract: (self
				   binary: SpvOpcode opVectorTimesMatrix
				   left: self emitVector
				   right: self emitMatrix
				   type: (self typeAt: #vector))
		  type: (self typeAt: #f32)
		  indices: { self class componentRead }
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitFormula [
	"The values every later step reads are emitted once and kept by name, so no emitting
	 method takes them as arguments. The order matters: a pointer and a load have to precede
	 the value they feed, and the lane and the signed value are read by two steps each."

	ids
		at: #index put: self emitIndex;
		at: #value put: self emitLoadedValue;
		at: #lane put: self emitLane;
		at: #signed put: self emitSignedValue;
		at: #isLow put: self emitIsLow;
		at: #nonPositive put: self emitNonPositive.
	builder emitStore: self emitTotal at: (self pointerInto: #output)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitGroup [
	^ self
		  binary: SpvOpcode opUDiv
		  left: (self idAt: #index)
		  right: (self constantUInt: self class groupWidth)
		  type: (self typeAt: #u32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitHigh [
	"The byte read back out of the packed word, which only answers the byte again if the
	 shift and the two bit operations all name the instruction they claim."

	^ self
		  binary: SpvOpcode opShiftRightLogical
		  left: self emitPacked
		  right: (self constantUInt: self class channelShift)
		  type: (self typeAt: #u32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitIndex [
	^ builder
		  emitCompositeExtract:
		  (builder
			   emitLoad: (self idAt: #invocationId) id
			   type: (self typeAt: #invocationId))
		  type: (self typeAt: #u32)
		  indices: { self class indexComponent }
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitIsHigh [
	"The other half of the lane split, read with the unsigned ordering rather than with a
	 negation of emitIsLow, so the constant it names is the one under test."

	^ self
		  binary: SpvOpcode opUGreaterThanEqual
		  left: (self idAt: #lane)
		  right: (self constantUInt: self class laneSplit)
		  type: (self typeAt: #bool)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitIsLow [
	^ self
		  binary: SpvOpcode opULessThan
		  left: (self idAt: #lane)
		  right: (self constantUInt: self class laneSplit)
		  type: (self typeAt: #bool)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitIsPositive [
	^ self
		  binary: SpvOpcode opFOrdGreaterThan
		  left: (self idAt: #value)
		  right: (self constantFloat: 0.0)
		  type: (self typeAt: #bool)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitLane [
	^ self
		  binary: SpvOpcode opUMod
		  left: (self idAt: #index)
		  right: (self constantUInt: self class groupWidth)
		  type: (self typeAt: #u32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitLoadedValue [
	^ builder emitLoad: (self pointerInto: #input) type: (self typeAt: #f32)
]

{ #category : 'building' }
PVOpcodeProbeKernel >> emitMain [
	"The entry point and its one block: the probe has no control flow, because a branch would
	 let a driver skip the very instruction the probe is checking."

	| function |
	function := builder newFunction: (self typeAt: #void).
	builder currentBlock: function addBlock.
	self emitFormula.
	builder emitReturn.
	builder
		addEntryPoint: function
		executionModel: SpvExecutionModel glCompute
		name: self class entryPointName
		interfaces: self interfaceVariables.
	builder
		addExecutionMode: function
		mode: SpvExecutionMode localSize
		literals: self class localSize
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitMatrix [
	"Column major, as SPIR-V stores a matrix: each column is a composite of constants."

	^ builder
		  emitCompositeConstruct: (self class matrixColumns collect: [ :column |
				   builder
					   emitCompositeConstruct:
					   (column collect: [ :each | self constantFloat: each ])
					   type: (self typeAt: #vector) ])
		  type: (self typeAt: #matrix)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitNonPositive [
	"The comparison the inputs straddle: half of them are negative and the oracle holds the
	 other direction, which is how the constant that answered OpFOrdGreaterThan was caught."

	^ self
		  binary: SpvOpcode opFOrdLessThanEqual
		  left: (self idAt: #value)
		  right: (self constantFloat: 0.0)
		  type: (self typeAt: #bool)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitPacked [
	"The byte shifted into place and the index masked into the low byte, which is the packing
	 a pixel of the rasteriser writes."

	^ self
		  binary: SpvOpcode opBitwiseOr
		  left: (self
				   binary: SpvOpcode opShiftLeftLogical
				   left: self emitByte
				   right: (self constantUInt: self class channelShift)
				   type: (self typeAt: #u32))
		  right: (self
				   binary: SpvOpcode opBitwiseAnd
				   left: (self idAt: #index)
				   right: (self constantUInt: self class channelMask)
				   type: (self typeAt: #u32))
		  type: (self typeAt: #u32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitPredicateFlags [
	"One bit a predicate, folded with the bitwise or, so a comparison that answers the wrong
	 way changes the total by its own weight alone and names itself."

	| flags |
	flags := nil.
	self class predicateSelectors
		with: self class predicateFlagWeights
		do: [ :selector :weight |
			| bit |
			bit := builder
				       emitSelect: (self perform: selector)
				       ifTrue: (self constantUInt: weight)
				       ifFalse: (self constantUInt: 0)
				       type: (self typeAt: #u32).
			flags := flags
				         ifNil: [ bit ]
				         ifNotNil: [ self
						         binary: SpvOpcode opBitwiseOr
						         left: flags
						         right: bit
						         type: (self typeAt: #u32) ] ].
	^ flags
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitSignedDiffers [
	"The integer inequality the winding rule reads, on the one signed value the body already
	 holds: the two inputs that truncate to zero are the elements where this flag is clear."

	^ self
		  binary: SpvOpcode opINotEqual
		  left: (self idAt: #signed)
		  right: (self constantInt: 0)
		  type: (self typeAt: #bool)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitSignedValue [
	"The signed conversion keeps the sign the clamp of emitByte throws away, so a negative
	 input still reaches the sum."

	^ self
		  unary: SpvOpcode opConvertFToS
		  operand: (self idAt: #value)
		  type: (self typeAt: #i32)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitTotal [
	"One float carrying every step, because a buffer of one element per invocation is what
	 the host reads back: the choice, the signed value and the predicate flags converted back
	 to floats, plus the bonus and the column."

	^ self
		  add: (self
				   add: (self
						    unary: SpvOpcode opConvertUToF
						    operand: self emitChoice
						    type: (self typeAt: #f32))
				   to: (self
						    unary: SpvOpcode opConvertSToF
						    operand: (self idAt: #signed)
						    type: (self typeAt: #f32)))
		  to: (self
				   add: (self add: self emitBonus to: self emitColumn)
				   to: (self
						    unary: SpvOpcode opConvertUToF
						    operand: self emitPredicateFlags
						    type: (self typeAt: #f32)))
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> emitVector [
	"The loaded value and the constant tail, so the product carries the input and a
	 transposed multiply answers a different number."

	^ builder emitCompositeConstruct: { (self idAt: #value) }
	  , (self class vectorTail collect: [ :each | self constantFloat: each ])
		  type: (self typeAt: #vector)
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> extInst: anInstructionNumber operands: anArray [
	"Every extended instruction this kernel sends answers a float, so the result type is
	 fixed here."

	^ builder
		  emitExtInst: (self idAt: #glsl)
		  op: anInstructionNumber
		  operands: anArray
		  type: (self typeAt: #f32)
]

{ #category : 'accessing' }
PVOpcodeProbeKernel >> idAt: aName [
	^ ids at: aName
]

{ #category : 'inspecting' }
PVOpcodeProbeKernel >> inspectorComparison: aBuilder [
	"The device against the formula, invocation by invocation. The difference is computed
	 here rather than stated, so a wrong opcode constant shows as a number in the last
	 column."

	<inspectorPresentationOrder: 20 title: 'Device against the formula'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Invocation' evaluated: [ :each |
					   (each at: #index) printString ]);
		  addColumn: (SpStringTableColumn title: 'Input' evaluated: [ :each |
					   (each at: #input) printString ]);
		  addColumn: (SpStringTableColumn title: 'Device' evaluated: [ :each |
					   (each at: #device) printString ]);
		  addColumn: (SpStringTableColumn title: 'Formula' evaluated: [ :each |
					   (each at: #expected) printString ]);
		  addColumn: (SpStringTableColumn title: 'Difference' evaluated: [ :each |
					   (each at: #difference) printString ]);
		  items: self comparisonRows;
		  yourself
]

{ #category : 'inspecting' }
PVOpcodeProbeKernel >> inspectorComparisonContext: aContext [
	"A kernel that was only built has nothing to compare, so the tab appears once it has run."

	aContext active: results notNil
]

{ #category : 'inspecting' }
PVOpcodeProbeKernel >> inspectorInstructions: aBuilder [
	"Which instruction the module really holds, and how many of each. The rows are counted in
	 the emitted bytes and named by reflection over SpvOpcode, so the tab cannot claim an
	 instruction the kernel stopped emitting."

	<inspectorPresentationOrder: 10 title: 'Instructions'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Instruction' evaluated: [ :each |
					   (each at: #name) asString ]);
		  addColumn: (SpStringTableColumn title: 'Opcode' evaluated: [ :each |
					   (each at: #opcode) printString ]);
		  addColumn: (SpStringTableColumn title: 'In the module' evaluated: [ :each |
					   (each at: #count) printString ]);
		  items: self instructionRows;
		  yourself
]

{ #category : 'reporting' }
PVOpcodeProbeKernel >> instructionRows [
	"One row per opcode the emitted bytes really hold, found by asking SpvOpcode for every
	 constant it declares and counting that number in the module. Nothing here names an
	 opcode of its own, so an instruction this kernel stops emitting leaves the table and one
	 it starts emitting joins it."

	| module rows |
	module := PVSpirvValidator on: self spirv.
	rows := (SpvOpcode class selectors
		         select: [ :each | each beginsWith: self class opcodeSelectorPrefix ])
		        inject: OrderedCollection new
		        into: [ :all :each |
			        | count |
			        count := module countOfOpcode: (SpvOpcode perform: each).
			        count > 0 ifTrue: [
				        all add: (self rowNamed: each count: count) ].
			        all ].
	^ rows asArray sort: [ :one :other |
		  (one at: #count) = (other at: #count)
			  ifTrue: [ (one at: #name) < (other at: #name) ]
			  ifFalse: [ (one at: #count) > (other at: #count) ] ]
]

{ #category : 'building' }
PVOpcodeProbeKernel >> interfaceVariables [
	"SPIR-V 1.4 onwards wants every module-scope variable the entry point touches named in
	 its interface list."

	^ #( #input #output #invocationId ) collect: [ :each | self idAt: each ]
]

{ #category : 'building' }
PVOpcodeProbeKernel >> newBufferVariableOfType: aPointerType binding: anInteger [
	| variable |
	variable := builder
		            addGlobalVariable: aPointerType
		            storageClass: SpvStorageClass storageBuffer.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration descriptorSet
		literals: { PVSPIRVEmitter computeDescriptorSet }.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration bindingDecoration
		literals: { anInteger }.
	^ variable
]

{ #category : 'building' }
PVOpcodeProbeKernel >> newInvocationIdVariable [
	| variable |
	variable := builder
		            addGlobalVariable: (builder types
				             pointerType: SpvStorageClass input
				             type: (self typeAt: #invocationId))
		            storageClass: SpvStorageClass input.
	builder module
		addDecoration: variable id
		decoration: SpvDecoration builtIn
		literals: { SpvBuiltIn globalInvocationId }.
	^ variable
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> pointerInto: aBufferName [
	"The element of the named buffer this invocation owns. The first index of the chain is
	 the one member of the Block struct and the second is the element."

	^ builder
		  emitAccessChain: (self idAt: aBufferName) id
		  type: (self typeAt: #elementPointer)
		  indices: {
				  (self constantUInt: PVSPIRVEmitter bufferMemberIndex).
				  (self idAt: #index) }
]

{ #category : 'printing' }
PVOpcodeProbeKernel >> printOn: aStream [
	super printOn: aStream.
	aStream
		nextPutAll: ' of ';
		print: self instructionRows size;
		nextPutAll: ' distinct instructions'
]

{ #category : 'accessing' }
PVOpcodeProbeKernel >> results [
	"What the device wrote, or nil until the probe has been dispatched."

	^ results
]

{ #category : 'reporting' }
PVOpcodeProbeKernel >> rowNamed: aSelector count: anInteger [
	^ Dictionary new
		  at: #name put: aSelector;
		  at: #opcode put: (SpvOpcode perform: aSelector);
		  at: #count put: anInteger;
		  yourself
]

{ #category : 'running' }
PVOpcodeProbeKernel >> runOn: aContext [
	"Dispatch the probe on the device of aContext and keep what came back, so a test and a
	 view can compare it with the formula. The results are read before anything is freed and
	 the kernel is destroyed before the buffers, because a buffer freed under a live pipeline
	 takes the image with it."

	| inputs input output kernel |
	inputs := self class sampleInputs.
	input := VkBuffer storageBuffer: inputs size on: aContext device.
	output := VkBuffer storageBuffer: inputs size on: aContext device.
	[
	input putF32s: inputs.
	output putF32s:
		(Array new: inputs size withAll: self class unwrittenMarker).
	kernel := PVComputeKernel on: aContext spirv: self spirv.
	kernel bindBuffer: input.
	kernel bindBuffer: output.
	kernel prepare.
	kernel dispatch: 1 y: 1 z: 1.
	results := output getF32s.
	kernel destroy ] ensure: [
		input destroy.
		output destroy ].
	^ results
]

{ #category : 'accessing' }
PVOpcodeProbeKernel >> spirv [
	"The module bytes, built once: the build allocates result ids, so a second build would
	 answer different ids for the same kernel."

	^ spirv ifNil: [ spirv := self buildSpirv ]
]

{ #category : 'accessing' }
PVOpcodeProbeKernel >> typeAt: aName [
	^ types at: aName
]

{ #category : 'emitting' }
PVOpcodeProbeKernel >> unary: anOpcode operand: anId type: aType [
	^ builder emitUnaryOp: anOpcode operand: anId type: aType
]
