"
The four operands besides the component type that make one OpTypeCooperativeMatrixKHR: rows, columns, the scope the matrix is held across, and the role the matrix plays in a multiply-accumulate. They travel together because a kernel may not mix them freely: the device reports whole combinations through vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR, and A, B and the accumulator of one combination differ in use while sharing a scope.

`key` is what lets SpvTypeRegistry hand back the same type twice, and `constantValues` names the operands a type declares as constants rather than as literals. Key methods: rows, columns, scope, use, constantValues, key.
"
Class {
	#name : 'SpvCooperativeMatrixShape',
	#superclass : 'Object',
	#instVars : [
		'rows',
		'columns',
		'scope',
		'use'
	],
	#category : 'PharoVulkan-SPIRV-Types',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Types'
}

{ #category : 'constants' }
SpvCooperativeMatrixShape class >> canonicalOrder [
	"The one M, N, K combination the target device reports for VK_KHR_cooperative_matrix: M8 N8 K8,
	 square, so one number covers all three. A kernel must name a reported shape exactly, and both
	 the hand-built kernel and the compiled one take their shape from here — the value belongs to
	 the SPIR-V type that models the shape rather than to either reader."

	^ 8
]

{ #category : 'instance creation' }
SpvCooperativeMatrixShape class >> rows: rowCount columns: columnCount scope: aScope use: aUse [
	^ self new
		  setRows: rowCount
		  columns: columnCount
		  scope: aScope
		  use: aUse
]

{ #category : 'accessing' }
SpvCooperativeMatrixShape >> columns [
	^ columns
]

{ #category : 'accessing' }
SpvCooperativeMatrixShape >> constantValues [
	"The operands a cooperative matrix type names by id rather than as literals, so the
	 module declares each of them as an unsigned constant."

	^ {
		  scope.
		  rows.
		  columns.
		  use }
]

{ #category : 'inspector' }
SpvCooperativeMatrixShape >> inspectorOperands: aBuilder [
	"What this shape contributes to an OpTypeCooperativeMatrixKHR, beside the component
	 type. Each value comes from the accessor the instruction itself asks."

	<inspectorPresentationOrder: 10 title: 'Operands'>
	^ PVFactRow
		  tableOf: self operandRows
		  nameColumn: 'Operand'
		  valueColumn: 'Value'
		  in: aBuilder
]

{ #category : 'accessing' }
SpvCooperativeMatrixShape >> key [
	"Two shapes are the same type only when all four agree: A, B and the accumulator differ
	 in use alone."

	^ Array
		  with: rows
		  with: columns
		  with: scope
		  with: use
]

{ #category : 'accessing' }
SpvCooperativeMatrixShape >> operandRows [
	"The four operands, each asked of its own accessor, so a row cannot drift from the value
	 the type emits."

	^ { #rows. #columns. #scope. #use } collect: [ :each |
		  PVFactRow name: each value: (self perform: each) ]
]

{ #category : 'printing' }
SpvCooperativeMatrixShape >> printOn: aStream [
	aStream
		print: rows;
		nextPutAll: ' by ';
		print: columns;
		nextPutAll: ', scope ';
		print: scope;
		nextPutAll: ', use ';
		print: use
]

{ #category : 'accessing' }
SpvCooperativeMatrixShape >> rows [
	^ rows
]

{ #category : 'accessing' }
SpvCooperativeMatrixShape >> scope [
	^ scope
]

{ #category : 'initialization' }
SpvCooperativeMatrixShape >> setRows: rowCount columns: columnCount scope: aScope use: aUse [
	rows := rowCount.
	columns := columnCount.
	scope := aScope.
	use := aUse
]

{ #category : 'accessing' }
SpvCooperativeMatrixShape >> use [
	^ use
]
