# PharoVulkan GLSL-like Shader API Tutorial

The GLSL-like API lets you write vertex and fragment shaders as ordinary Pharo
methods annotated with pragmas. `PVKernelCompiler` compiles them to SPIR-V
binary automatically. You do not touch `SpvModule`, `SpvInstruction`, or any
of the low-level builder classes — those are handled internally.

---

## How it works

```
Pharo method
    ↓  PVBytecodeDecoder     — reads bytecodes → PVBytecodeOp list
    ↓  PVStackSimulator      — stack → register ops
    ↓  PVTypeInferencer      — infers SPIR-V type per register
    ↓  PVSPIRVEmitter        — emits SPIR-V binary
    → ByteArray (SPIR-V)
```

The method is never executed in Pharo. Its bytecodes are decoded and compiled
to SPIR-V directly. Type information comes entirely from the pragma
annotations — no type inference across call boundaries is needed because the
DSL is monomorphic.

---

## Annotating a shader method

Every GPU method needs at least one pragma selecting the shader kind, plus one
`<param:named:>` pragma per input and one `<output:named:...>` pragma per
output variable.

### Shader kind pragmas

| Pragma | SPIR-V execution model |
|---|---|
| `<gpu>` | GLCompute (compute kernel) |
| `<gpuVertex>` | Vertex |
| `<gpuFragment>` | Fragment |

### Input parameter pragma

```smalltalk
<param: #typeName named: #argName>
```

One pragma per method argument, in argument order. The `#typeName` is a symbol
from the supported type set (see below).

### Output variable pragmas

```smalltalk
<output: #typeName named: #varName location: N>
<output: #typeName named: #varName builtin: #builtinName>
```

Output variables correspond to instance variables `out0`, `out1`, etc. (in
declaration order). `out0` maps to the first `<output:...>` pragma, `out1` to
the second, and so on. The class must declare `out0` and `out1` as instance
variables.

---

## Supported types

| Symbol | GLSL equivalent | Description |
|---|---|---|
| `#f32` | `float` | 32-bit float |
| `#i32` | `int` | 32-bit signed integer |
| `#u32` | `uint` | 32-bit unsigned integer |
| `#bool` | `bool` | Boolean |
| `#vec2` | `vec2` | 2-component float vector |
| `#vec3` | `vec3` | 3-component float vector |
| `#vec4` | `vec4` | 4-component float vector |
| `#mat4` | `mat4` | 4×4 float matrix |
| `#workItem` | — | Compute work-item (x/y/z global IDs) |
| `#bufferOf_f32` | `buffer float[]` | Storage buffer of float |
| `#bufferOf_i32` | `buffer int[]` | Storage buffer of int |

---

## Supported operations

### Arithmetic (f32, i32, u32)

| Pharo message | SPIR-V op |
|---|---|
| `a + b` | `OpFAdd` / `OpIAdd` |
| `a - b` | `OpFSub` / `OpISub` |
| `a * b` | `OpFMul` / `OpIMul` |
| `a / b` | `OpFDiv` |
| `a // b` | `OpSDiv` (i32 only) |
| `a \\ b` | `OpSMod` (i32 only) |
| `a < b` | `OpFOrdLessThan` / `OpSLessThan` |
| `a <= b` | `OpFOrdLessThanEqual` / `OpSLessThanEqual` |

### Vector arithmetic (vec2, vec3, vec4)

| Pharo message | SPIR-V op |
|---|---|
| `a + b` | `OpFAdd` (component-wise) |
| `a - b` | `OpFSub` (component-wise) |
| `a * b` | `OpFMul` (component-wise) |

### Component extraction

| Pharo message | Result |
|---|---|
| `v x` | `OpCompositeExtract` index 0 → f32 |
| `v y` | `OpCompositeExtract` index 1 → f32 |
| `v z` | `OpCompositeExtract` index 2 → f32 (vec3, vec4) |
| `v w` | `OpCompositeExtract` index 3 → f32 (vec4 only) |

### Composite construction (`,` chaining)

The `,` message builds larger vectors from smaller components:

```smalltalk
x , y           "f32 , f32  → vec2"
x , y , z       "vec2 , f32 → vec3"
x , y , z , w   "vec3 , f32 → vec4"
```

### Matrix operation

| Pharo message | SPIR-V op |
|---|---|
| `m * v` (mat4 × vec4) | `OpMatrixTimesVector` → vec4 |

### GLSL.std.450 extended instructions

| Pharo message | GLSL function | Result type |
|---|---|---|
| `v normalize` | `normalize` | same vec type |
| `v length` | `length` | f32 |
| `a dot: b` (vec3) | `dot` | f32 |
| `x sqrt` | `sqrt` | f32 |
| `x clamp: lo to: hi` | `clamp` | f32 |
| `a mix: b factor: t` | `mix` | vec3 |

---

## Example 1 — passthrough vertex shader

```smalltalk
PVKernelExamples >> triVertex: position color: color [
    <gpuVertex>
    <param: #vec2 named: #position>
    <param: #vec3 named: #color>
    <output: #vec4 named: #glPosition builtin: #position>
    <output: #vec3 named: #fragColor location: 0>
    out0 := position x , position y , 0.0 , 1.0.
    out1 := color
]
```

What the compiler does:

1. Detects `<gpuVertex>` → vertex shader path
2. Creates two Input `OpVariable`s:
   - `inPosition` (vec2, Location 0)
   - `inColor` (vec3, Location 1)
3. Creates two Output `OpVariable`s:
   - `outGlPosition` in the `gl_PerVertex` block with `BuiltIn Position`
   - `outFragColor` (vec3, Location 0)
4. Emits `void main()` that:
   - Loads `inPosition` → expands to vec4 via `compositeConstruct(x, y, 0, 1)` → stores to `gl_Position`
   - Loads `inColor` → stores to `outFragColor` unchanged

Compile it:

```smalltalk
vertSpirv := PVKernelCompiler compile: (PVKernelExamples >> #triVertex:color:).
```

Verify it starts with the SPIR-V magic number:

```smalltalk
(vertSpirv copyFrom: 1 to: 4) = #[3 2 35 7]    "=> true"
```

---

## Example 2 — passthrough fragment shader

```smalltalk
PVKernelExamples >> triFragment: fragColor [
    <gpuFragment>
    <param: #vec3 named: #fragColor>
    <output: #vec4 named: #outColor location: 0>
    out0 := fragColor x , fragColor y , fragColor z , 1.0
]
```

Receives `vec3 fragColor` from the vertex shader (Location 0), appends
`alpha = 1.0`, and writes the resulting `vec4` to the framebuffer.

```smalltalk
fragSpirv := PVKernelCompiler compile: (PVKernelExamples >> #triFragment:).
```

---

## Example 3 — GLSL triangle with normalize and mix

A more interesting pair using GLSL extended instructions:

```smalltalk
PVKernelExamples >> glslTriVertex: position color: color [
    <gpuVertex>
    <param: #vec2 named: #position>
    <param: #vec3 named: #color>
    <output: #vec4 named: #glPosition builtin: #position>
    <output: #vec3 named: #fragColor location: 0>
    out0 := position x , position y , 0.0 , 1.0.
    out1 := color normalize
]
```

`color normalize` compiles to `OpExtInst GLSL.std.450 Normalize`.
Vertex colors are unit-length vectors — saturated, uniform-brightness hues.

```smalltalk
PVKernelExamples >> glslTriFragment: fragColor [
    <gpuFragment>
    <param: #vec3 named: #fragColor>
    <output: #vec4 named: #outColor location: 0>
    | white blended |
    white := 1.0 , 1.0 , 1.0.
    blended := fragColor mix: white factor: 0.5.
    out0 := blended x , blended y , blended z , 1.0
]
```

`fragColor mix: white factor: 0.5` compiles to `OpExtInst GLSL.std.450 FMix`.
Each fragment interpolates 50% toward white, producing pastel colors.

The use of local variables (`white`, `blended`) is fully supported. The
compiler assigns each a virtual register and tracks its type through the
expression chain.

---

## Rendering the GLSL triangle

`PVGlslTriangleScene` subclasses `PVHelloTriangleScene` and overrides only the
two shader-building methods. Everything else (surface, swapchain, pipeline,
vertex buffer, render loop) is inherited unchanged.

```smalltalk
PVGlslTriangleScene renderTriangle
```

This opens an 800×600 window and renders 300 frames. The shaders are compiled
from Pharo source on each fresh scene initialization — no pre-baked SPIR-V.

To run just the compilation and inspect the output without opening a window:

```smalltalk
| vBytes fBytes |
vBytes := PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:).
fBytes := PVKernelCompiler compile: (PVKernelExamples >> #glslTriFragment:).
vBytes size.    "=> word count × 4"
fBytes size.
```

---

## Writing your own shader pair

### 1. Add instance variables

The class that holds your shader methods needs `out0` and `out1` declared:

```smalltalk
Object subclass: #MyShaders
    instanceVariableNames: 'out0 out1'
    ...
```

`PVKernelExamples` already has these. You can add methods directly to it or
to your own subclass.

### 2. Write the vertex shader

```smalltalk
MyShaders >> myVertex: position [
    <gpuVertex>
    <param: #vec2 named: #position>
    <output: #vec4 named: #glPosition builtin: #position>
    out0 := position x , position y , 0.0 , 1.0
]
```

No color output here — the fragment shader will use a constant color.

### 3. Write the fragment shader

```smalltalk
MyShaders >> myFragment [
    <gpuFragment>
    <output: #vec4 named: #outColor location: 0>
    out0 := 1.0 , 0.0 , 0.5 , 1.0    "solid pink"
]
```

A fragment shader with no input parameters — the constant color is built
entirely from literal floats via `,` chaining.

### 4. Compile

```smalltalk
vertSpirv := PVKernelCompiler compile: (MyShaders >> #myVertex:).
fragSpirv := PVKernelCompiler compile: (MyShaders >> #myFragment).
```

### 5. Feed into the graphics pipeline

Subclass `PVHelloTriangleScene` and override the two builder methods:

```smalltalk
PVHelloTriangleScene subclass: #MyTriangleScene
    instanceVariableNames: ''
    ...

MyTriangleScene >> buildVertexShader [
    ^ PVKernelCompiler compile: (MyShaders >> #myVertex:)
]

MyTriangleScene >> buildFragmentShader [
    ^ PVKernelCompiler compile: (MyShaders >> #myFragment)
]

MyTriangleScene class >> renderTriangle [
    | attrs win backendWin ctx scene |
    PVVulkanDriver install.
    attrs := PVWindowAttributes newVulkan.
    attrs title: 'My Shader'; extent: 800@600; windowCentered: true.
    win := OSWindow createWithAttributes: attrs.
    backendWin := win backendWindow.
    ctx := VkContext graphicsContextForExtensions: backendWin requiredInstanceExtensions.
    scene := self prepare: ctx backendWindow: backendWin.
    1 to: 300 do: [:i | scene renderFrame].
    ctx computeQueue waitIdle.
    scene destroy.
    ctx destroy.
    win destroy.
    PVVulkanDriver uninstall.
    ^ scene
]
```

Then run:

```smalltalk
MyTriangleScene renderTriangle
```

---

## Constraints and limitations

- **Monomorphic only.** Each message send must have a statically known receiver
  type derivable from the pragma annotations. Polymorphic dispatch is not
  supported.
- **No loops in shaders.** Vertex and fragment shaders must be straight-line
  code (single basic block). Loops and conditionals are supported only in
  compute kernels (`<gpu>`).
- **No recursion.** No function calls to other Pharo methods — only the
  operations listed in the supported-operations table are translated.
- **No closures (except compute loops).** The `,` and GLSL ops are message
  sends, not closures. `1 to: n do: [...]` is the one closure form recognised,
  in compute kernels only.
- **Output variables via `out0`/`out1` only.** The class must declare these as
  instance variables. The compiler maps `popIntoReceiverVariable:` bytecodes to
  `OpStore` into the corresponding output `OpVariable`.
- **Vertex layout is fixed by `VkGraphicsPipeline`.** The current pipeline
  expects binding 0 at stride 20 (vec2 position + vec3 color). If your vertex
  shader has different inputs you must also subclass `VkGraphicsPipeline` and
  override the vertex input state.

---

## Debugging tips

**Check SPIR-V magic number first:**

```smalltalk
bytes := PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:).
(bytes copyFrom: 1 to: 4) = #[3 2 35 7]    "must be true"
```

**Inspect the register ops after stack simulation:**

```smalltalk
| m bytecodeOps regOps |
m := PVKernelExamples >> #glslTriFragment:.
bytecodeOps := PVBytecodeDecoder decode: m.
regOps := PVStackSimulator simulate: bytecodeOps paramCount: 1.
regOps do: [:op | Transcript showCr: op printString].
```

**Inspect the type map:**

```smalltalk
| m ann bytecodeOps regOps st typeInf typeMap |
m := PVKernelExamples >> #glslTriFragment:.
ann := PVTypeAnnotation fromMethod: m.
bytecodeOps := PVBytecodeDecoder decode: m.
regOps := PVStackSimulator simulate: bytecodeOps paramCount: ann params size.
st := PVSelectorTable standard.
typeInf := PVTypeInferencer new initialize annotation: ann.
typeMap := typeInf inferAll: regOps selectorTable: st.
typeMap associations do: [:a | Transcript showCr: a key printString , ' → ' , a value].
```

**Common errors:**

| Error | Cause | Fix |
|---|---|---|
| `PVTypeError: No SPIR-V mapping for X on Y` | Selector `X` not in `PVSelectorTable` for type `Y` | Add mapping to `initializeVecMappings` or `initializeGLSLMappings` |
| `PVTypeError: Cannot infer type for recv of X` | Receiver register has no type entry | Check that all input params have `<param:named:>` pragmas and that temp variables are assigned before use |
| `PVTypeError: Method is not annotated` | Missing `<gpu>`, `<gpuVertex>`, or `<gpuFragment>` pragma | Add the pragma |
| First 4 bytes are not `#[3 2 35 7]` | SPIR-V serialisation error | Inspect the `SpvModule` intermediate — likely a missing type or dangling ID |
