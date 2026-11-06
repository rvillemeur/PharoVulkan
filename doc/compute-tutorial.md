# PharoVulkan Compute API Tutorial

This tutorial covers both the high-level `PVComputeKernel` runner and the
manual step-by-step pipeline assembly underneath it. It also documents
the Pharo→SPIR-V compiler: how to annotate a method, what operations are
supported, and how the 9-stage compilation pipeline works.

---

## Overview — two ways to use the compute API

**High-level**: `PVComputeKernel` handles shader module, descriptor set,
pipeline, and command pool for you. Best for getting results fast.

**Low-level**: assemble each Vulkan object manually. Needed when you want
multiple descriptor sets, push constants, or custom pipeline cache behaviour.

Both paths share the same context creation and buffer allocation steps.

---

## Step 1 — Create a VkContext for compute

```smalltalk
| ctx |
ctx := VkContext computeContext.
```

`VkContext class >> computeContext` calls `initializeCompute` which:

1. Allocates a `VkApplicationInfo` with `apiVersion = VkApiVersion vulkan13`
   (= 4206592 = `VK_MAKE_API_VERSION(0,1,3,0)`)
2. Creates a `VkInstance` (no instance extensions needed for headless compute)
3. Calls `selectPhysicalDevice` — iterates all GPUs, picks the first with
   `VK_QUEUE_COMPUTE_BIT` set in any queue family
4. Calls `createLogicalDevice` — creates a `VkDevice` with
   `VkPhysicalDeviceSynchronization2Features` enabled
5. Calls `fetchComputeQueue` — retrieves the `VkQueue`

After this:
- `ctx device` — the `VkDevice` wrapper
- `ctx computeQueue` — the `VkQueue`
- `ctx computeQueueFamily` — the queue family index (integer)
- `ctx physicalDevice` — the selected `VkPhysicalDevice`

---

## Step 2 — Allocate device buffers

Every buffer is device-local + host-visible + host-coherent so the CPU can
read and write it without explicit cache flushes.

```smalltalk
| inputBuf outputBuf |
inputBuf  := VkBuffer on: ctx device size: 1024 usage: VkImageUsage storageBit.
outputBuf := VkBuffer on: ctx device size: 1024 usage: VkImageUsage storageBit.
```

`VkBuffer>>allocate` (called by the factory) does:
1. `vkCreateBuffer` with the given `size` and `usage`
2. `vkGetBufferMemoryRequirements`
3. `physicalDevice findMemoryType: typeBits properties: VkMemoryProperty hostVisibleAndCoherent`
   (= bit mask 6, combining `HOST_VISIBLE=2` and `HOST_COHERENT=4`)
4. `vkAllocateMemory`
5. `vkBindBufferMemory`

### Writing data into a buffer

```smalltalk
| data |
data := ByteArray new: 1024.
"fill data with your input (little-endian floats or ints)"
inputBuf copyFromByteArray: data.
```

`copyFromByteArray:` maps memory (`vkMapMemory`), copies byte-by-byte,
then unmaps (`vkUnmapMemory`).

### Writing floats (IEEE 754 little-endian)

```smalltalk
putFloat32: aFloat into: bytes at: byteOffset [
    | bits |
    bits := aFloat asIEEE32BitWord.
    bytes at: byteOffset   put: (bits        bitAnd: 16rFF).
    bytes at: byteOffset+1 put: ((bits >>  8) bitAnd: 16rFF).
    bytes at: byteOffset+2 put: ((bits >> 16) bitAnd: 16rFF).
    bytes at: byteOffset+3 put: ((bits >> 24) bitAnd: 16rFF) ]

putInt32: anInt into: bytes at: byteOffset [
    bytes at: byteOffset   put: (anInt        bitAnd: 16rFF).
    bytes at: byteOffset+1 put: ((anInt >>  8) bitAnd: 16rFF).
    bytes at: byteOffset+2 put: ((anInt >> 16) bitAnd: 16rFF).
    bytes at: byteOffset+3 put: ((anInt >> 24) bitAnd: 16rFF) ]
```

---

## Step 3 — Write and compile a GPU kernel

### 3a — Annotating the Pharo method

A kernel method must carry `<gpu>` and one `<param: type named: name>` pragma
per parameter.

```smalltalk
MyKernels >> addVectors: a and: b [
    <gpu>
    <param: #f32 named: #a>
    <param: #f32 named: #b>
    ^ a + b
]
```

Rules:
- `<gpu>` must be the first pragma
- Each `<param:named:>` maps a method parameter to a SPIR-V scalar type
- Parameter order matches the pragma order, not the Smalltalk keyword order
- The method body may only use operations from the supported set (see §3c)
- Returned value becomes the shader function's return value

### 3b — Supported SPIR-V types

| Symbol | SPIR-V type | Width |
|---|---|---|
| `#f32` | `OpTypeFloat` 32 | 32-bit float |
| `#i32` | `OpTypeInt` 32 signed | 32-bit signed integer |
| `#u32` | `OpTypeInt` 32 unsigned | 32-bit unsigned integer |
| `#bool` | `OpTypeBool` | boolean (result of comparisons only) |

### 3c — Supported Pharo operations

The `PVSelectorTable` maps Pharo message sends to SPIR-V opcodes:

| Pharo selector | Receiver type | SPIR-V opcode | Result type |
|---|---|---|---|
| `+` | `#f32` | `OpFAdd` | `#f32` |
| `-` | `#f32` | `OpFSub` | `#f32` |
| `*` | `#f32` | `OpFMul` | `#f32` |
| `/` | `#f32` | `OpFDiv` | `#f32` |
| `<` | `#f32` | `OpFOrdLessThan` | `#bool` |
| `<=` | `#f32` | `OpFOrdLessThanEqual` | `#bool` |
| `+` | `#i32` | `OpIAdd` | `#i32` |
| `-` | `#i32` | `OpISub` | `#i32` |
| `*` | `#i32` | `OpIMul` | `#i32` |
| `//` | `#i32` | `OpSDiv` | `#i32` |
| `\\` | `#i32` | `OpSMod` | `#i32` |
| `<` | `#i32` | `OpSLessThan` | `#bool` |
| `<=` | `#i32` | `OpSLessThanEqual` | `#bool` |
| `+` | `#u32` | `OpIAdd` | `#u32` |
| `*` | `#u32` | `OpIMul` | `#u32` |

Control flow:
- `ifTrue:ifFalse:` — compiled to `OpSelectionMerge` + `OpBranchConditional`
- `whileTrue:` — compiled to `OpLoopMerge` + `OpBranchConditional`

**Not supported** (Phase 1–6 scope):
- Array/buffer indexing, pointer arithmetic
- Global work ID access (`gl_GlobalInvocationID`)
- Virtual dispatch or polymorphic calls
- Recursive methods
- Floating-point literals as Pharo `Float` (use `0.0`, `1.0` etc. — the
  compiler recognises them as f32 constants)

### 3d — Examples from PVKernelExamples

```smalltalk
"Straight-line arithmetic"
addFloat: a to: b [
    <gpu>
    <param: #f32 named: #a>
    <param: #f32 named: #b>
    ^ a + b
]

"Conditional (ifTrue:ifFalse:)"
relu: x [
    <gpu>
    <param: #f32 named: #x>
    ^ x < 0.0 ifTrue: [ 0.0 ] ifFalse: [ x ]
]

"Loop (whileTrue:)"
accumulateUpTo: n [
    <gpu>
    <param: #i32 named: #n>
    | sum i |
    sum := 0.
    i := 1.
    [ i <= n ] whileTrue: [ sum := sum + i. i := i + 1 ].
    ^ sum
]
```

### 3e — Compile to SPIR-V bytes

```smalltalk
| spirvBytes |
spirvBytes := PVKernelCompiler compile: (MyKernels >> #addVectors:and:).
"=> ByteArray — 32-bit LE SPIR-V binary, passes spirv-val"
```

`PVKernelCompiler compile:` is a class-side factory that runs all 7 stages:

| Stage | Class | Input → Output |
|---|---|---|
| 1 | `PVBytecodeDecoder` | `CompiledMethod` → `Array of PVBytecodeOp` |
| 2 | `PVStackSimulator` | bytecode ops → `Array of PVRegisterOp` (stack machine → register IR) |
| 3 | `PVTypeInferencer` | register ops + pragma annotations → `typeMap: reg → SpvType` |
| 4 | `PVCFGBuilder buildBytecodeBlocks:` | bytecode ops → `Array of PVBytecodeBlock` (identifies straight-line / selection / loop) |
| 5 | `PVStructuredCFGRecognizer` | blocks → `PVSelectionNode` or `PVLoopNode` or nil, and a straight-line method skips it |
| 6 | `PVSPIRVEmitter` | register ops and `typeMap` → `SpvModule` |
| 7 | `SpvSerializer + SpvValidator` | `SpvModule` → `ByteArray` |

There is no SSA stage. A merge point needs `OpPhi`, and `PVSPIRVEmitter` writes those itself by
saving its register map before an arm and restoring it after.

If `<gpu>` is missing, stage 1 raises `PVTypeError signal: 'Method is not
annotated with <gpu>'`. If the control flow is unrecognised, stage 5 raises
`PVTypeError signal: 'Unrecognized CFG shape'`.

---

## Step 4 — High-level dispatch with PVComputeKernel

`PVComputeKernel` builds and runs the full pipeline in a few messages.

```smalltalk
| kernel result |
kernel := PVComputeKernel on: ctx spirv: spirvBytes.
kernel bindBuffer: inputBuf.
kernel bindBuffer: outputBuf.
kernel prepare.
kernel dispatch: 64 y: 1 z: 1.
result := outputBuf copyToByteArray.
kernel destroy.
```

### What `prepare` does

```
VkShaderModule fromBytes: spirvBytes device: ctx device
    │
VkDescriptorSetLayout on: ctx device
    │ addStorageBufferBinding: 0 stageFlags: VkShaderStage computeBit
    │ addStorageBufferBinding: 1 stageFlags: VkShaderStage computeBit
    │ ...  (one binding per bound buffer, 0-indexed)
    │ create
    │
VkPipelineLayout on: ctx device setLayouts: (Array with: descriptorSetLayout)
    │
VkComputePipeline on: shaderModule layout: pipelineLayout device: ctx device
    │
VkDescriptorPool on: ctx device maxSets: 1 descriptorCount: buffers size
    │ allocateSet: descriptorSetLayout
    │
descriptorSet updateStorageBuffer: buf atBinding: i   (for each buffer)
    │
VkCommandPool on: ctx device queueFamilyIndex: ctx computeQueueFamily
```

### What `dispatch:y:z:` does

```
commandPool allocateBuffer
    │
cb do: [:c |
    c bindComputePipeline: pipeline.
    c bindDescriptorSets: (Array with: descriptorSet)
      pipelineLayout: pipelineLayout.
    c dispatch: x y: y z: z]
    │
ctx computeQueue submit: cb andWait: true
```

`submit:andWait:` calls `vkQueueSubmit2` (sync2) then `vkQueueWaitIdle`.
Control returns to Pharo only after the GPU is done.

### What `destroy` does (reverse order)

```
commandPool destroy
descriptorPool destroy
pipeline destroy
pipelineLayout destroy
descriptorSetLayout destroy
shaderModule destroy
```

The buffers are **not** destroyed by `PVComputeKernel` — you allocated them,
you own them.

---

## Step 5 — Reading results back

```smalltalk
| bytes |
bytes := outputBuf copyToByteArray.
```

`copyToByteArray` maps the buffer memory, copies all bytes into a new
`ByteArray`, then unmaps.

### Decoding f32 values

```smalltalk
readFloat32From: bytes at: byteOffset [
    | bits |
    bits := (bytes at: byteOffset)
          | ((bytes at: byteOffset+1) << 8)
          | ((bytes at: byteOffset+2) << 16)
          | ((bytes at: byteOffset+3) << 24).
    ^ Float fromIEEE32Bit: bits
]
```

### Decoding i32 values

```smalltalk
readInt32From: bytes at: byteOffset [
    | v |
    v := (bytes at: byteOffset)
       | ((bytes at: byteOffset+1) << 8)
       | ((bytes at: byteOffset+2) << 16)
       | ((bytes at: byteOffset+3) << 24).
    (v bitAnd: 16r80000000) = 0 ifTrue: [ ^ v ].
    ^ v - 16r100000000    "sign-extend"
]
```

---

## Step 6 — Full teardown

```smalltalk
"After kernel.destroy and result read-back:"
outputBuf destroy.
inputBuf  destroy.
ctx       destroy.
```

`VkContext>>destroy` calls `vkDestroyDevice` then `vkDestroyInstance`.
Always destroy buffers before the device.

---

## Complete worked example

```smalltalk
| ctx inputBuf outputBuf spirv kernel resultBytes |

"1. Context"
ctx := VkContext computeContext.

"2. Buffers — 4 floats each"
inputBuf  := VkBuffer on: ctx device size: 16 usage: VkImageUsage storageBit.
outputBuf := VkBuffer on: ctx device size: 16 usage: VkImageUsage storageBit.

"3. Fill input with [1.0, 2.0, 3.0, 4.0]"
| inData |
inData := ByteArray new: 16.
#(1.0 2.0 3.0 4.0) doWithIndex: [:v :i |
    | bits base |
    bits := v asIEEE32BitWord.
    base := (i - 1) * 4 + 1.
    inData at: base   put: (bits        bitAnd: 16rFF).
    inData at: base+1 put: ((bits >>  8) bitAnd: 16rFF).
    inData at: base+2 put: ((bits >> 16) bitAnd: 16rFF).
    inData at: base+3 put: ((bits >> 24) bitAnd: 16rFF)].
inputBuf copyFromByteArray: inData.

"4. Compile relu kernel"
spirv := PVKernelCompiler compile: (PVKernelExamples >> #relu:).

"5. Run"
kernel := PVComputeKernel on: ctx spirv: spirv.
kernel bindBuffer: inputBuf.
kernel bindBuffer: outputBuf.
kernel prepare.
kernel dispatch: 1 y: 1 z: 1.

"6. Read back"
resultBytes := outputBuf copyToByteArray.

"7. Teardown"
kernel destroy.
outputBuf destroy.
inputBuf  destroy.
ctx destroy.
```

---

## Step-by-step manual pipeline (no PVComputeKernel)

Use this when you need finer control.

### 1. Shader module

```smalltalk
| shaderModule |
shaderModule := VkShaderModule fromBytes: spirvBytes device: ctx device.
```

### 2. Descriptor set layout

Declares the binding schema. One call per storage buffer binding:

```smalltalk
| dsl |
dsl := VkDescriptorSetLayout on: ctx device.
dsl addStorageBufferBinding: 0 stageFlags: VkShaderStage computeBit.
dsl addStorageBufferBinding: 1 stageFlags: VkShaderStage computeBit.
dsl create.
```

`addStorageBufferBinding:stageFlags:` stores:
`{ bindingIndex. VkDescriptorType storageBuffer. descriptorCount=1. stageFlags }`

`create` calls `vkCreateDescriptorSetLayout` with these as
`VkDescriptorSetLayoutBinding` entries.

### 3. Pipeline layout

```smalltalk
| pipelineLayout |
pipelineLayout := VkPipelineLayout on: ctx device setLayouts: (Array with: dsl).
```

### 4. Compute pipeline

```smalltalk
| pipeline |
pipeline := VkComputePipeline
    on: shaderModule
    layout: pipelineLayout
    device: ctx device.
```

Creates a `VkComputePipelineCreateInfo` with a single
`VkPipelineShaderStageCreateInfo` (sType=`computePipelineCreateInfo`,
stage=`VkShaderStage computeBit`, entry point = `'main'`).

### 5. Descriptor pool + set

```smalltalk
| pool descriptorSet |
pool := VkDescriptorPool on: ctx device maxSets: 1 descriptorCount: 2.
"maxSets = sets allocated out of the pool; descriptorCount = storage buffers they hold"

descriptorSet := pool allocateSet: dsl.
```

`VkDescriptorPool>>create:descriptorCount:` creates one
`VkDescriptorPoolSize` entry of type `VkDescriptorType storageBuffer` with
that `descriptorCount`, and bounds the pool at `maxSets` sets. The two
numbers are independent: a compute kernel puts every binding in one set, so
it asks for one set holding as many descriptors as it has buffers. Asking
for `maxSets` 0 — which the old one-argument API did for a kernel with no
buffers — is accepted by the driver here and then fails one call later in
`allocateSet:` with `VK_ERROR_OUT_OF_POOL_MEMORY`; `PVComputeKernel >>
prepare` now refuses a kernel with no bound buffer instead.

### 6. Bind buffers to descriptor set

```smalltalk
descriptorSet updateStorageBuffer: inputBuf  atBinding: 0.
descriptorSet updateStorageBuffer: outputBuf atBinding: 1.
```

Each call issues `vkUpdateDescriptorSets` with a `VkWriteDescriptorSet`
(sType=`writeDescriptorSet`, descriptorType=`VkDescriptorType storageBuffer`)
wrapping a `VkDescriptorBufferInfo` (buffer handle, offset=0, range=WHOLE_SIZE).

### 7. Command pool + buffer + dispatch

```smalltalk
| commandPool cb |
commandPool := VkCommandPool on: ctx device queueFamilyIndex: ctx computeQueueFamily.

cb := commandPool allocateBuffer.
cb do: [:c |
    c bindComputePipeline: pipeline.
    c bindDescriptorSets: (Array with: descriptorSet) pipelineLayout: pipelineLayout.
    c dispatch: 64 y: 1 z: 1].
```

`cb do: [...]` calls `vkBeginCommandBuffer`, runs the block, then
`vkEndCommandBuffer`. Inside:
- `bindComputePipeline:` → `vkCmdBindPipeline` (bind point 1 = COMPUTE)
- `bindDescriptorSets:pipelineLayout:` → `vkCmdBindDescriptorSets`
  (bind point 1, firstSet=0)
- `dispatch:y:z:` → `vkCmdDispatch(groupCountX, groupCountY, groupCountZ)`

### 8. Submit and wait

```smalltalk
ctx computeQueue submit: cb andWait: true.
```

`submit:andWait:` builds a `VkSubmitInfo2` with one
`VkCommandBufferSubmitInfo`, calls `vkQueueSubmit2`, then (if `doWait` is
true) calls `vkQueueWaitIdle`.

You can also wait manually:

```smalltalk
ctx computeQueue submit: cb andWait: false.
ctx computeQueue waitIdle.
```

### 9. Tear down

```smalltalk
commandPool     destroy.
pool            destroy.
pipeline        destroy.
pipelineLayout  destroy.
dsl             destroy.
shaderModule    destroy.
outputBuf       destroy.
inputBuf        destroy.
ctx             destroy.
```

---

## Workgroup sizing

`dispatch: x y: y z: z` specifies the **workgroup count**, not the global
thread count. The SPIR-V emitter currently sets the local workgroup size via
`OpExecutionMode LocalSize 1 1 1`. This means:

- `dispatch: 64 y: 1 z: 1` → 64 workgroups × 1 thread = 64 total invocations
- Each invocation runs the kernel function once

To process `N` elements in parallel with one thread per element, dispatch
`N y: 1 z: 1`.

---

## Using direct SpvModule to build compute shaders

If the Pharo→SPIR-V compiler does not cover your use case (e.g. you need
buffer access chains or the global invocation ID), build the SPIR-V manually:

```smalltalk
| mod tr cp u32 u32ptr voidType funcType inBuf outBuf fn blk gidType gid ... |
mod := SpvModule new initialize.
mod addCapability: 1.    "Shader"
mod setAddressingModel: 0 memoryModel: 1.    "Logical GLSL450"

tr := mod typeRegistry.

"--- types ---"
u32    := tr intType: 32 signed: false.
voidType := tr voidType.
funcType := tr functionType: voidType paramTypes: #().

"--- declare storage buffer interface block ---"
"(requires Block decoration, RuntimeArray member, etc.)"
"... see SPIR-V spec §2.16.1 for storage buffer layout ..."

"--- execution mode: 64 invocations in X ---"
fn := SpvFunction new
    id: mod newId; returnType: voidType; functionType: funcType;
    module: mod; initialize; yourself.
mod addFunction: fn.
mod addEntryPoint: fn executionModel: SpvExecutionModel glCompute
    name: 'main' interfaces: #().
mod addExecutionMode: fn mode: 17 literals: (Array with: 64 with: 1 with: 1).
"mode 17 = LocalSize"
```

The builder has all the primitives (`SpvInstruction`, `SpvOpcode`, etc.)
needed to emit any SPIR-V instruction. Check `SpvOpcode` for all supported
opcodes and `SpvDecoration` for decoration constants.

---

## Compiler limitations (Phase 1–6)

| Limitation | Reason |
|---|---|
| No buffer indexing | Compiler emits scalar functions; no OpAccessChain into runtime arrays |
| No `gl_GlobalInvocationID` | No built-in variable access in the generated shader |
| No `u32` / `i32` literals | Integer literals in Pharo bytecode are SmallIntegers; only `0` works reliably |
| Monomorphic only | One receiver type per message send; no polymorphic dispatch |
| No cross-method calls | No inlining; `^` inside a nested block does non-local return |
| Straight-line + one level of nesting | CFG recogniser handles one `ifTrue:ifFalse:` or one `whileTrue:` per method |

For production workloads needing buffer access or invocation IDs, use
`SpvModule` directly (see above).
