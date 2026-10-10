"
The host meaning of a cooperative matrix: a square matrix of floats, held flat and row-major, which is what `coopMatLoad:` answers when a kernel body runs in the image instead of on a device.

On a device a cooperative matrix is spread over a subgroup and no invocation holds the whole of it, which is why SPIR-V gives it its own type and its own load, store and multiply-accumulate instructions. In one Pharo process there is no subgroup, so the honest host twin is the whole matrix in one object and an ordinary triple loop for the product.

Send `coopMatLoad:` to a collection to build one, `coopMatMulAdd:` to multiply two, and `coopMatStore:` to write one back into a collection. `order` is the matrix order, 8 here because that is the one M, N, K combination the device reports; see PVCooperativeMatrixKernel.
"
Class {
	#name : 'PVCooperativeMatrix',
	#superclass : 'Object',
	#instVars : [
		'order',
		'elements'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'examples' }
PVCooperativeMatrix class >> exampleProductOfTheHostTwin [
	"One click: the eight by eight product the DSL kernel computes, worked out in the
	 image rather than on a device. The left matrix is a ramp and the right one the
	 identity, so the product reads back as the ramp."

	<sampleInstance>
	| order ramp identity |
	order := PVCooperativeMatrixKernel matrixOrder.
	ramp := PVCooperativeMatrixKernel exampleRampMatrix coopMatLoad: 0.
	identity := PVCooperativeMatrixKernel exampleIdentityMatrix coopMatLoad: 0.
	^ ramp coopMatMulAdd: identity
]

{ #category : 'instance creation' }
PVCooperativeMatrix class >> order: anOrder elements: aCollection [
	"The elements are copied, so a matrix cannot change under its holder when the buffer
	 it was loaded from is written to."

	aCollection size = (anOrder * anOrder) ifFalse: [
		^ PVTypeError signal: 'A cooperative matrix of order ' , anOrder printString
			  , ' needs ' , (anOrder * anOrder) printString , ' elements' ].
	^ self new setOrder: anOrder elements: aCollection asArray copy; yourself
]

{ #category : 'accessing' }
PVCooperativeMatrix >> atRow: aRow col: aColumn [
	"Rows and columns count from zero, as they do in a kernel body."

	^ elements at: aRow * order + aColumn + 1
]

{ #category : 'arithmetic' }
PVCooperativeMatrix >> coopMatMulAdd: aMatrix [
	"The host twin of OpCooperativeMatrixMulAddKHR: the receiver times the argument,
	 added to a zero accumulator, which is the product. The order of the two matrices
	 must agree, since the device offers one M, N, K combination and a kernel has to use
	 it exactly."

	| product |
	aMatrix order = order ifFalse: [
		^ PVTypeError signal: 'A cooperative matrix product needs two matrices of one order' ].
	product := Array new: order * order.
	0 to: order - 1 do: [ :row |
		0 to: order - 1 do: [ :column |
			product
				at: row * order + column + 1
				put: ((0 to: order - 1) inject: 0.0 into: [ :accumulated :k |
						 accumulated + ((self atRow: row col: k)
							  * (aMatrix atRow: k col: column)) ]) ] ].
	^ self class order: order elements: product
]

{ #category : 'accessing' }
PVCooperativeMatrix >> elements [
	^ elements
]

{ #category : 'inspector' }
PVCooperativeMatrix >> inspectorRows: aBuilder [
	"The matrix as its own rows, read through atRow:col: rather than out of the flat
	 collection, so the tab cannot disagree with the accessor a kernel body uses."

	<inspectorPresentationOrder: 10 title: 'Rows'>
	| rows |
	rows := (0 to: order - 1) collect: [ :row |
		         (0 to: order - 1) collect: [ :column |
			         self atRow: row col: column ] ].
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Row'
				   evaluated: [ :each | (rows indexOf: each) - 1 ]);
		  addColumn: (SpStringTableColumn
				   title: 'Elements'
				   evaluated: [ :each |
					   ', ' join: (each collect: [ :one | one printString ]) ]);
		  items: rows;
		  yourself
]

{ #category : 'accessing' }
PVCooperativeMatrix >> order [
	^ order
]

{ #category : 'printing' }
PVCooperativeMatrix >> printOn: aStream [
	aStream
		nextPutAll: self class name;
		nextPutAll: ' of order ';
		print: order
]

{ #category : 'initialization' }
PVCooperativeMatrix >> setOrder: anOrder elements: anArray [
	order := anOrder.
	elements := anArray
]
