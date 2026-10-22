"
Named constants for SPIR-V opcodes. All methods are class-side.
Phase 1 subset is hand-written; full set generated from spirv.core.grammar.json in Phase 1A.
Key methods: opCapability, opTypeVoid, opTypeFloat, opFAdd, opLoad, opStore, etc. (class-side).
"
Class {
	#name : 'SpvOpcode',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV-Constants',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Constants'
}

{ #category : 'memory' }
SpvOpcode class >> opAccessChain [         ^ 65
]

{ #category : 'bits' }
SpvOpcode class >> opBitwiseAnd [
	"Bitwise and, which is how a channel is taken out of a packed pixel word."

	^ 199
]

{ #category : 'bits' }
SpvOpcode class >> opBitwiseOr [
	"Bitwise or, which is how a pixel word is packed from its channels."

	^ 197
]

{ #category : 'control-flow' }
SpvOpcode class >> opBranch [              ^ 249
]

{ #category : 'control-flow' }
SpvOpcode class >> opBranchConditional [   ^ 250
]

{ #category : 'module' }
SpvOpcode class >> opCapability [          ^ 17
]

{ #category : 'composite' }
SpvOpcode class >> opCompositeConstruct [  ^ 80
]

{ #category : 'composite' }
SpvOpcode class >> opCompositeExtract [    ^ 81
]

{ #category : 'constants' }
SpvOpcode class >> opConstant [            ^ 43
]

{ #category : 'constants' }
SpvOpcode class >> opConstantFalse [       ^ 42
]

{ #category : 'constants' }
SpvOpcode class >> opConstantNull [        ^ 46
]

{ #category : 'constants' }
SpvOpcode class >> opConstantTrue [        ^ 41
]

{ #category : 'constants' }
SpvOpcode class >> opControlBarrier [
	"OpControlBarrier, the neighbour of OpMemoryBarrier 225. Every invocation of the
	 execution scope must reach it before any of them continues, and it carries memory
	 semantics so the shared memory written before it is visible after it."

	^ 224
]

{ #category : 'converting' }
SpvOpcode class >> opConvertFToS [
	"A float truncated towards zero into a signed integer."

	^ 110
]

{ #category : 'converting' }
SpvOpcode class >> opConvertFToU [
	"A float truncated towards zero into an unsigned integer. The float must not be negative:
	 the result is undefined where it is."

	^ 109
]

{ #category : 'converting' }
SpvOpcode class >> opConvertSToF [

	^ 111
]

{ #category : 'converting' }
SpvOpcode class >> opConvertUToF [         ^ 112
]

{ #category : 'memory' }
SpvOpcode class >> opCooperativeMatrixLoadKHR [
	"OpCooperativeMatrixLoadKHR = 4457. Operands: pointer, memory layout, stride."

	^ 4457
]

{ #category : 'arithmetic' }
SpvOpcode class >> opCooperativeMatrixMulAddKHR [
	"OpCooperativeMatrixMulAddKHR = 4459. Operands: the A, B and accumulator matrices."

	^ 4459
]

{ #category : 'memory' }
SpvOpcode class >> opCooperativeMatrixStoreKHR [
	"OpCooperativeMatrixStoreKHR = 4458. Operands: pointer, object, memory layout, stride."

	^ 4458
]

{ #category : 'annotations' }
SpvOpcode class >> opDecorate [            ^ 71
]

{ #category : 'arithmetic' }
SpvOpcode class >> opDot [                 ^ 148
]

{ #category : 'module' }
SpvOpcode class >> opEntryPoint [          ^ 15
]

{ #category : 'module' }
SpvOpcode class >> opExecutionMode [       ^ 16
]

{ #category : 'module' }
SpvOpcode class >> opExtInst [             ^ 12
]

{ #category : 'module' }
SpvOpcode class >> opExtInstImport [       ^ 11
]

{ #category : 'module' }
SpvOpcode class >> opExtension [           ^ 10
]

{ #category : 'arithmetic' }
SpvOpcode class >> opFAdd [                ^ 129
]

{ #category : 'converting' }
SpvOpcode class >> opFConvert [          ^ 115
]

{ #category : 'arithmetic' }
SpvOpcode class >> opFDiv [                ^ 136
]

{ #category : 'arithmetic' }
SpvOpcode class >> opFMul [                ^ 133
]

{ #category : 'comparison' }
SpvOpcode class >> opFOrdEqual [           ^ 180
]

{ #category : 'comparison' }
SpvOpcode class >> opFOrdGreaterThan [
	"This is the number opFOrdLessThanEqual held, which is why a module whose comparisons ran
	 the other way round was accepted by the validator: the two take the same operands.
	 Checked by assembling the instruction by name with spirv-as."

	^ 186
]

{ #category : 'comparison' }
SpvOpcode class >> opFOrdGreaterThanEqual [
	"The ordered comparison an edge is tested against a sub-row with: an edge is taken from
	 its upper end inclusive, so the bound belongs to the test. Checked by assembling the
	 instruction by name with spirv-as."

	^ 190
]

{ #category : 'comparison' }
SpvOpcode class >> opFOrdLessThan [        ^ 184
]

{ #category : 'comparison' }
SpvOpcode class >> opFOrdLessThanEqual [
	"Was 186, which is OpFOrdGreaterThan: the two comparisons take the same operands, so
	 spirv-val accepted the module and every f32 <= of a compiled kernel ran the other way
	 round. The numbers of this class are checked by assembling the instruction by name with
	 spirv-as and reading the opcode word back."

	^ 188
]

{ #category : 'arithmetic' }
SpvOpcode class >> opFSub [                ^ 131
]

{ #category : 'functions' }
SpvOpcode class >> opFunction [            ^ 54
]

{ #category : 'functions' }
SpvOpcode class >> opFunctionCall [        ^ 57
]

{ #category : 'functions' }
SpvOpcode class >> opFunctionEnd [         ^ 56
]

{ #category : 'functions' }
SpvOpcode class >> opFunctionParameter [   ^ 55
]

{ #category : 'group-operations' }
SpvOpcode class >> opGroupNonUniformFAdd [
	"OpGroupNonUniformFAdd, the floating point neighbour of OpGroupNonUniformIAdd 349. It
	 takes an execution scope id, a group operation literal and the value this lane holds."

	^ 350
]

{ #category : 'arithmetic' }
SpvOpcode class >> opIAdd [                ^ 128
]

{ #category : 'comparison' }
SpvOpcode class >> opIEqual [              ^ 170
]

{ #category : 'arithmetic' }
SpvOpcode class >> opIMul [                ^ 132
]

{ #category : 'comparison' }
SpvOpcode class >> opINotEqual [
	"Integer inequality, the test a winding number of the winding rule is read by: a winding
	 of zero is outside and anything else is inside. Checked by assembling the instruction by
	 name with spirv-as."

	^ 171
]

{ #category : 'arithmetic' }
SpvOpcode class >> opISub [                ^ 130
]

{ #category : 'control-flow' }
SpvOpcode class >> opLabel [               ^ 248
]

{ #category : 'memory' }
SpvOpcode class >> opLoad [                ^ 61
]

{ #category : 'logic' }
SpvOpcode class >> opLogicalAnd [
	"And of two booleans. The bitwise instructions do not apply to a bool."

	^ 167
]

{ #category : 'logic' }
SpvOpcode class >> opLogicalNot [
	"Negation of a boolean."

	^ 168
]

{ #category : 'logic' }
SpvOpcode class >> opLogicalOr [
	"Or of two booleans."

	^ 166
]

{ #category : 'control-flow' }
SpvOpcode class >> opLoopMerge [           ^ 246
]

{ #category : 'generated' }
SpvOpcode class >> opMatrixTimesMatrix [ ^ 146
]

{ #category : 'generated' }
SpvOpcode class >> opMatrixTimesVector [
	"Was 144, which is OpVectorTimesMatrix: the two instructions take their operands in
	 opposite orders, so the one matrix multiply the selector table maps emitted a module the
	 validator rejected. Checked by assembling the instruction by name with spirv-as."

	^ 145
]

{ #category : 'annotations' }
SpvOpcode class >> opMemberDecorate [      ^ 72
]

{ #category : 'module' }
SpvOpcode class >> opMemoryModel [         ^ 14
]

{ #category : 'opcodes' }
SpvOpcode class >> opPhi [
	^ 245
]

{ #category : 'control-flow' }
SpvOpcode class >> opReturn [              ^ 253
]

{ #category : 'control-flow' }
SpvOpcode class >> opReturnValue [         ^ 254
]

{ #category : 'arithmetic' }
SpvOpcode class >> opSDiv [                ^ 135
]

{ #category : 'comparison' }
SpvOpcode class >> opSLessThan [           ^ 177
]

{ #category : 'comparison' }
SpvOpcode class >> opSLessThanEqual [      ^ 179
]

{ #category : 'arithmetic' }
SpvOpcode class >> opSMod [                ^ 139
]

{ #category : 'logic' }
SpvOpcode class >> opSelect [
	"One of two values by a boolean, with no branch and so no merge block, which is what an
	 invocation that may not diverge from its neighbours needs."

	^ 169
]

{ #category : 'control-flow' }
SpvOpcode class >> opSelectionMerge [      ^ 247
]

{ #category : 'bits' }
SpvOpcode class >> opShiftLeftLogical [
	"Shift towards the high bits, filling with zeroes."

	^ 196
]

{ #category : 'bits' }
SpvOpcode class >> opShiftRightLogical [
	"Shift towards the low bits, filling with zeroes, which is the shift an unsigned channel needs."

	^ 194
]

{ #category : 'memory' }
SpvOpcode class >> opStore [               ^ 62
]

{ #category : 'types' }
SpvOpcode class >> opTypeArray [           ^ 28
]

{ #category : 'types' }
SpvOpcode class >> opTypeBool [            ^ 20
]

{ #category : 'types' }
SpvOpcode class >> opTypeCooperativeMatrixKHR [
	"OpTypeCooperativeMatrixKHR = 4456, from the SPV_KHR_cooperative_matrix extension. The
	 number was read back out of a module spirv-as assembled, not recalled."

	^ 4456
]

{ #category : 'types' }
SpvOpcode class >> opTypeFloat [           ^ 22
]

{ #category : 'types' }
SpvOpcode class >> opTypeFunction [        ^ 33
]

{ #category : 'types' }
SpvOpcode class >> opTypeInt [             ^ 21
]

{ #category : 'types' }
SpvOpcode class >> opTypeMatrix [          ^ 24
]

{ #category : 'types' }
SpvOpcode class >> opTypePointer [         ^ 32
]

{ #category : 'types' }
SpvOpcode class >> opTypeRuntimeArray [    ^ 29
]

{ #category : 'types' }
SpvOpcode class >> opTypeStruct [          ^ 30
]

{ #category : 'types' }
SpvOpcode class >> opTypeVector [          ^ 23
]

{ #category : 'types' }
SpvOpcode class >> opTypeVoid [            ^ 19
]

{ #category : 'arithmetic' }
SpvOpcode class >> opUDiv [
	"Unsigned division, which is what an index derived from an invocation identifier needs."

	^ 134
]

{ #category : 'comparison' }
SpvOpcode class >> opUGreaterThanEqual [
	"Unsigned comparison the other way round from opULessThan, which a loop that counts down
	 to a bound needs. Checked by assembling the instruction by name with spirv-as."

	^ 174
]

{ #category : 'constants' }
SpvOpcode class >> opULessThan [
	"The unsigned neighbour of OpSLessThan 177. Loop counters built from a built-in
	 invocation id are unsigned, so an unsigned comparison is the one that cannot wrap."

	^ 176
]

{ #category : 'arithmetic' }
SpvOpcode class >> opUMod [
	"Unsigned remainder, the companion of opUDiv."

	^ 137
]

{ #category : 'constants' }
SpvOpcode class >> opUndef [               ^ 1
]

{ #category : 'memory' }
SpvOpcode class >> opVariable [            ^ 59
]

{ #category : 'generated' }
SpvOpcode class >> opVectorTimesMatrix [
	"Was 142, which is OpVectorTimesScalar. Checked by assembling the instruction by name with
	 spirv-as."

	^ 144
]
