"
SPIR-V cooperative matrix type, OpTypeCooperativeMatrixKHR. A cooperative matrix is held jointly by all the invocations of a scope — a subgroup here — so no invocation owns the whole matrix and the shape is part of the type rather than of the instruction.

A kernel cannot pick its own shape: it must name one of the rows, columns and component type combinations the device reports through vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR, which `VkCooperativeMatrixConfiguration` decodes. The Use operand separates the three roles of a multiply-accumulate, so A, B and the accumulator are distinct types even where their component type and shape agree; `matrixAUse`, `matrixBUse` and `matrixAccumulatorUse` name the values. Scope, rows, columns and use are ids of constants, not literals, which is why `instruction` asks the module's constant pool. Key methods: componentType, scope, rows, columns, use, instruction.
"
Class {
	#name : 'SpvCooperativeMatrixType',
	#superclass : 'SpvType',
	#instVars : [
		'componentType',
		'shape'
	],
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'constants' }
SpvCooperativeMatrixType class >> columnMajorLayout [
	"CooperativeMatrixLayout ColumnMajorKHR = 1."

	^ 1
]

{ #category : 'constants' }
SpvCooperativeMatrixType class >> matrixAUse [
	"CooperativeMatrixUse MatrixAKHR = 0, the left operand of a multiply-accumulate."

	^ 0
]

{ #category : 'constants' }
SpvCooperativeMatrixType class >> matrixAccumulatorUse [
	"CooperativeMatrixUse MatrixAccumulatorKHR = 2, the operand a multiply-accumulate adds
	 into and answers."

	^ 2
]

{ #category : 'constants' }
SpvCooperativeMatrixType class >> matrixBUse [
	"CooperativeMatrixUse MatrixBKHR = 1, the right operand of a multiply-accumulate."

	^ 1
]

{ #category : 'constants' }
SpvCooperativeMatrixType class >> rowMajorLayout [
	"CooperativeMatrixLayout RowMajorKHR = 0: consecutive elements of a row sit next to each
	 other in memory, and the stride counts elements between rows."

	^ 0
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> columns [
	^ shape columns
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> componentType [
	^ componentType
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> componentType: anObject [
	componentType := anObject
]

{ #category : 'inspector' }
SpvCooperativeMatrixType >> inspectorInstruction: aBuilder [
	"The operands of the OpTypeCooperativeMatrixKHR this type emits: the component type id
	 first, then the ids of the scope, rows, columns and use constants. Every one of them is
	 an id, which is why none of these numbers reads as the shape itself."

	<inspectorPresentationOrder: 10 title: 'Instruction'>
	^ PVFactRow
		  tableOf: self instructionRows
		  nameColumn: 'Position'
		  valueColumn: 'Operand id'
		  in: aBuilder
]

{ #category : 'encoding' }
SpvCooperativeMatrixType >> instruction [
	"Scope, rows, columns and use are ids of unsigned constants rather than literals, so the
	 module declares each of them like any other constant and the serialiser emits them
	 before this type. The constant pool deduplicates, so a second matrix of the same shape
	 names the same constants."

	^ SpvInstruction
		  opcode: SpvOpcode opTypeCooperativeMatrixKHR
		  resultType: nil
		  resultId: id
		  operands: { componentType id } , (shape constantValues collect: [ :each |
			   module constantPool constantUInt32: each ])
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> instructionRows [
	"The instruction this type emits, operand by operand, asked of the instruction itself so
	 a row cannot describe an operand order the serialiser does not use."

	^ self instruction operands withIndexCollect: [ :operand :index |
		  PVFactRow name: index value: operand ]
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> key [
	"The component type and the shape together: A, B and the accumulator are different types
	 even when they share a component type, because their use differs."

	^ Array with: #cooperativeMatrix with: componentType id with: shape key
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> rows [
	^ shape rows
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> scope [
	^ shape scope
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> shape [
.
	^ shape
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> shape: aShape [
.
	shape := aShape
]

{ #category : 'accessing' }
SpvCooperativeMatrixType >> use [
	^ shape use
]
