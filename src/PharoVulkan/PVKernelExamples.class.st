"
Example GPU kernels used for integration testing and demonstration. Each method carries <gpu> and <param:> pragmas and exercises a specific compiler feature (arithmetic, control flow, etc.).
"
Class {
	#name : 'PVKernelExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Example',
	#package : 'PharoVulkan',
	#tag : 'Example'
}

{ #category : 'examples' }
PVKernelExamples >> accumulateUpTo: n [
	<gpu>
	<param: #i32 named: #n>
	| sum |
	sum := 0.
	1 to: n do: [ :i | sum := sum + i ].
	sum := sum + n.
	"i := 1.
	[ i <= n ] whileTrue: [ sum := sum + i. i := i + 1 ]."
	^ sum
]

{ #category : 'kernels' }
PVKernelExamples >> addFloat: a to: b [
	<gpu>
	<param: #f32 named: #a>
	<param: #f32 named: #b>
	^ a + b
]

{ #category : 'kernels' }
PVKernelExamples >> addInt: a to: b [
	<gpu>
	<param: #i32 named: #a>
	<param: #i32 named: #b>
	^ a + b
]

{ #category : 'kernels' }
PVKernelExamples >> mulFloat: a by: b [
	<gpu>
	<param: #f32 named: #a>
	<param: #f32 named: #b>
	^ a * b
]

{ #category : 'kernels' }
PVKernelExamples >> relu: x [
	<gpu>
	<param: #f32 named: #x>
	^ x < 0.0 ifTrue: [ 0.0 ] ifFalse: [ x ]
]

{ #category : 'kernels' }
PVKernelExamples >> vectorAdd: wi a: a b: b out: output [
<gpu>
<param: #workItem named: #wi>
<param: #bufferOf_f32 named: #a>
<param: #bufferOf_f32 named: #b>
<param: #bufferOf_f32 named: #output>
| idx |
idx := wi x.
output at: idx put: (a at: idx) + (b at: idx)
]
