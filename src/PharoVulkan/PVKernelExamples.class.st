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
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan',
	#tag : 'Compute'
}

{ #category : 'accessing' }
PVKernelExamples class >> defaultMatmulFamily [
	"The plain row-times-column product, which every other family is read against."

	^ #naive
]

{ #category : 'accessing' }
PVKernelExamples class >> matmulFamilies [
	"The matmul kernels by family. A caller measuring one family against another names both
	 the family and the precision, so neither is picked out of a list kept by hand."

	^ Dictionary newFrom: {
			  (self defaultMatmulFamily -> self matmulKernels).
			  (self tiledMatmulFamily -> self tiledMatmulKernels) }
]

{ #category : 'accessing' }
PVKernelExamples class >> matmulFor: anElementTypeSymbol [
	^ self matmulFor: anElementTypeSymbol family: self defaultMatmulFamily
]

{ #category : 'accessing' }
PVKernelExamples class >> matmulFor: anElementTypeSymbol family: aFamilySymbol [
	"The matmul of one precision in one family. Both an unknown family and a precision the
	 family has no kernel for raise, because either way there is nothing to dispatch and a
	 fallback would report the wrong kernel's number."

	| kernels |
	kernels := self matmulFamilies
		           at: aFamilySymbol
		           ifAbsent: [
		           PVTypeError signal: 'No matmul family named ' , aFamilySymbol ].
	^ self >> (kernels
		   at: anElementTypeSymbol
		   ifAbsent: [
			   PVTypeError signal: 'No ' , aFamilySymbol , ' matmul kernel for '
				   , anElementTypeSymbol ])
]

{ #category : 'kernels' }
PVKernelExamples class >> matmulKernels [
	"The matmul written for each element width. One source, so a caller working in either
	 precision names the precision and the two kernels cannot drift apart in their callers."

	^ Dictionary newFrom: {
			  (#f32 -> #matmulF32:a:b:out:).
			  (#f16 -> #matmulF16:a:b:out:) }
]

{ #category : 'accessing' }
PVKernelExamples class >> tiledMatmulFamily [
	"The family holding a 16 by 16 block of each input in shared memory."

	^ #tiled
]

{ #category : 'accessing' }
PVKernelExamples class >> tiledMatmulFor: anElementTypeSymbol [
	^ self matmulFor: anElementTypeSymbol family: self tiledMatmulFamily
]

{ #category : 'accessing' }
PVKernelExamples class >> tiledMatmulKernels [
	"The tiled matmul written for each element width, keyed the way matmulKernels is, so a
	 caller naming a precision gets the tiled kernel of that precision or nothing at all."

	^ Dictionary newFrom: {
			  (#f32 -> #tiledMatmulF32:a:b:out:tileA:tileB:).
			  (#f16 -> #tiledMatmulF16:a:b:out:tileA:tileB:) }
]

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
PVKernelExamples >> broadcastFirstOf: wi data: data out: output tile: tile [
	"Shared memory and a barrier in Pharo source. Each invocation fills its own slot of the
	 workgroup's tile, then every invocation reads slot zero, which only the first invocation
	 of the workgroup wrote. The barrier is what makes that read defined."

	<gpu>
	<localSize: #( 8 1 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #data>
	<param: #bufferOf_f32 named: #output>
	<shared: #f32 named: #tile count: 8>
	tile at: wi localX put: (data at: wi x).
	wi barrier.
	output at: wi x put: (tile at: 0)
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

{ #category : 'kernels' }
PVKernelExamples >> coopMatrixProductOf: a by: b into: output [
	"The 8 by 8 cooperative matrix product PVCooperativeMatrixKernel builds by hand,
	 written through the DSL instead. Each parameter type names the operand role its
	 buffer feeds, because one cooperative matrix type is fixed to one role in SPIR-V and
	 a load has to know which one it is building. The kernel takes no work item: every
	 invocation of the subgroup reaches the same three instructions, and the matrix
	 position inside the subgroup is the device's business, not the kernel's.
	 coopMatMulAdd: adds to a zero matrix, so the product is exactly a times b. The
	 hand-built kernel reads its accumulator from the output binding instead, which lets
	 the host decide what the product is added to; the DSL has no selector for that yet."

	<gpu>
	<localSize: #( 8 1 1 )>
	<param: #matrixABufferOf_f16 named: #a>
	<param: #matrixBBufferOf_f16 named: #b>
	<param: #accumulatorBufferOf_f32 named: #output>
	output coopMatStore: ((a coopMatLoad: 0) coopMatMulAdd: (b coopMatLoad: 0))
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
PVKernelExamples >> localIndexOf: wi data: data out: output [
	"Reads the element its position inside the workgroup points at, and writes it to the slot
	 its position in the dispatch points at. Every workgroup therefore reads the same first
	 eight elements, which is what tells a local index apart from a global one."

	<gpu>
	<localSize: #( 8 1 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #data>
	<param: #bufferOf_f32 named: #output>
	output at: wi x put: (data at: wi localX)
]

{ #category : 'kernels' }
PVKernelExamples >> mat4Mul: m vec: v [
<gpu>
<param: #mat4 named: #m>
<param: #vec4 named: #v>
^ m * v
]

{ #category : 'kernels' }
PVKernelExamples >> matmulF16: wi a: a b: b out: output [
	"The half precision twin of matmulF32:a:b:out:: the same naive row-times-column
	 product, with the matrices held as halves and the dot product accumulated in float.
	 Accumulating in half would cost far more accuracy than the storage format itself does,
	 because the error of an N-term sum grows with N."

	<gpu>
	<localSize: #( 16 16 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f16 named: #a>
	<param: #bufferOf_f16 named: #b>
	<param: #bufferOf_f16 named: #output>
	| row col n k acc |
	row := wi x.
	col := wi y.
	n := wi gridWidth.
	acc := 0.0.
	k := 0.
	[ k < n ] whileTrue: [
		acc := acc + ((a at: row * n + k) asF32 * (b at: k * n + col) asF32).
		k := k + 1 ].
	output at: row * n + col put: acc asF16
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

{ #category : 'kernels' }
PVKernelExamples >> nestedAccumulateOf: wi data: data out: output [
	"A loop inside a loop, the one nesting shape the recogniser matches. The addition after
	 the inner loop lands in the block the inner loop merges into, which is also where the
	 outer loop steps."

	<gpu>
	<localSize: #( 4 1 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #data>
	<param: #bufferOf_f32 named: #output>
	| i j acc |
	i := 0.
	acc := 0.0.
	[ i < 4 ] whileTrue: [
		j := 0.
		[ j < 2 ] whileTrue: [
			acc := acc + (data at: j).
			j := j + 1 ].
		acc := acc + (data at: i).
		i := i + 1 ].
	output at: wi x put: acc
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
PVKernelExamples >> subgroupDotOf: wi a: a b: b out: output lanes: lanes [
	"A dot product reduced in hardware: each invocation multiplies its own pair, then the
	 subgroup adds the products. Reduce delivers the total to every lane, so each lane writes
	 its subgroup's total to its own slot.
	 The second reduction adds 1.0 per lane, which answers how many lanes the subgroup really
	 had. The host cannot assume that: VkPhysicalDeviceSubgroupProperties reports the widest
	 subgroup the device offers, while the driver compiles a shader to whichever width it
	 likes, and this one chose half of what the device reports. With the width measured, the
	 host recovers the dot product by dividing the sum of every slot by it.
	 subgroupSum is a group operation, so every lane of the subgroup must reach it: that is
	 why this body carries no control flow."

	<gpu>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #a>
	<param: #bufferOf_f32 named: #b>
	<param: #bufferOf_f32 named: #output>
	<param: #bufferOf_f32 named: #lanes>
	| i |
	i := wi x.
	output at: i put: ((a at: i) * (b at: i)) subgroupSum.
	lanes at: i put: 1.0 subgroupSum
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

{ #category : 'examples - compute' }
PVKernelExamples >> tiledMatmulF16: wi a: a b: b out: output tileA: tileA tileB: tileB [
	"The half precision twin of tiledMatmulF32:a:b:out:tileA:tileB:. The tiles hold halves, so
	 a tile pair costs half the shared memory of the float kernel's and each tile load moves
	 half the bytes; the dot product still accumulates in float, because the error of a sum
	 accumulated in half grows with the number of terms rather than with the storage format.
	 This is the kernel half precision has to be measured on: the naive matmul is bound by
	 global memory traffic, so narrowing the loads there buys almost nothing.

	 The tile width appears as the literal 16 and the tile size as the literal 256, which is
	 16 by 16: a kernel body carries no message sends beyond those the DSL maps, so it cannot
	 ask a class-side constant for them. The matrix order comes from the dispatch
	 (wi gridWidth), so the grid must cover the matrix exactly: N / 16 groups along each of
	 x and y. Row-major storage throughout."

	<gpu>
	<localSize: #( 16 16 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f16 named: #a>
	<param: #bufferOf_f16 named: #b>
	<param: #bufferOf_f16 named: #output>
	<shared: #f16 named: #tileA count: 256>
	<shared: #f16 named: #tileB count: 256>
	| row col n lx ly acc tileBase k |
	row := wi x.
	col := wi y.
	n := wi gridWidth.
	lx := wi localX.
	ly := wi localY.
	acc := 0.0.
	tileBase := 0.
	[ tileBase < n ] whileTrue: [
		tileA at: lx * 16 + ly put: (a at: row * n + (tileBase + ly)).
		tileB at: lx * 16 + ly put: (b at: (tileBase + lx) * n + col).
		wi barrier.
		k := 0.
		[ k < 16 ] whileTrue: [
			acc := acc
			       + ((tileA at: lx * 16 + k) asF32 * (tileB at: k * 16 + ly) asF32).
			k := k + 1 ].
		wi barrier.
		tileBase := tileBase + 16 ].
	output at: row * n + col put: acc asF16
]

{ #category : 'kernels' }
PVKernelExamples >> tiledMatmulF32: wi a: a b: b out: output tileA: tileA tileB: tileB [
	"Tiled row-times-column matmul in Pharo source: the kernel PVTiledMatmulKernel builds
	 by hand, written through the DSL instead. Each workgroup walks the matrices one 16 by
	 16 tile at a time, copies its own element of each tile into shared memory, waits, and
	 reads the tile 16 times from there rather than 16 times from global memory. The two
	 barriers are both needed: the first before the tile is read, the second before the next
	 iteration overwrites it.

	 The tile width appears as the literal 16 and the tile size as the literal 256, which is
	 16 by 16: a kernel body carries no message sends beyond those the DSL maps, so it
	 cannot ask a class-side constant for them. The matrix order comes from the dispatch
	 (wi gridWidth), so the grid must cover the matrix exactly: N / 16 groups along each of
	 x and y. Row-major storage throughout."

	<gpu>
	<localSize: #( 16 16 1 )>
	<param: #workItem named: #wi>
	<param: #bufferOf_f32 named: #a>
	<param: #bufferOf_f32 named: #b>
	<param: #bufferOf_f32 named: #output>
	<shared: #f32 named: #tileA count: 256>
	<shared: #f32 named: #tileB count: 256>
	| row col n lx ly acc tileBase k |
	row := wi x.
	col := wi y.
	n := wi gridWidth.
	lx := wi localX.
	ly := wi localY.
	acc := 0.0.
	tileBase := 0.
	[ tileBase < n ] whileTrue: [
		tileA at: lx * 16 + ly put: (a at: row * n + (tileBase + ly)).
		tileB at: lx * 16 + ly put: (b at: (tileBase + lx) * n + col).
		wi barrier.
		k := 0.
		[ k < 16 ] whileTrue: [
			acc := acc + ((tileA at: lx * 16 + k) * (tileB at: k * 16 + ly)).
			k := k + 1 ].
		wi barrier.
		tileBase := tileBase + 16 ].
	output at: row * n + col put: acc
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
