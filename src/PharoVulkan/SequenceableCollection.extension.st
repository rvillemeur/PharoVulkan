Extension { #name : 'SequenceableCollection' }

{ #category : '*PharoVulkan' }
SequenceableCollection >> coopMatLoad: anElementIndex [
	"Extension on SequenceableCollection: the kernel DSL''s cooperative matrix load. It
	 lives here rather than upstream because a cooperative matrix is this project''s
	 concept, and a kernel body must mean the same thing when it runs in the image as
	 when it runs on the device. The index counts elements from zero, as a kernel does,
	 and the matrix is read row by row with one order between rows, which is the
	 row-major layout the emitted load uses."

	| order |
	order := PVCooperativeMatrixKernel matrixOrder.
	^ PVCooperativeMatrix
		  order: order
		  elements:
		  ((1 to: order * order) collect: [ :each |
			   (self at: anElementIndex + each) asFloat ])
]

{ #category : '*PharoVulkan' }
SequenceableCollection >> coopMatStore: aCooperativeMatrix [
	"Extension on SequenceableCollection: the kernel DSL''s cooperative matrix store,
	 the twin of coopMatLoad:. It writes at the start of the receiver, which is where
	 the emitted store writes, and answers the receiver."

	aCooperativeMatrix elements doWithIndex: [ :each :index |
		self at: index put: each ].
	^ self
]
