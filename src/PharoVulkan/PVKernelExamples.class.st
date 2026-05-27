"
Example GPU kernels used for integration testing and demonstration. Each method carries <gpu> and <param:> pragmas and exercises a specific compiler feature (arithmetic, control flow, etc.).
"
Class {
	#name : 'PVKernelExamples',
	#superclass : 'Object',
	#instVars : [
		'out0',
		'out1'
	],
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

{ #category : 'examples' }
PVKernelExamples >> dotOfA: a b: b [
    <gpuVertex>
    <param: #vec3 named: #a>
    <param: #vec3 named: #b>
    <output: #f32 named: #dotResult location: 0>
    out0 := a dot: b
]

{ #category : 'kernels' }
PVKernelExamples >> mulFloat: a by: b [
	<gpu>
	<param: #f32 named: #a>
	<param: #f32 named: #b>
	^ a * b
]

{ #category : 'examples' }
PVKernelExamples >> normalizeV: v [
    <gpuVertex>
    <param: #vec3 named: #v>
    <output: #vec3 named: #result location: 0>
    out0 := v normalize
]

{ #category : 'kernels' }
PVKernelExamples >> relu: x [
	<gpu>
	<param: #f32 named: #x>
	^ x < 0.0 ifTrue: [ 0.0 ] ifFalse: [ x ]
]

{ #category : 'examples' }
PVKernelExamples >> triFragment: fragColor [
    <gpuFragment>
    <param: #vec3 named: #fragColor>
    <output: #vec4 named: #outColor location: 0>
    out0 := fragColor x , fragColor y , fragColor z , 1.0
]

{ #category : 'examples' }
PVKernelExamples >> triVertex: position color: color [
    <gpuVertex>
    <param: #vec2 named: #position>
    <param: #vec3 named: #color>
    <output: #vec4 named: #glPosition builtin: #position>
    <output: #vec3 named: #fragColor location: 0>
    out0 := position x , position y , 0.0 , 1.0.
    out1 := color
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
