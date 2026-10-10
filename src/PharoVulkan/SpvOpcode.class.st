"
Named constants for SPIR-V opcodes. All methods are class-side.
Phase 1 subset is hand-written; full set generated from spirv.core.grammar.json in Phase 1A.
Key methods: opCapability, opTypeVoid, opTypeFloat, opFAdd, opLoad, opStore, etc. (class-side).
"
Class {
	#name : 'SpvOpcode',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'memory' }
SpvOpcode class >> opAccessChain [         ^ 65
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
SpvOpcode class >> opFOrdLessThan [        ^ 184
]

{ #category : 'comparison' }
SpvOpcode class >> opFOrdLessThanEqual [   ^ 186
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

{ #category : 'arithmetic' }
SpvOpcode class >> opISub [                ^ 130
]

{ #category : 'control-flow' }
SpvOpcode class >> opLabel [               ^ 248
]

{ #category : 'memory' }
SpvOpcode class >> opLoad [                ^ 61
]

{ #category : 'control-flow' }
SpvOpcode class >> opLoopMerge [           ^ 246
]

{ #category : 'generated' }
SpvOpcode class >> opMatrixTimesMatrix [ ^ 146
]

{ #category : 'generated' }
SpvOpcode class >> opMatrixTimesVector [ ^ 144
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

{ #category : 'control-flow' }
SpvOpcode class >> opSelectionMerge [      ^ 247
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

{ #category : 'constants' }
SpvOpcode class >> opULessThan [
	"The unsigned neighbour of OpSLessThan 177. Loop counters built from a built-in
	 invocation id are unsigned, so an unsigned comparison is the one that cannot wrap."

	^ 176
]

{ #category : 'constants' }
SpvOpcode class >> opUndef [               ^ 1
]

{ #category : 'memory' }
SpvOpcode class >> opVariable [            ^ 59
]

{ #category : 'generated' }
SpvOpcode class >> opVectorTimesMatrix [ ^ 142
]
