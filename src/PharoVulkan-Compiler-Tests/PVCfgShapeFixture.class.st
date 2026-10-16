"
Kernels with known control-flow graph shapes, used to pin the exact boundary of PVStructuredCFGRecognizer. These are deliberately not in PVKernelExamples: nobody should run them, each one exists only because its CFG shape has a known expected verdict, either a valid SPIR-V module or PVTypeError. The selector names the shape.
"
Class {
	#name : 'PVCfgShapeFixture',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler-Tests-Fixtures',
	#package : 'PharoVulkan-Compiler-Tests',
	#tag : 'Fixtures'
}

{ #category : 'recognised shapes' }
PVCfgShapeFixture >> computeLoopSum: aWorkItem data: aBuffer out: anOutput [
	"One whileTrue: in a compute kernel. The loop was flattened to a single pass before
	 the compute path ran the recogniser, and the module still passed spirv-val."

	<gpu>
	<param: #workItem named: #aWorkItem>
	<param: #bufferOf_f32 named: #aBuffer>
	<param: #bufferOf_f32 named: #anOutput>
	| i acc |
	i := 0.
	acc := 0.0.
	[ i < 16 ] whileTrue: [
		acc := acc + (aBuffer at: i).
		i := i + 1 ].
	anOutput at: aWorkItem x put: acc
]

{ #category : 'recognised shapes' }
PVCfgShapeFixture >> computeNestedLoops: aWorkItem data: aBuffer out: anOutput [
	"Loop inside a loop body, in a compute kernel. The one nesting shape the recogniser
	 matches, added for the tiled matmul: the outer body is the inner loop and nothing
	 else. The scalar path still refuses the shape, see nestedLoops:."

	<gpu>
	<param: #workItem named: #aWorkItem>
	<param: #bufferOf_f32 named: #aBuffer>
	<param: #bufferOf_f32 named: #anOutput>
	| i j acc |
	i := 0.
	acc := 0.0.
	[ i < 4 ] whileTrue: [
		j := 0.
		[ j < 4 ] whileTrue: [
			acc := acc + (aBuffer at: j).
			j := j + 1 ].
		i := i + 1 ].
	anOutput at: aWorkItem x put: acc
]

{ #category : 'recognised shapes' }
PVCfgShapeFixture >> computeSelectionClamp: aWorkItem data: aBuffer out: anOutput [
	"One ifTrue:ifFalse: in a compute kernel. Raised PVTypeError: No mapping for at:put:
	 before the compute path ran the recogniser, because type inference saw the register
	 numbering of the whole-method simulation rather than of the blocks."

	<gpu>
	<param: #workItem named: #aWorkItem>
	<param: #bufferOf_f32 named: #aBuffer>
	<param: #bufferOf_f32 named: #anOutput>
	| v r |
	v := aBuffer at: aWorkItem x.
	r := v < 0.0 ifTrue: [ 0.0 ] ifFalse: [ v ].
	anOutput at: aWorkItem x put: r
]

{ #category : 'rejected shapes' }
PVCfgShapeFixture >> computeTwoSequentialSelections: aWorkItem data: aBuffer out: anOutput [
	"Two selections one after the other, in a compute kernel. The sequence case is the one
	 the coverage check in PVStructuredCFGRecognizer exists to refuse."

	<gpu>
	<param: #workItem named: #aWorkItem>
	<param: #bufferOf_f32 named: #aBuffer>
	<param: #bufferOf_f32 named: #anOutput>
	| v r |
	v := aBuffer at: aWorkItem x.
	r := v < 0.0 ifTrue: [ 0.0 ] ifFalse: [ v ].
	r := r < 1.0 ifTrue: [ r ] ifFalse: [ 1.0 ].
	anOutput at: aWorkItem x put: r
]

{ #category : 'rejected shapes' }
PVCfgShapeFixture >> loopThenSelection: n [
	"A loop followed by a selection. Emitted a module returning a bool from a function
	 declared to return an int before the coverage check was added."

	<gpu>
	<param: #i32 named: #n>
	| i sum |
	sum := 0.
	i := 1.
	[ i <= n ] whileTrue: [
		sum := sum + i.
		i := i + 1 ].
	^ sum < 5 ifTrue: [ 0 ] ifFalse: [ sum ]
]

{ #category : 'rejected shapes' }
PVCfgShapeFixture >> nestedLoops: n [
	"Loop inside a loop body."

	<gpu>
	<param: #i32 named: #n>
	| i j sum |
	sum := 0.
	i := 1.
	[ i <= n ] whileTrue: [
		j := 1.
		[ j <= n ] whileTrue: [
			sum := sum + 1.
			j := j + 1 ].
		i := i + 1 ].
	^ sum
]

{ #category : 'rejected shapes' }
PVCfgShapeFixture >> nestedSelection: x [
	"Selection inside the true arm of a selection."

	<gpu>
	<param: #f32 named: #x>
	^ x < 1.0
		ifTrue: [ x < 0.5 ifTrue: [ 0.25 ] ifFalse: [ 0.75 ] ]
		ifFalse: [ 0.0 ]
]

{ #category : 'recognised shapes' }
PVCfgShapeFixture >> oneLoop: n [
	"Single whileTrue:, the shape PVLoopNode represents."

	<gpu>
	<param: #i32 named: #n>
	| i sum |
	sum := 0.
	i := 1.
	[ i <= n ] whileTrue: [
		sum := sum + i.
		i := i + 1 ].
	^ sum
]

{ #category : 'recognised shapes' }
PVCfgShapeFixture >> oneSelection: x [
	"Single ifTrue:ifFalse:, the shape PVSelectionNode represents."

	<gpu>
	<param: #f32 named: #x>
	^ x < 1.0 ifTrue: [ 1.0 ] ifFalse: [ 0.0 ]
]

{ #category : 'rejected shapes' }
PVCfgShapeFixture >> selectionInLoop: n [
	"Selection inside a loop body."

	<gpu>
	<param: #i32 named: #n>
	| i sum |
	sum := 0.
	i := 1.
	[ i <= n ] whileTrue: [
		sum := i < 3 ifTrue: [ sum + 1 ] ifFalse: [ sum + 2 ].
		i := i + 1 ].
	^ sum
]

{ #category : 'rejected shapes' }
PVCfgShapeFixture >> twoSequentialSelections: x [
	"Two selections one after the other. Compiled to the first one alone before the
	 coverage check was added to PVStructuredCFGRecognizer."

	<gpu>
	<param: #f32 named: #x>
	| r |
	r := x < 1.0 ifTrue: [ 1.0 ] ifFalse: [ 0.0 ].
	r := r < 0.5 ifTrue: [ 2.0 ] ifFalse: [ 3.0 ].
	^ r
]
