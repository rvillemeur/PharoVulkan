"
Kernels with known control-flow graph shapes, used to pin the exact boundary of PVStructuredCFGRecognizer. These are deliberately not in PVKernelExamples: nobody should run them, each one exists only because its CFG shape has a known expected verdict, either a valid SPIR-V module or PVTypeError. The selector names the shape.
"
Class {
	#name : 'PVCfgShapeFixture',
	#superclass : 'Object',
	#category : 'PharoVulkan-Tests-Compiler',
	#package : 'PharoVulkan-Tests',
	#tag : 'Compiler'
}

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
