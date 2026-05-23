Class {
	#name : 'PVKernelExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'examples' }
PVKernelExamples >> accumulateUpTo: n [
	<gpu>
	<param: #i32 named: #n>
	| sum i |
	sum := 0.
	i := 1.
	[ i <= n ] whileTrue: [ sum := sum + i. i := i + 1 ].
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
