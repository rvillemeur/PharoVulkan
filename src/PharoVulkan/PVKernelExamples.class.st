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

{ #category : 'shaders' }
PVKernelExamples >> alphaClip: color threshold: t [
	<gpuFragment>
	<param: #vec3 named: #color>
	<param: #f32 named: #threshold>
	<output: #vec4 named: #outColor location: 0>
	(t < color length)
		ifTrue: [out0 := color x , color y , color z , 1.0]
		ifFalse: [out0 := 0.0 , 0.0 , 0.0 , 0.0]
]

{ #category : 'kernels' }
PVKernelExamples >> clampF32: x lo: lo hi: hi [
<gpu>
<param: #f32 named: #x>
<param: #f32 named: #lo>
<param: #f32 named: #hi>
^ x clamp: lo to: hi
]

{ #category : 'kernels' }
PVKernelExamples >> clampNegatives: wi data: data out: output [
	"A compute kernel whose body is one ifTrue:ifFalse:. Negative inputs become zero."

	<gpu>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #data>
	<param: #bufferOf_f32 named: #output>
	| v r |
	v := data at: wi x.
	r := v < 0.0
		     ifTrue: [ 0.0 ]
		     ifFalse: [ v ].
	output at: wi x put: r
]

{ #category : 'examples' }
PVKernelExamples >> dotOfA: a b: b [
    <gpuVertex>
    <param: #vec3 named: #a>
    <param: #vec3 named: #b>
    <output: #f32 named: #dotResult location: 0>
    out0 := a dot: b
]

{ #category : 'shaders' }
PVKernelExamples >> glslTriFragment: fragColor [
<gpuFragment>
<param: #vec3 named: #fragColor>
<output: #vec4 named: #outColor location: 0>
| white blended |
white := 1.0 , 1.0 , 1.0.
blended := fragColor mix: white factor: 0.5.
out0 := blended x , blended y , blended z , 1.0
]

{ #category : 'shaders' }
PVKernelExamples >> glslTriVertex: position color: color [
<gpuVertex>
<param: #vec2 named: #position>
<param: #vec3 named: #color>
<output: #vec4 named: #glPosition builtin: #position>
<output: #vec3 named: #fragColor location: 0>
out0 := position x , position y , 0.0 , 1.0.
out1 := color normalize
]

{ #category : 'kernels' }
PVKernelExamples >> mat4Mul: m vec: v [
<gpu>
<param: #mat4 named: #m>
<param: #vec4 named: #v>
^ m * v
]

{ #category : 'kernels' }
PVKernelExamples >> matmulF32: wi a: a b: b out: output [
	"Naive row-times-column matmul, one invocation per output element: the Phase 7
	 baseline, with no tiling and no shared memory. The matrix order comes from the
	 dispatch (wi gridWidth), so the grid must cover the matrix exactly: N / localSizeX
	 groups along x and the same along y. Row-major storage throughout."

	<gpu>
	<localSize: #( 16 16 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #a>
	<param: #bufferOf_f32 named: #b>
	<param: #bufferOf_f32 named: #output>
	| row col n k acc |
	row := wi x.
	col := wi y.
	n := wi gridWidth.
	acc := 0.0.
	k := 0.
	[ k < n ] whileTrue: [
		acc := acc + ((a at: row * n + k) * (b at: k * n + col)).
		k := k + 1 ].
	output at: row * n + col put: acc
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

{ #category : 'kernels' }
PVKernelExamples >> sqrtF32: x [
<gpu>
<param: #f32 named: #x>
^ x sqrt
]

{ #category : 'kernels' }
PVKernelExamples >> sumFirst16: wi data: data out: output [
	"A compute kernel whose body is one whileTrue:. Every invocation sums the first
	 16 elements of data and writes the total to its own slot."

	<gpu>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #data>
	<param: #bufferOf_f32 named: #output>
	| i acc |
	i := 0.
	acc := 0.0.
	[ i < 16 ] whileTrue: [
		acc := acc + (data at: i).
		i := i + 1 ].
	output at: wi x put: acc
]

{ #category : 'kernels' }
PVKernelExamples >> sumFirstGridWidth: wi data: data out: output [
	"Sums as many elements as the dispatch grid is wide. The grid width is the only way a
	 kernel can learn a problem size under the WorkItem-plus-buffers ABI, so this kernel
	 is what proves wi gridWidth answers groupCountX times localSizeX."

	<gpu>
	<localSize: #( 8 1 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #data>
	<param: #bufferOf_f32 named: #output>
	| k acc n |
	n := wi gridWidth.
	acc := 0.0.
	k := 0.
	[ k < n ] whileTrue: [
		acc := acc + (data at: k).
		k := k + 1 ].
	output at: wi x put: acc
]

{ #category : 'kernels' }
PVKernelExamples >> taggedLocalSizeAdd: wi data: data out: output [
	"Carries a non-default <localSize:> so a test can tell a pragma-driven local size from
	 the default one. The numbers are deliberately unlike #( 64 1 1 )."

	<gpu>
	<localSize: #( 8 4 2 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #data>
	<param: #bufferOf_f32 named: #output>
	output at: wi x put: (data at: wi x) * 2.0
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
PVKernelExamples >> vec3Add: a b: b [
<gpu>
<param: #vec3 named: #a>
<param: #vec3 named: #b>
^ a + b
]

{ #category : 'kernels' }
PVKernelExamples >> vec3Length: v [
<gpu>
<param: #vec3 named: #v>
^ v length
]

{ #category : 'kernels' }
PVKernelExamples >> vec4W: v [
<gpu>
<param: #vec4 named: #v>
^ v w
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

{ #category : 'kernels' }
PVKernelExamples >> vectorAddF16: wi a: a b: b out: output [
	"The half precision twin of vectorAdd:a:b:out:, the same arithmetic over two-byte
	 elements. No pragma states the half precision capabilities: the emitter derives them
	 from the buffer element type, so a kernel cannot declare one and use the other."

	<gpu>
	<param: #workItem named: #wi>
	<param: #bufferOf_f16 named: #a>
	<param: #bufferOf_f16 named: #b>
	<param: #bufferOf_f16 named: #output>
	| idx |
	idx := wi x.
	output at: idx put: (a at: idx) + (b at: idx)
]
