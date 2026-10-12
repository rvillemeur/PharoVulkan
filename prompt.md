# PharoVulkan — Implementation Prompt

This document is the detailed specification for each implementation phase.
Read the relevant phase section before writing any code.
Each phase must pass its own tests before the next phase begins.

---

## Phase 1 — Generator, Bindings, SPIR-V Builder

**Goal**: Pharo can call `vkCreateInstance`, enumerate physical devices, and
build + validate a hand-crafted vector-add SPIR-V module.

**Packages**: `PharoVulkan-Generator`, `PharoVulkan-Bindings`,
`PharoVulkan-SPIRV`, `PharoVulkan-Tests-Bindings`, `PharoVulkan-Tests-SPIRV`

**Done when**: `VkBindingsTest` and `SpvBuilderTest` pass in a clean image.

---

### 1A. Generator (`PharoVulkan-Generator`)

The generator reads Khronos schema files and emits Pharo classes into the live
image. It runs once to bootstrap the bindings; re-running must be idempotent.

**Input files** (download once, store outside the Pharo image):
- `vk.xml` — Vulkan API registry (Khronos GitHub: KhronosGroup/Vulkan-Headers)
- `spirv.core.grammar.json` — SPIR-V grammar (KhronosGroup/SPIRV-Headers)

---

#### Class: `VkXmlParser`

**Purpose**: Parses `vk.xml` and produces structured descriptor objects for
types, commands, enums, and struct members. All parsing is done here; no
Pharo class generation happens in this class.

Instance variables: `xml` (parsed XML document), `types` (Dictionary),
`commands` (Dictionary), `enums` (Dictionary).

Key methods:
- `parseFile: aFilePath` — entry point; loads and parses the XML file.
- `types` — Dictionary of type name → `VkTypeDescriptor`.
- `commands` — Dictionary of command name → `VkCommandDescriptor`.
- `enums` — Dictionary of enum name → `VkEnumDescriptor`.
- `parseTypes` — private; iterates `<types>` nodes.
- `parseCommands` — private; iterates `<commands>` nodes.
- `parseEnums` — private; iterates `<enums>` nodes.

---

#### Class: `VkTypeDescriptor`

**Purpose**: Describes one Vulkan type as parsed from `vk.xml`.

Instance variables: `name` (String), `category` (Symbol: `#struct`,
`#union`, `#handle`, `#enum`, `#bitmask`, `#basetype`, `#funcpointer`),
`members` (OrderedCollection of `VkMemberDescriptor`),
`requires` (String or nil), `alias` (String or nil).

---

#### Class: `VkMemberDescriptor`

**Purpose**: Describes one member of a Vulkan struct.

Instance variables: `name`, `type`, `isPointer` (Boolean),
`isConst` (Boolean), `arrayLen` (String or nil).

---

#### Class: `VkCommandDescriptor`

**Purpose**: Describes one Vulkan function.

Instance variables: `name`, `returnType`, `params` (OrderedCollection
of `VkParamDescriptor`), `successCodes` (Array), `errorCodes` (Array).

---

#### Class: `VkParamDescriptor`

**Purpose**: Describes one parameter of a Vulkan function.

Instance variables: `name`, `type`, `isPointer`, `isConst`,
`optional` (Boolean), `len` (String or nil).

---

#### Class: `VkEnumDescriptor`

**Purpose**: Describes one Vulkan enum or bitmask group.

Instance variables: `name`, `type` (Symbol: `#enum` or `#bitmask`),
`values` (Dictionary of valueName → Integer).

---

#### Class: `VkBindingGenerator`

**Purpose**: Takes `VkXmlParser` output and creates Pharo classes in the live
image. The generator is the only place allowed to create binding classes — do
not write bindings by hand.

Instance variables: `parser` (VkXmlParser), `targetEnvironment`
(the Pharo namespace, defaults to `Smalltalk globals`).

Key methods:
- `generateAll` — runs all sub-generators in dependency order:
  enums first, then structs, then commands.
- `generateEnum: aVkEnumDescriptor` — creates a `SharedPool` subclass with
  class-side constant methods for each enum value.
- `generateStruct: aVkTypeDescriptor` — creates a `VkStructure` subclass
  with FFI field layout matching the C struct.
- `generateHandle: aVkTypeDescriptor` — creates a `VkHandle` subclass.
- `generateCommands` — adds class-side `ffiCall:` methods to `Vk`.
- `isIdempotent` — returns true if re-running produces no changes.

**Important**: generator must not overwrite classes that have been manually
extended. Check for existing methods before generating; skip if present and
warn to the Transcript.

---

#### Class: `SpvGrammarParser`

**Purpose**: Parses `spirv.core.grammar.json` and produces instruction +
operand descriptors. Output drives both the SPIR-V builder API and the
emitter in Phase 3.

Instance variables: `grammar` (parsed JSON Dictionary),
`instructions` (Dictionary of opname → `SpvInstructionDescriptor`),
`operandKinds` (Dictionary of kind name → `SpvOperandKindDescriptor`).

Key methods:
- `parseFile: aFilePath` — loads and parses JSON.
- `instructions` — Dictionary of opname string → descriptor.
- `operandKinds` — Dictionary of kind name → descriptor.

---

#### Class: `SpvInstructionDescriptor`

**Purpose**: Describes one SPIR-V instruction from the grammar.

Instance variables: `opname` (String), `opcode` (Integer),
`operands` (Array of `SpvOperandDescriptor`), `capabilities` (Array).

---

#### Class: `SpvOperandDescriptor`

**Purpose**: Describes one operand of a SPIR-V instruction.

Instance variables: `kind` (String), `name` (String or nil),
`quantifier` (Symbol: `#required`, `#optional`, `#variadic`).

---

#### Class: `SpvBuilderGenerator`

**Purpose**: Takes `SpvGrammarParser` output and emits a builder method on
`SpvBuilder` for each SPIR-V instruction. Each builder method validates
operands at construction time and returns an `SpvInstruction`.

Key methods:
- `generateAll` — creates one method per instruction in the grammar.
- `generateInstruction: anSpvInstructionDescriptor` — emits one builder
  method with the right arity.

---

### 1B. Bindings (`PharoVulkan-Bindings`)

These classes are generated by `VkBindingGenerator`. The hand-written
parts are: `VkLibrary`, `VkHandle`, `VkStructure`, and the `Vk` entry
class. Everything else is generated.

---

#### Class: `VkLibrary` (extends `FFILibrary`)

**Purpose**: Locates `libvulkan.so.1` on the system. All Vulkan FFI calls
route through this library.

Key methods (all class-side):
- `unixLibraryName` → `'libvulkan.so.1'`
- `win32LibraryName` → `'vulkan-1.dll'`
- `macLibraryName` → `'libMoltenVK.dylib'`

---

#### Class: `VkHandle` (extends `FFIExternalObject`)

**Purpose**: Base class for all opaque Vulkan handle types (`VkInstance`,
`VkDevice`, `VkQueue`, etc.). Provides a shared `isNull` check.

Key methods:
- `isNull` — returns `self getHandle isNull`.
- `printOn: aStream` — prints class name + handle address hex.

Subclasses (generated): `VkInstance_H`, `VkPhysicalDevice_H`, `VkDevice_H`,
`VkQueue_H`, `VkCommandPool_H`, `VkCommandBuffer_H`, `VkBuffer_H`,
`VkDeviceMemory_H`, `VkDescriptorPool_H`, `VkDescriptorSetLayout_H`,
`VkDescriptorSet_H`, `VkPipelineLayout_H`, `VkPipeline_H`, `VkShaderModule_H`.

Note: suffix `_H` avoids collision with higher-level wrapper classes that
share the same root name (e.g. `VkDevice` wraps `VkDevice_H`).

---

#### Class: `VkStructure` (extends `FFIExternalStructure`)

**Purpose**: Base class for all Vulkan struct types. Provides `sType:`
initialization and a `asPointer` convenience.

Key methods:
- `initialize` — subclasses override to set `sType` field to the correct
  `VkStructureType` constant.
- `asPointer` — returns `self`.

Subclasses (generated, Phase 1 subset):
`VkApplicationInfo`, `VkInstanceCreateInfo`, `VkPhysicalDeviceProperties`,
`VkExtensionProperties`, `VkQueueFamilyProperties`.

---

#### Class: `Vk` (hand-written, class-side only)

**Purpose**: Entry point for all Vulkan function calls. Mirrors the pattern
of Pharo's `SDL2` class. All methods are class-side `ffiCall:` wrappers.
Generated methods are added by `VkBindingGenerator`.

Key hand-written class-side methods:
- `ffiLibrary` → `VkLibrary`
- `checkResult: aVkResult` — raises `VkError` if result is not
  `VK_SUCCESS`. Call after every Vulkan function that returns `VkResult`.

Generated class-side methods (Phase 1 subset):
```smalltalk
createInstance: pCreateInfo allocator: pAllocator instance: pInstance
    ^ self ffiCall: #( VkResult vkCreateInstance (
        VkInstanceCreateInfo* pCreateInfo,
        void* pAllocator,
        VkInstance_H* pInstance ) )

destroyInstance: instance allocator: pAllocator
    ^ self ffiCall: #( void vkDestroyInstance (
        VkInstance_H instance,
        void* pAllocator ) )

enumeratePhysicalDevices: instance physicalDeviceCount: pPhysicalDeviceCount physicalDevices: pPhysicalDevices
    ^ self ffiCall: #( VkResult vkEnumeratePhysicalDevices (
        VkInstance_H instance,
        uint32* pPhysicalDeviceCount,
        VkPhysicalDevice_H* pPhysicalDevices ) )

getPhysicalDeviceProperties: physicalDevice properties: pProperties
    ^ self ffiCall: #( void vkGetPhysicalDeviceProperties (
        VkPhysicalDevice_H physicalDevice,
        VkPhysicalDeviceProperties* pProperties ) )
```

---

#### Class: `VkResult` (hand-written)

**Purpose**: Wraps a VkResult integer. Knows which values are errors.

Class-side constants: `VK_SUCCESS`, `VK_NOT_READY`, `VK_TIMEOUT`,
`VK_ERROR_OUT_OF_HOST_MEMORY`, etc.

Key methods:
- `isSuccess` — returns `self value = VK_SUCCESS`.
- `isError` — returns `self value < 0` (all Vulkan error codes are negative).
- `signal` — raises `VkError` with the result name.

---

#### Class: `VkError` (extends `Error`)

**Purpose**: Raised when a Vulkan call returns a non-success `VkResult`.

Instance variables: `result` (VkResult).
Key method: `messageText` — returns `'Vulkan error: ', result name`.

---

### 1C. SPIR-V Builder (`PharoVulkan-SPIRV`)

The builder API lets Pharo code construct a valid SPIR-V module from
Pharo objects, then serialize it to a `ByteArray`.

---

#### Class: `SpvModule`

**Purpose**: Top-level container for a SPIR-V module. Owns all sections:
capabilities, extensions, extended instruction sets, memory model,
entry points, execution modes, decorations, types, constants, globals,
and functions.

Instance variables: `capabilities` (OrderedCollection of Symbol),
`extensions` (OrderedCollection of String),
`extInstSets` (Dictionary of name → result id),
`addressingModel` (Symbol), `memoryModel` (Symbol),
`entryPoints` (OrderedCollection of SpvEntryPoint),
`executionModes` (OrderedCollection),
`decorations` (OrderedCollection of SpvDecoration),
`typeRegistry` (SpvTypeRegistry),
`constantPool` (SpvConstantPool),
`globalVariables` (OrderedCollection of SpvGlobalVariable),
`functions` (OrderedCollection of SpvFunction),
`nextId` (Integer, starts at 1).

Key methods:
- `newId` — returns next fresh result id as an Integer; increments `nextId`.
- `addCapability: aSymbol` — e.g. `#Shader`, `#Int64`.
- `addExtension: aString` — e.g. `'SPV_KHR_vulkan_memory_model'`.
- `importExtInstSet: aName` — imports GLSL.std.450 or similar, returns id.
- `setAddressingModel: addrModel memoryModel: memModel` — sets both.
- `addEntryPoint: anSpvFunction executionModel: aSymbol name: aString interfaces: anArray`.
- `addExecutionMode: anSpvFunction mode: aSymbol literals: anArray`.
- `typeRegistry` — returns the `SpvTypeRegistry`.
- `constantPool` — returns the `SpvConstantPool`.
- `addFunction: anSpvFunction`.
- `addGlobalVariable: anSpvGlobalVariable`.
- `addDecoration: anId decoration: aSymbol literals: anArray`.
- `addMemberDecoration: aStructId member: idx decoration: aSymbol literals: anArray`.
- `serialize` — returns a `ByteArray` (valid SPIR-V binary).
- `bound` — returns `nextId`.

---

#### Class: `SpvTypeRegistry`

**Purpose**: Deduplicates SPIR-V type declarations. Every unique type
(by structure) maps to exactly one result id. Callers request a type
object; the registry returns the existing one or creates a new one.

Instance variables: `module` (SpvModule), `types` (Dictionary of key → SpvType).

Key methods:
- `voidType` → `SpvVoidType`
- `boolType` → `SpvBoolType`
- `intType: width signed: aBoolean` → `SpvIntType`
- `floatType: width` → `SpvFloatType`
- `vectorType: componentType count: n` → `SpvVectorType`
- `pointerType: storageClass type: baseType` → `SpvPointerType`
- `functionType: returnType paramTypes: anArray` → `SpvFunctionType`
- `arrayType: elementType length: constId` → `SpvArrayType`
- `runtimeArrayType: elementType` → `SpvRuntimeArrayType`
- `structType: memberTypes` → `SpvStructType`

---

#### Class: `SpvType` (abstract)

**Purpose**: Represents one SPIR-V type declaration.

Instance variables: `id` (Integer), `module` (SpvModule).
Key methods: `id`, `encodeInto: aWordStream` (abstract),
`key` (abstract — used by registry for deduplication).

Concrete subclasses: `SpvVoidType`, `SpvBoolType`, `SpvIntType`
(width, signed), `SpvFloatType` (width), `SpvVectorType` (component, count),
`SpvPointerType` (storageClass, baseType), `SpvFunctionType` (return, params),
`SpvArrayType` (element, lengthId), `SpvRuntimeArrayType` (element),
`SpvStructType` (members).

---

#### Class: `SpvConstantPool`

**Purpose**: Deduplicates SPIR-V constant declarations.

Key methods:
- `constantTrue` — `OpConstantTrue`
- `constantFalse` — `OpConstantFalse`
- `constantInt32: anInteger` — `OpConstant` for i32
- `constantUInt32: anInteger` — `OpConstant` for u32
- `constantFloat32: aFloat` — `OpConstant` for f32
- `constantNull: aType` — `OpConstantNull`
- `undef: aType` — `OpUndef`

---

#### Class: `SpvFunction`

**Purpose**: A SPIR-V function. Owns an ordered list of basic blocks.
The first block is the entry block.

Instance variables: `id` (Integer), `module`, `returnType`,
`functionType`, `parameters` (OrderedCollection of SpvFunctionParameter),
`blocks` (OrderedCollection of SpvBlock).

Key methods:
- `addParameter: aType` — appends an `OpFunctionParameter`, returns its id.
- `addBlock` — appends a new empty `SpvBlock`, returns it.
- `encodeInto: aWordStream`.

---

#### Class: `SpvBlock`

**Purpose**: A SPIR-V basic block. Owns an ordered list of instructions.
Every block must end with exactly one terminator instruction
(`OpBranch`, `OpBranchConditional`, `OpReturn`, `OpReturnValue`,
`OpKill`, `OpUnreachable`).

Instance variables: `id` (Integer), `function`, `instructions`
(OrderedCollection of SpvInstruction), `terminator` (SpvInstruction or nil).

Key methods:
- `addInstruction: anSpvInstruction` — appends a non-terminator instruction.
- `terminate: anSpvInstruction` — sets the terminator.
- `isTerminated` — returns `terminator notNil`.
- `encodeInto: aWordStream`.

---

#### Class: `SpvBuilder`

**Purpose**: High-level façade over `SpvModule`. Provides one method per
SPIR-V instruction (generated by `SpvBuilderGenerator`). Callers use
only `SpvBuilder` — they never touch `SpvModule` directly.

Instance variables: `module` (SpvModule), `currentBlock` (SpvBlock or nil).

Key methods (hand-written):
- `newModule` — creates and returns a fresh `SpvModule`.
- `setCurrentBlock: aBlock` — sets insertion point.
- `currentBlock` — the current insertion block.

Generated methods (one per instruction, naming convention: camelCase opname
minus `Op` prefix, e.g. `opFAdd` → `fAdd:b:type:`). Generated methods:
1. allocate a new result id via `module newId`,
2. construct an `SpvInstruction`,
3. append to `currentBlock` (or to the appropriate section for type/const decls),
4. return the result id.

---

#### Class: `SpvInstruction`

**Purpose**: One encoded SPIR-V instruction: opcode + result id (if any) +
operands (all Integers or result id references).

Instance variables: `opcode` (Integer), `resultId` (Integer or nil),
`operands` (Array of Integer).

Key methods:
- `wordCount` — `2 + operands size` (or `1 + operands size` if no result).
- `encodeInto: aWordStream` — writes `(wordCount << 16) | opcode` then
  `resultId` (if present) then each operand word.

---

#### Class: `SpvSerializer`

**Purpose**: Walks a `SpvModule` and emits the complete SPIR-V binary
word stream in the correct section order.

Section order (SPIR-V 1.5 §2.4):
1. Header (5 words: magic, version, generator, bound, schema=0)
2. Capabilities (`OpCapability`)
3. Extensions (`OpExtension`)
4. Extended instruction set imports (`OpExtInstImport`)
5. Memory model (`OpMemoryModel`)
6. Entry points (`OpEntryPoint`)
7. Execution modes (`OpExecutionMode`)
8. Annotations (`OpDecorate`, `OpMemberDecorate`)
9. Type declarations + constants + global variables
10. Functions

Key methods:
- `serialize: anSpvModule` → `ByteArray`
- `writeHeader:` (private)
- `writeSection:` (private, takes an OrderedCollection of SpvInstruction)

---

#### Class: `SpvValidator`

**Purpose**: Runs `spirv-val` (from system PATH or a configured path) on a
SPIR-V `ByteArray`. Raises `SpvValidationError` on failure.

Key methods:
- `validate: aByteArray` — writes bytes to a temp file, invokes `spirv-val`,
  raises `SpvValidationError` with the validator output if exit code ≠ 0.
- `spirvValPath` — class-side; returns path to `spirv-val` binary.
  Defaults to `'spirv-val'` (from PATH). Override for custom install.

---

#### Class: `SpvValidationError` (extends `Error`)

**Purpose**: Raised when `spirv-val` reports an error.

Instance variables: `validatorOutput` (String).
Key method: `messageText` → `'SPIR-V validation failed: ', validatorOutput`.

---

### 1D. Tests

#### Class: `VkBindingsTest` (extends `TestCase`, package `PharoVulkan-Tests-Bindings`)

Tests verify the bindings work against the real Vulkan loader.
**Prerequisite**: `libvulkan.so.1` must be present on the test machine.
Tests that require a GPU are tagged `<requiresGPU>` and skipped otherwise.

Required tests:
- `testLibraryLoads` — `VkLibrary uniqueInstance notNil`.
- `testCreateDestroyInstance` — create a `VkInstance` with a minimal
  `VkApplicationInfo`, verify it is not null, destroy it.
- `testEnumeratePhysicalDevices` — after instance creation, enumerate
  physical devices; assert count > 0.
- `testPhysicalDeviceProperties` — fetch properties for the first device;
  assert `deviceName` is a non-empty string.
- `testGeneratorIsIdempotent` — run `VkBindingGenerator generateAll`
  twice; assert no new classes are created on the second run.

---

#### Class: `SpvBuilderTest` (extends `TestCase`, package `PharoVulkan-Tests-SPIRV`)

Required tests:
- `testSerializeHeader` — build an empty module; serialize; verify the
  first 4 bytes are `0x03 0x02 0x23 0x07` (SPIR-V magic, little-endian).
- `testTypeDeduplication` — request `floatType: 32` twice; assert both
  calls return the same object (same id).
- `testConstantDeduplication` — request `constantFloat32: 1.0` twice;
  assert same object.
- `testVectorAddModule` — build a compute SPIR-V module implementing
  `result[i] = a[i] + b[i]` by hand using `SpvBuilder`; serialize;
  validate with `SpvValidator`. This is the primary integration test for
  Phase 1.
- `testValidatorRaisesOnGarbage` — pass a bogus `ByteArray` to
  `SpvValidator`; assert `SpvValidationError` is raised.

The vector-add module spec (for `testVectorAddModule`):
```
Execution model:  GLCompute
Capability:       Shader
Memory model:     Logical / GLSL450
Entry point name: "main"
Execution mode:   LocalSize 64 1 1
Bindings:
  binding 0 = input buffer A  (float[])
  binding 1 = input buffer B  (float[])
  binding 2 = output buffer R (float[])
GlobalInvocationId used to index.
```

---

## Phase 2 — Compute Bring-up

**Goal**: Vector-add kernel runs on GPU using pre-compiled SPIR-V bytes.
No DSL compiler yet — SPIR-V is the `ByteArray` built in Phase 1.

**Packages**: `PharoVulkan-Core`, `PharoVulkan-Compute`,
`PharoVulkan-Tests-Core`, `PharoVulkan-Tests-Compute`

**Done when**: `PVComputeTest >> testVectorAdd` passes on a machine with
a Vulkan-capable GPU.

---

### 2A. Core lifecycle (`PharoVulkan-Core`)

#### Class: `VkContext`

**Purpose**: Owns the top-level Vulkan state: `VkInstance`, selected
`VkPhysicalDevice`, `VkDevice`, and one compute `VkQueue`. The single
entry point for application code to get a working Vulkan context.

Instance variables: `instance` (VkInstance_H), `physicalDevice`
(VkPhysicalDevice), `device` (VkDevice), `computeQueue` (VkQueue),
`computeQueueFamily` (Integer).

Class-side factory methods:
- `computeContext` — creates a context with compute queue only, no
  surface, no validation layers. Suitable for headless compute.
- `computeContextWithValidation` — same but enables
  `VK_LAYER_KHRONOS_validation`.

Key instance methods:
- `initialize` — called by factory; drives the init sequence.
- `selectPhysicalDevice` — picks the first device with a compute queue.
  Prefers discrete GPU over integrated.
- `createLogicalDevice` — creates device with one compute queue.
- `destroy` — destroys device then instance in reverse order.

---

#### Class: `VkPhysicalDevice`

**Purpose**: Wraps a `VkPhysicalDevice_H` handle and caches properties,
queue family properties, and memory properties.

Instance variables: `handle` (VkPhysicalDevice_H), `properties`
(VkPhysicalDeviceProperties), `queueFamilyProperties`
(Array of VkQueueFamilyProperties), `memoryProperties`
(VkPhysicalDeviceMemoryProperties).

Key methods:
- `fetchProperties` — calls `vkGetPhysicalDeviceProperties`.
- `fetchQueueFamilyProperties` — calls `vkGetPhysicalDeviceQueueFamilyProperties`.
- `fetchMemoryProperties` — calls `vkGetPhysicalDeviceMemoryProperties`.
- `findComputeQueueFamily` — returns index of first queue family with
  `VK_QUEUE_COMPUTE_BIT` set. Raises `VkError` if none found.
- `findMemoryType: typeFilter properties: propertyFlags` — returns memory
  type index matching filter and flags.

---

#### Class: `VkDevice`

**Purpose**: Wraps a `VkDevice_H` (logical device). Factory for all
device-owned objects (command pools, descriptor pools, buffers, etc.).

Instance variables: `handle` (VkDevice_H), `physicalDevice`
(VkPhysicalDevice), `context` (VkContext).

Key methods:
- `getQueue: familyIndex index: queueIndex` → `VkQueue`.
- `createCommandPool: queueFamilyIndex` → `VkCommandPool`.
- `createDescriptorPool: maxSets descriptorCount: descriptorCount` → `VkDescriptorPool`.
- `allocateBuffer: size usage: usageFlags` → `VkBuffer`.
- `createShaderModule: spirvBytes` → `VkShaderModule`.
- `destroy` — calls `vkDestroyDevice`.

---

#### Class: `VkQueue`

**Purpose**: Wraps a `VkQueue_H`. Submits command buffers using
synchronization2 (`vkQueueSubmit2KHR`).

Instance variables: `handle` (VkQueue_H), `familyIndex`.

Key methods:
- `submit: aCommandBuffer` — wraps in `VkSubmitInfo2KHR`, submits,
  does not wait.
- `submit: aCommandBuffer andWait: aBoolean` — submits; if `aBoolean`,
  calls `waitIdle`.
- `waitIdle` — calls `vkQueueWaitIdle`.

---

#### Class: `VkCommandPool`

**Purpose**: Wraps `VkCommandPool_H`. Allocates command buffers.

Instance variables: `handle`, `device`, `queueFamilyIndex`.

Key methods:
- `allocateBuffer` → `VkCommandBuffer` (allocates one primary buffer).
- `reset` — calls `vkResetCommandPool`.
- `destroy`.

---

#### Class: `VkCommandBuffer`

**Purpose**: Wraps `VkCommandBuffer_H`. Records Vulkan commands.
Designed for one-shot use in Phase 2; reset and reuse in later phases.

Instance variables: `handle`, `pool`.

Key methods:
- `begin` — calls `vkBeginCommandBuffer` with one-time-submit flag.
- `end` — calls `vkEndCommandBuffer`.
- `bindComputePipeline: aVkComputePipeline`.
- `bindDescriptorSets: anArrayOfSets pipelineLayout: aLayout`.
- `dispatch: x y: y z: z`.
- `pipelineBarrier2: aVkDependencyInfo` — uses synchronization2.
- `do: aBlock` — convenience: calls `begin`, evaluates `aBlock` with self,
  calls `end`.

---

#### Class: `VkBuffer`

**Purpose**: A Vulkan buffer + its bound device memory. Encapsulates the
three-step Vulkan buffer lifecycle: create, allocate memory, bind.

Instance variables: `handle` (VkBuffer_H), `memory` (VkDeviceMemory_H),
`size` (Integer), `usage` (Integer), `device` (VkDevice),
`mappedPointer` (FFIExternalObject or nil).

Key methods:
- `allocate` — creates buffer, finds compatible memory type, allocates and
  binds memory.
- `map` → FFI pointer to mapped memory.
- `unmap`.
- `copyFromByteArray: aByteArray` — maps, copies, unmaps.
- `copyToByteArray` → `ByteArray`.
- `destroy`.

---

#### Class: `VkMemoryAllocator`

**Purpose**: Simple device memory allocator for Phase 2. One allocation
per buffer; no suballocation. Phase 7 may replace this with a pool.

Instance variables: `device` (VkDevice), `physicalDevice` (VkPhysicalDevice).

Key methods:
- `allocate: size memoryTypeIndex: index` → `VkDeviceMemory_H`.
- `free: aVkDeviceMemory_H`.

---

#### Class: `VkShaderModule`

**Purpose**: Wraps `VkShaderModule_H`. Created from a SPIR-V `ByteArray`.

Instance variables: `handle`, `device`.

Key methods:
- `destroy`.

Class-side:
- `fromBytes: aByteArray device: aVkDevice` → `VkShaderModule`.

---

### 2B. Compute pipeline (`PharoVulkan-Compute`)

#### Class: `VkDescriptorSetLayout`

**Purpose**: Describes the set of bindings (buffers, images, samplers)
that a pipeline accepts at one descriptor set slot.

Instance variables: `handle`, `device`,
`bindings` (OrderedCollection of VkDescriptorSetLayoutBinding structs).

Key methods:
- `addStorageBufferBinding: index stageFlags: flags` — appends a
  `VkDescriptorSetLayoutBinding` for a storage buffer.
- `create` — calls `vkCreateDescriptorSetLayout`.
- `destroy`.

---

#### Class: `VkPipelineLayout`

**Purpose**: Wraps `VkPipelineLayout_H`. Owns descriptor set layouts and
push constant ranges.

Instance variables: `handle`, `device`,
`setLayouts` (Array of VkDescriptorSetLayout),
`pushConstantRanges` (Array of VkPushConstantRange).

Key methods:
- `create`.
- `destroy`.

---

#### Class: `VkComputePipeline`

**Purpose**: Wraps a compute `VkPipeline_H`.

Instance variables: `handle`, `device`, `layout` (VkPipelineLayout),
`shaderModule` (VkShaderModule), `entryPoint` (String, default `'main'`).

Key methods:
- `create` — calls `vkCreateComputePipelines`.
- `destroy`.

---

#### Class: `VkDescriptorPool`

**Purpose**: Wraps `VkDescriptorPool_H`. Allocates descriptor sets.

Instance variables: `handle`, `device`.

Key methods:
- `allocateSet: aVkDescriptorSetLayout` → `VkDescriptorSet`.
- `destroy`.

---

#### Class: `VkDescriptorSet`

**Purpose**: Wraps `VkDescriptorSet_H`. Binds buffers to pipeline slots.

Instance variables: `handle`, `pool`, `layout`, `device`.

Key methods:
- `updateStorageBuffer: aVkBuffer atBinding: index`.
  Uses `vkUpdateDescriptorSets` with `VkWriteDescriptorSet`.

---

#### Class: `PVComputeKernel`

**Purpose**: High-level façade for a single compute dispatch. Hides raw
Vulkan objects. This is the class application code interacts with.

Instance variables: `context` (VkContext), `spirvBytes` (ByteArray),
`buffers` (Dictionary of index → VkBuffer), `pushConstantData` (ByteArray),
`workgroupCount` (Point3D or nil), `pipeline` (VkComputePipeline),
`layout` (VkPipelineLayout), `descriptorSetLayout` (VkDescriptorSetLayout),
`descriptorSet` (VkDescriptorSet).

Key methods:
- `spirv: aByteArray` — sets the SPIR-V bytes.
- `bindBuffer: aVkBuffer atIndex: index`.
- `setPushConstants: aByteArray`.
- `workgroups: x y: y z: z`.
- `prepare` — creates shader module, pipeline layout, pipeline, descriptor
  set layout, descriptor set, updates descriptors. Must be called once
  before dispatch.
- `dispatch` — records and submits a command buffer; waits for completion.
- `destroy` — frees all owned Vulkan objects.

---

### 2C. Tests

#### Class: `VkCoreTest` (extends `TestCase`, package `PharoVulkan-Tests-Core`)

- `testComputeContextCreation` — `VkContext computeContext` does not raise.
- `testPhysicalDeviceSelection` — context has a non-null physical device.
- `testBufferAllocate` — allocate a 64-byte storage buffer, map it, write
  bytes, unmap, destroy.
- `testBufferRoundtrip` — write a `ByteArray` to a buffer, read it back,
  assert equality.

#### Class: `PVComputeTest` (extends `TestCase`, package `PharoVulkan-Tests-Compute`)

- `testVectorAdd` — the primary Phase 2 integration test.
  1. Build Phase-1 vector-add SPIR-V via `SpvBuilder`.
  2. Create `VkContext computeContext`.
  3. Allocate 3 buffers (A, B, result), fill A and B with known floats.
  4. Create `PVComputeKernel`, bind buffers, dispatch 1 workgroup.
  5. Read result buffer, compare to CPU reference within float tolerance.

---

## Phase 3 — SPIR-V Emitter

**Goal**: Construct the Phase 2 vector-add SPIR-V programmatically from
typed IR nodes (no hand-coded opcode sequences).

**Packages**: extend `PharoVulkan-SPIRV`, extend `PharoVulkan-Tests-SPIRV`

**Done when**: `SpvEmitterTest >> testVectorAddEmitted` produces SPIR-V
that matches the Phase 1 hand-built bytes (or is semantically equivalent
per `spirv-val` + GPU execution).

---

#### Class: `SpvIRNode` (abstract)

**Purpose**: Base for typed IR nodes used by the emitter. Each node
represents one SPIR-V instruction at the semantic level.

Instance variables: `type` (SpvType), `id` (Integer or nil).

---

#### Class: `SpvIRFunction`

**Purpose**: IR-level function. Owns parameters and a list of IR blocks.

Instance variables: `name` (String), `returnType`, `parameterTypes`,
`blocks` (OrderedCollection of SpvIRBlock).

---

#### Class: `SpvIRBlock`

**Purpose**: IR-level basic block. Owns a list of IR nodes.

Instance variables: `id`, `nodes` (OrderedCollection of SpvIRNode),
`terminator` (SpvIRNode).

---

Concrete IR node subclasses (minimum for vector-add):
- `SpvIRLoad` — `pointer` (id), `memoryAccess` (Symbol)
- `SpvIRStore` — `pointer` (id), `value` (id)
- `SpvIRAccessChain` — `base` (id), `indices` (Array of id)
- `SpvIRCompositeExtract` — `composite` (id), `indices` (Array of Integer)
- `SpvIRBinaryOp` — `opcode` (Symbol), `left` (id), `right` (id)
- `SpvIRReturn` — no operands
- `SpvIRReturnValue` — `value` (id)
- `SpvIRBranch` — `target` (id)

---

#### Class: `SpvModuleEmitter`

**Purpose**: Takes a typed `SpvIRFunction` and emits a complete
`SpvModule`. Two-pass: first collects all types and constants for the
preamble, then emits function bodies.

Instance variables: `module` (SpvModule), `functions`
(OrderedCollection of SpvIRFunction), `idMap`
(Dictionary of SpvIRNode → Integer).

Key methods:
- `emit: anSpvIRFunction` → `SpvModule`.
- `collectTypesAndConstants` (private, pass 1).
- `emitFunctions` (private, pass 2).
- `emitNode: anSpvIRNode intoBlock: anSpvBlock` (private).

---

### Phase 3 tests

#### `SpvEmitterTest` additions:

- `testVectorAddEmitted` — construct vector-add via `SpvIRFunction` /
  `SpvModuleEmitter`; validate with `SpvValidator`; run on GPU via
  `PVComputeKernel`; compare result to CPU reference.
- `testEmitterIdempotent` — emitting the same IR twice produces identical
  byte sequences.

---

## Phase 4 — Bytecode Compiler, Straight-Line Methods

**Goal**: A simple Pharo method with no branches compiles end-to-end to
SPIR-V and runs on the GPU.

**Packages**: `PharoVulkan-Compiler`, `PharoVulkan-Tests-Compiler`

**Done when**: `PVCompilerTest >> testStraightLineAdd` passes on GPU.

---

### Type annotation system

Pharo methods intended for GPU compilation are annotated with pragmas:

```smalltalk
addKernel: a to: b result: r workItem: wi
    <gpu>
    <param: #storageBuffer type: #f32Array named: #a>
    <param: #storageBuffer type: #f32Array named: #b>
    <param: #storageBuffer type: #f32Array named: #r>
    <param: #workItem named: #wi>
    | i |
    i := wi globalId x.
    r at: i put: (a at: i) + (b at: i)
```

Pragma grammar:
- `<gpu>` — marks method as a GPU kernel entry point.
- `<param: #storageBuffer type: #f32Array named: #x>` — storage buffer
  binding.
- `<param: #pushConstant type: #u32 named: #n>` — push constant.
- `<param: #workItem named: #wi>` — `WorkItem` object providing
  `globalId`, `localId`, `workgroupId`.

---

#### Class: `PVTypeAnnotation`

**Purpose**: Extracted type info from a compiled method's pragmas.
Consumed by stage ⑥ type inferencer.

Instance variables: `isGPU` (Boolean), `params`
(OrderedCollection of PVParamAnnotation).

Class-side:
- `fromMethod: aCompiledMethod` — extracts pragmas, builds annotation.

---

#### Class: `PVParamAnnotation`

**Purpose**: One parameter's type annotation.

Instance variables: `kind` (Symbol: `#storageBuffer`, `#pushConstant`,
`#workItem`), `type` (Symbol: `#f32Array`, `#f32`, `#u32`, etc.),
`name` (Symbol).

---

#### Class: `PVKernelCompiler`

**Purpose**: Top-level compiler. Drives the 9-stage pipeline and returns
a `SpvModule`.

Instance variables: `method` (CompiledMethod),
`annotation` (PVTypeAnnotation).

Key methods:
- `compile: aCompiledMethod` → `SpvModule`.
- `compileToBytes: aCompiledMethod` → `ByteArray` (serializes + validates).

---

#### Class: `PVBytecodeDecoder` (Stage ②)

**Purpose**: Decodes Pharo Sista bytecodes into `PVBytecodeOp` objects.
Each op captures PC, opcode, operands, and the known stack effect.

Key method:
- `decode: aCompiledMethod` → `OrderedCollection of PVBytecodeOp`.

Uses `InstructionStream` (Pharo's built-in bytecode walker) as the
iteration primitive. Do not implement bytecode decoding from scratch.

---

#### Class: `PVBytecodeOp`

**Purpose**: One decoded Sista bytecode with metadata.

Instance variables: `pc` (Integer), `opcode` (Symbol),
`operands` (Array), `stackEffect` (Integer, may be negative).

---

#### Class: `PVStackSimulator` (Stage ③)

**Purpose**: Walks the flat bytecode op list maintaining a compile-time
stack of virtual register ids. Each pop yields a register id; each push
creates a new one. Output is a flat list of `PVRegisterOp`.

Key property: Sista bytecode has statically known stack depth at every PC.
This makes the simulation deterministic.

Key method:
- `simulate: aCollectionOfBytecodeOps` → `OrderedCollection of PVRegisterOp`.

Instance variables: `stack` (OrderedCollection of Integer),
`nextReg` (Integer), `ops` (output list).

---

#### Class: `PVRegisterOp`

**Purpose**: One register-based operation. Result id is assigned here.

Instance variables: `opcode` (Symbol), `result` (Integer or nil),
`inputs` (Array of Integer), `literal` (Object or nil), `pc` (Integer).

---

#### Class: `PVCFGBuilder` (Stage ④)

**Purpose**: Identifies basic block boundaries from jump targets in the
register op list. Builds a `PVControlFlowGraph`.

Key method:
- `build: aCollectionOfRegisterOps` → `PVControlFlowGraph`.

Algorithm: first pass collects all jump targets (block leaders); second
pass partitions ops into blocks and wires successor edges.

---

#### Class: `PVBasicBlock`

**Purpose**: A basic block in the CFG.

Instance variables: `id` (Integer), `ops` (OrderedCollection of PVRegisterOp),
`successors` (OrderedCollection of PVBasicBlock),
`predecessors` (OrderedCollection of PVBasicBlock).

---

#### Class: `PVControlFlowGraph`

**Purpose**: The full CFG for one method.

Instance variables: `entry` (PVBasicBlock),
`blocks` (OrderedCollection of PVBasicBlock).

Key methods:
- `blockAt: pc` → `PVBasicBlock`.
- `postOrder` → blocks in reverse post-order (used by SSA construction).

---

#### Class: `PVSSAConstructor` (Stage ⑤)

**Purpose**: Transforms the CFG into SSA form using the Braun et al.
on-the-fly algorithm. Reference: Braun, Buchwald, Hack, Leißa, Mallon,
Zwinkau (2013), "Simple and Efficient Construction of Static Single
Assignment Form".

Algorithm summary:
- `writeVariable: var block: b value: v` — records that variable `var`
  has value `v` at end of block `b`.
- `readVariable: var block: b` — returns the current SSA value of `var`
  in block `b`. If `b` has one predecessor, recurse. If multiple
  predecessors, insert an incomplete phi, fill it later.
- Phi nodes are inserted lazily; incomplete phis are resolved when
  a block's predecessor set is known.

Key method:
- `construct: aPVControlFlowGraph` → SSA-form CFG with `PVPhiNode`s.

Do NOT use the Cytron et al. algorithm (requires a separate dominance
tree pass). Braun is ~200 lines with no pre-pass.

---

#### Class: `PVSSAVar`

**Purpose**: One SSA-renamed variable: has a unique name and one def site.

Instance variables: `name` (String), `defBlock` (PVBasicBlock),
`defOp` (PVRegisterOp or PVPhiNode).

---

#### Class: `PVPhiNode`

**Purpose**: An SSA phi instruction.

Instance variables: `id` (Integer), `type` (SpvType),
`block` (PVBasicBlock),
`operands` (Dictionary of PVBasicBlock → Integer "result id").

---

#### Class: `PVTypeInferencer` (Stage ⑥)

**Purpose**: Assigns SPIR-V types to every SSA variable and resolves every
message send to a SPIR-V opcode or a recursive function call.

Key method:
- `infer: aCFG withAnnotation: aPVTypeAnnotation` → typed CFG.

Resolution uses `PVSelectorTable`. Unresolvable sends raise
`PVTypeError`.

---

#### Class: `PVSelectorTable`

**Purpose**: Maps `(selector × receiver-type × arg-types)` to a SPIR-V
opcode or to a special form (recursive call, built-in access).

Class-side:
- `default` — returns the shared table with all built-in mappings.

Key method:
- `lookup: selector receiver: receiverType args: argTypes`
  → `PVSelectorMapping` or raises `PVTypeError`.

Built-in mappings (minimum for straight-line):

| Pharo selector | Receiver type | Result | SPIR-V |
|---|---|---|---|
| `+` | `f32` | `f32` | `OpFAdd` |
| `-` | `f32` | `f32` | `OpFSub` |
| `*` | `f32` | `f32` | `OpFMul` |
| `/` | `f32` | `f32` | `OpFDiv` |
| `+` | `i32` | `i32` | `OpIAdd` |
| `-` | `i32` | `i32` | `OpISub` |
| `*` | `i32` | `i32` | `OpIMul` |
| `//` | `i32` | `i32` | `OpSDiv` |
| `\\` | `i32` | `i32` | `OpSMod` |
| `at:` | `f32Array` | `f32` | `OpAccessChain` + `OpLoad` |
| `at:put:` | `f32Array` | `void` | `OpAccessChain` + `OpStore` |
| `globalId` | `WorkItem` | `uvec3` | `OpLoad GlobalInvocationId` |
| `x` | `uvec3` | `u32` | `OpCompositeExtract 0` |
| `y` | `uvec3` | `u32` | `OpCompositeExtract 1` |
| `z` | `uvec3` | `u32` | `OpCompositeExtract 2` |

---

#### Class: `PVSelectorMapping`

**Purpose**: One resolved mapping from selector to SPIR-V.

Instance variables: `spirvOp` (Symbol), `resultType` (Symbol),
`isSpecialForm` (Boolean), `specialFormHandler` (Block or nil).

---

#### Class: `PVTypeError` (extends `Error`)

**Purpose**: Raised when a selector cannot be resolved.

---

#### Class: `PVSPIRVEmitter` (Stage ⑧)

**Purpose**: Lowers the typed SSA CFG to a `SpvModule`.
Extends `SpvModuleEmitter` with CFG awareness.

For straight-line methods (Phase 4), there is only one block, so no
structured control flow annotation is needed yet.

Key method:
- `emit: aTypedCFG annotation: aPVTypeAnnotation` → `SpvModule`.

---

### Phase 4 tests

#### Class: `PVCompilerTest` (extends `TestCase`, package `PharoVulkan-Tests-Compiler`)

- `testDecoderProducesOps` — decode a known compiled method; assert op
  count matches expected.
- `testStackSimulatorAssignsRegs` — simulate a known method; assert every
  op has correct result/input register ids.
- `testCFGBuilderSingleBlock` — a straight-line method has exactly one block.
- `testSSAConstructorNoPhisForStraightLine` — straight-line method has no
  phi nodes after SSA construction.
- `testTypeInferencerResolvesAdd` — infer types on `a + b` where both are
  f32; assert result type is f32 and op is `OpFAdd`.
- `testStraightLineAdd` — compile `addKernel:to:result:workItem:` (the
  annotated method above); run on GPU; compare to CPU reference.

---

## Phase 5 — Control Flow

**Goal**: DSL kernels can use `to:do:`, `whileTrue:`, and `ifTrue:ifFalse:`.
Compile a dot product and tiled matrix multiply from Pharo source.

**Packages**: extend `PharoVulkan-Compiler`, extend
`PharoVulkan-Tests-Compiler`

**Done when**: `PVCompilerTest >> testMatMul` output matches CPU within
float tolerance.

---

#### Class: `PVStructuredCFGRecognizer` (Stage ⑦)

**Purpose**: Identifies structured control flow patterns in the typed SSA
CFG and annotates blocks with merge information required by SPIR-V.

SPIR-V requires `OpSelectionMerge` before `OpBranchConditional` and
`OpLoopMerge` before a loop header. The recognizer finds these patterns
and attaches `PVMergeAnnotation` to blocks.

Key method:
- `recognize: aTypedCFG` → annotated CFG. Raises `PVUnrecognizedPatternError`
  for unrecognized shapes.

Recognized patterns (all six; see design notes):
1. `ifTrue:ifFalse:` → `OpSelectionMerge` + `OpBranchConditional`
2. `whileTrue:` → `OpLoopMerge` + back edge
3. `to:do:` → `OpLoopMerge` + init + compare + increment
4. `timesRepeat:` → same structure as `to:do:` without accumulator
5. Straight-line → `OpBranch`
6. Early return within a straight-line block

Each recognized shape maps to a `PVStructuredPattern` subclass.

---

#### Class: `PVStructuredPattern` (abstract)

**Purpose**: Represents one recognized structured control flow pattern.

Subclasses: `PVIfThenElsePattern`, `PVWhileTruePattern`,
`PVToDoPattern`, `PVTimesRepeatPattern`, `PVStraightLinePattern`,
`PVEarlyReturnPattern`.

Each subclass knows how to emit the corresponding SPIR-V merge
annotations and terminator instructions.

---

#### Class: `PVMergeAnnotation`

**Purpose**: Attached to a CFG block by the pattern recognizer.
Carries the merge block id and continue block id (for loops).

Instance variables: `mergeBlockId` (Integer),
`continueBlockId` (Integer or nil), `selectionControl` (Integer).

---

#### Class: `PVUnrecognizedPatternError` (extends `Error`)

**Purpose**: Raised when the recognizer sees a CFG shape it cannot handle.
Includes the offending block for diagnosis.

---

### Extend `PVSelectorTable` for control flow

Add mappings for:

| Pharo selector | Receiver type | SPIR-V |
|---|---|---|
| `<` | `f32` | `OpFOrdLessThan` |
| `<=` | `f32` | `OpFOrdLessThanEqual` |
| `=` | `f32` | `OpFOrdEqual` |
| `<` | `i32` | `OpSLessThan` |
| `<=` | `i32` | `OpSLessThanEqual` |
| `=` | `i32` | `OpIEqual` |
| `dot:` | `vec3f` | `OpDot` |
| `sqrt` | `f32` | `OpExtInst GLSL.std.450 Sqrt` |

---

### Phase 5 tests (additions to `PVCompilerTest`)

- `testRecognizerToDoPattern` — recognize `to:do:` in a simple loop
  method; assert pattern is `PVToDoPattern`.
- `testRecognizerIfThenElse` — recognize `ifTrue:ifFalse:` in a clamp
  method; assert pattern is `PVIfThenElsePattern`.
- `testDotProduct` — compile a dot-product kernel from Pharo source;
  run on GPU; compare to CPU reference.
- `testMatMul` — compile a 64×64 float32 matrix multiply from Pharo
  source (using `to:do:` loops); compare GPU output to CPU reference
  within 1e-4 relative tolerance.

---

## Phase 6 — Graphics Path

**Goal**: Hello triangle renders in an SDL2 window using DSL-compiled
vertex and fragment shaders.

**Packages**: `PharoVulkan-SDL2`, `PharoVulkan-Graphics`,
`PharoVulkan-Tests-Graphics`

**Done when**: A window appears, a triangle renders, `spirv-val` passes on
both shaders, and no Vulkan validation layer errors are logged.

---

### 6A. SDL2 Vulkan surface (`PharoVulkan-SDL2`)

#### Class: `SDL2Vulkan`

**Purpose**: Exposes `SDL_Vulkan_*` functions via uFFI. These do not exist
in Pharo's standard SDL2 bindings and must be added here.

All methods class-side. Library: `SDL2Library` (same as SDL2 class).

Key methods:
```smalltalk
loadLibrary: path
    ^ self ffiCall: #( int SDL_Vulkan_LoadLibrary ( String path ) )

getInstanceExtensions: window count: pCount names: ppNames
    ^ self ffiCall: #( SDL_bool SDL_Vulkan_GetInstanceExtensions (
        SDL_Window window, uint32* pCount, void** ppNames ) )

createSurface: window instance: instance surface: pSurface
    ^ self ffiCall: #( SDL_bool SDL_Vulkan_CreateSurface (
        SDL_Window window, VkInstance_H instance, void* pSurface ) )

getDrawableSize: window w: pW h: pH
    ^ self ffiCall: #( void SDL_Vulkan_GetDrawableSize (
        SDL_Window window, int* pW, int* pH ) )

unloadLibrary
    ^ self ffiCall: #( void SDL_Vulkan_UnloadLibrary () )
```

---

#### Class: `OSVulkanAttributes`

**Purpose**: Carries Vulkan-specific window creation parameters. Parallel
to `OSWindowGLAttributes`. Currently no fields — surface creation needs
no extra SDL2-level config — but provides an extension point for future
options (e.g. preferred surface format hints).

No methods on existing classes. `OSWindowAttributes` is not touched.
Application code uses `PVWindowAttributes` (see below) instead.

---

#### Class: `PVWindowAttributes` (extends `OSWindowAttributes`)

**Purpose**: Extends `OSWindowAttributes` with a `vulkanAttributes` slot.
Application code uses `PVWindowAttributes` instead of `OSWindowAttributes`
when creating Vulkan windows. No modification to the base class.

Instance variables: `vulkanAttributes` (OSVulkanAttributes or nil).

Key methods:
- `vulkanAttributes` / `vulkanAttributes:` — accessor pair.
- `initialize` — calls super, sets `vulkanAttributes := nil`.

---

#### Class: `PVVulkanDriver` (extends `OSSDL2Driver`)

**Purpose**: Subclass of `OSSDL2Driver` that intercepts window creation
to handle `PVWindowAttributes vulkanAttributes`. Overrides one method;
all other behaviour is inherited unchanged.

Existing code must register `PVVulkanDriver` explicitly by calling
`PVVulkanDriver install` before opening Vulkan windows. `uninstall`
restores the original driver.

Class-side methods:
- `install` — registers self as the active OSWindow driver:
  `OSWindowDriver setDefault: self new`.
- `uninstall` — restores `OSSDL2Driver new` as the active driver.

Overridden instance method:
- `createWindowWithAttributes: attributes osWindow: osWindow` — calls
  `super createWindowWithAttributes: attributes osWindow: osWindow`.
  Before the call, if `attributes` is a `PVWindowAttributes` and its
  `vulkanAttributes` is not nil, adds `SDL2Vulkan sdlWindowVulkan` to
  `flags` and substitutes `OSSDL2VulkanBackendWindow` for the backend
  window class. The override is confined to this one method; the rest
  of the driver is untouched.

---

#### Class: `OSSDL2VulkanBackendWindow` (extends `OSSDL2BackendWindow`)

**Purpose**: An SDL2 backend window that can create a Vulkan surface.

Key methods:
- `createVulkanSurface: aVkInstance_H` → `VkSurfaceKHR_H`.
  Calls `SDL2Vulkan createSurface:instance:surface:`.
- `vulkanDrawableExtent` → `Point`.
  Calls `SDL2Vulkan getDrawableSize:w:h:`.

---

### 6B. Graphics resources (`PharoVulkan-Graphics`)

#### Class: `VkSurface`

**Purpose**: Wraps `VkSurfaceKHR_H`. Created from an
`OSSDL2VulkanBackendWindow`. Owns the surface lifecycle.

Instance variables: `handle`, `instance` (VkInstance_H),
`physicalDevice` (VkPhysicalDevice).

Key methods:
- `queryCapabilities` → `VkSurfaceCapabilitiesKHR`.
- `queryFormats` → Array of `VkSurfaceFormatKHR`.
- `queryPresentModes` → Array of Integer.
- `supportsPresentation: queueFamilyIndex` → Boolean.
- `destroy`.

---

#### Class: `VkSwapchain`

**Purpose**: Wraps `VkSwapchainKHR_H`. Manages the image ring buffer for
display presentation.

Instance variables: `handle`, `device`, `surface`, `images`
(Array of VkImage_H), `imageViews` (Array of VkImageView_H),
`format`, `extent`.

Key methods:
- `create` — chooses format, present mode, extent; calls
  `vkCreateSwapchainKHR`.
- `acquireNextImage: semaphore` → image index.
- `present: imageIndex queue: aQueue waitSemaphore: semaphore`.
- `destroy`.

---

#### Class: `VkRenderPass`

**Purpose**: Wraps `VkRenderPass_H`. Defines attachments and subpasses.

Key method:
- `createColorDepthPass: device format: colorFormat` — creates a render
  pass with one color attachment (clear on load, store on end).

---

#### Class: `VkFramebuffer`

**Purpose**: Wraps `VkFramebuffer_H`. Binds image views to a render pass.

---

#### Class: `VkGraphicsPipeline`

**Purpose**: Wraps a graphics `VkPipeline_H`.

Instance variables: `handle`, `device`, `layout`, `renderPass`,
`vertexShader` (VkShaderModule), `fragmentShader` (VkShaderModule),
`vertexInputState`, `rasterizationState`, `colorBlendState`.

Key methods:
- `create` — calls `vkCreateGraphicsPipelines`.
- `destroy`.

---

#### Class: `PVGraphicsScene` (abstract)

**Purpose**: Base for GPU-rendered scenes. Subclasses implement `render:`.

Key methods:
- `prepare: aVkContext surface: aVkSurface` — allocates all GPU resources.
- `render: frameIndex` — records and submits a frame.
- `destroy` — frees GPU resources.

---

#### Class: `PVHelloTriangleScene` (extends `PVGraphicsScene`)

**Purpose**: Renders a single triangle with hardcoded vertex positions and
DSL-compiled vertex + fragment shaders.

Vertex shader (Pharo DSL):
```smalltalk
vertexMain: vi
    <gpuVertex>
    <param: #vertexInput type: #vec2f named: #position>
    <param: #vertexInput type: #vec3f named: #color>
    <output: #vec4f named: #gl_Position builtin: #position>
    <output: #vec3f named: #fragColor location: 0>
    gl_Position := position x, position y, 0.0, 1.0.
    fragColor := color
```

Fragment shader (Pharo DSL):
```smalltalk
fragmentMain: fi
    <gpuFragment>
    <input: #vec3f named: #fragColor location: 0>
    <output: #vec4f named: #outColor location: 0>
    outColor := fragColor x, fragColor y, fragColor z, 1.0
```

---

### Phase 6 tests

#### Class: `PVGraphicsTest` (extends `TestCase`, package `PharoVulkan-Tests-Graphics`)

- `testVulkanAttributesSetFlag` — create `OSWindowAttributes` with
  `vulkanAttributes`; verify `SDL_WINDOW_VULKAN` flag is set.
- `testSurfaceCreation` — create an `OSSDL2VulkanBackendWindow`; create
  a `VkSurface`; assert handle is not null. (Requires display.)
- `testSwapchainCreation` — create swapchain; assert image count >= 2.
- `testHelloTriangle` — create window, run `PVHelloTriangleScene`
  for one frame, assert no Vulkan validation errors. (Requires display.)

---

## Phase A — Compiler Completeness ✅ DONE

**Goal**: Close gaps in the Pharo→SPIR-V compiler so realistic compute kernels
compile end-to-end without hand-written SPIR-V.

**Packages**: `PharoVulkan-Compiler`, `PharoVulkan-Tests-Compiler`

**Done when**: 16/16 `PVCompilerTest` pass; `PVKernelExamples >> #vectorAdd:a:b:out:`
compiles to valid SPIR-V and runs on GPU via `PVComputeKernel fromMethod:on:`.

**Completed work**:

- `PVBytecodeDecoder`: added `doDup`, `methodReturnConstant:`, `blockReturnTop`,
  `blockReturnConstant:`, `pushReceiverVariable:`, `storeIntoReceiverVariable:`,
  `popIntoReceiverVariable:`.
- `PVStackSimulator`: refactored `simulateOp:` to dispatch table (`handlers`
  Dictionary); added `simulate:paramCount:` which pre-seeds param registers
  (indices 0..n-1 → regs 1..n) so type inferencer lookups always match.
- `PVSelectorTable`: added `x`/`y`/`z` on `#workItem`; `at:`/`at:put:` on
  `#bufferOf_f32` and `#bufferOf_i32`.
- `PVSPIRVEmitter`: added `compileComputeKernel:annotation:typeMap:selectorTable:`
  (class-side); `emitWorkItemComponent:op:block:`, `emitBufferLoad:typeMap:block:`,
  `emitBufferStore:typeMap:block:` (instance-side). Emits `OpVariable` globals for
  buffers (StorageClass=12 StorageBuffer) and WorkItem (StorageClass=1 Input, BuiltIn
  GlobalInvocationId=28). Entry point: `void main()` with GLCompute execution model (5)
  and LocalSize execution mode (17), LocalSize 64×1×1.
- `PVKernelCompiler`: auto-detects compute kernels (any param with type
  `#workItem`, `#bufferOf_f32`, or `#bufferOf_i32`) and routes to
  `PVSPIRVEmitter compileComputeKernel:…`.
- `PVKernelExamples >> #vectorAdd:a:b:out:`: 4-param compute kernel example.
- New tests: `testVectorAddKernelCompiles`, `testStackSimulatorParamCountPreseeds`,
  `testSelectorTableComputeMappings`, `testDecoderHandlesInstVarAndDup`.

---

## Phase B — GLSL-like Vector/Matrix DSL ✅ DONE

**Goal**: Add composite types to the compiler so vertex and fragment shaders
can be written in Pharo without hand-coded SPIR-V.

**Packages**: extend `PharoVulkan-Compiler`, extend `PharoVulkan-Tests-Compiler`

**Done when**: A Pharo method annotated with `<gpuVertex>` or `<gpuFragment>`
using `PVVec3`, `PVVec4`, `PVMat4` compiles to valid SPIR-V and renders
correctly in the Phase 6 hello-triangle scene.

**Delivered**: `PVVec2`, `PVVec3`, `PVVec4`, `PVMat4`; `<gpuVertex>` and
`<gpuFragment>` routing in `PVKernelCompiler`; `PVKernelExamples` shader pairs;
`PVGlslTriangleScene`, which renders from the compiled shaders rather than
hand-built SPIR-V. `PVSpirvValidatorTest >> testGlslTriVertex` and
`testGlslTriFragment` check both against `spirv-val`.

**Spec**:

New Pharo-side value types (thin wrappers, never instantiated at runtime —
used only as type tokens in the selector table and emitter):

| Class     | SPIR-V type               |
|-----------|---------------------------|
| `PVVec2`  | `vec2` (`OpTypeVector f32 2`) |
| `PVVec3`  | `vec3` (`OpTypeVector f32 3`) |
| `PVVec4`  | `vec4` (`OpTypeVector f32 4`) |
| `PVMat4`  | `mat4` (`OpTypeMatrix vec4 4`) |
| `PVBVec3` | `bvec3` (`OpTypeVector bool 3`) |

New `PVSelectorTable` mappings:

| Pharo selector         | Receiver type | SPIR-V |
|------------------------|---------------|--------|
| `x` / `y` / `z` / `w` | vec2/3/4      | `OpCompositeExtract` |
| `,`                    | f32           | begins `OpCompositeConstruct` accumulation |
| `+` / `-` / `*`        | vec3          | `OpFAdd` / `OpFSub` / `OpFMul` (component-wise) |
| `*`                    | mat4 × vec4   | `OpMatrixTimesVector` |
| `dot:`                 | vec3          | `OpDot` |
| `normalize`            | vec3          | `OpExtInst GLSL.std.450 Normalize` |
| `length`               | vec3          | `OpExtInst GLSL.std.450 Length` |
| `mix:factor:`          | vec3          | `OpExtInst GLSL.std.450 FMix` |
| `clamp:min:max:`       | f32           | `OpExtInst GLSL.std.450 FClamp` |
| `sqrt`                 | f32           | `OpExtInst GLSL.std.450 Sqrt` |

New pragma keywords for vertex/fragment entry points:
- `<gpuVertex>` — marks a vertex shader method.
- `<gpuFragment>` — marks a fragment shader method.
- `<param: #vertexInput type: #vec3f named: #color>` — vertex attribute input.
- `<param: #fragmentInput type: #vec3f named: #fragColor location: 0>` — interpolated input.
- `<output: #vec4f named: #gl_Position builtin: #position>` — built-in output.
- `<output: #vec3f named: #fragColor location: 0>` — user output.

`PVKernelCompiler` must detect `<gpuVertex>` / `<gpuFragment>` and route to a new
`PVSPIRVEmitter compileVertexShader:…` / `compileFragmentShader:…` class method.

New tests (add to `PVCompilerTest`):
- `testVec3DotCompiles` — compile a method that computes `a dot: b` on two `#vec3`
  params; assert valid SPIR-V bytes.
- `testNormalizeCompiles` — compile a method that calls `v normalize`; assert
  GLSL.std.450 import and `OpExtInst` in output.
- `testVertexShaderCompiles` — compile the hello-triangle vertex shader from Pharo
  source; assert SPIR-V magic and `OpEntryPoint` with execution model Vertex (0).
- `testFragmentShaderCompiles` — same for fragment shader.

---

## Phase C — High-Level Compute API ✅ DONE

**Goal**: Hide the 6-step Vulkan compute pipeline behind a clean Pharo façade.
Application code should not touch `VkBuffer`, `VkDescriptorPool`, etc. directly
for common cases.

**Packages**: `PharoVulkan-Core`, `PharoVulkan-Compute`, `PharoVulkan-Tests-Compute`

**Done when**: `PVComputeTest >> testVectorAddFromCompiledMethod` passes; it compiles
a Pharo kernel, allocates buffers, dispatches, and reads back results — all via the
high-level API.

**Completed work**:

- `VkBuffer class >> storageBufferUsage` — named constant (= 32,
  `VK_BUFFER_USAGE_STORAGE_BUFFER_BIT`). Replaces all inline `32` literals.
- `VkBuffer class >> storageBuffer: count on: aDevice` — factory: allocates
  `count` float32 slots as a storage buffer.
- `VkBuffer >> putF32s: aFloatCollection` — converts a Pharo float collection to
  IEEE 32-bit little-endian bytes and writes to device memory.
- `VkBuffer >> getF32s` — reads device memory and converts back to a Pharo
  `Array` of `Float`.
- `PVComputeKernel class >> fromMethod: aCompiledMethod on: aContext` — compiles
  the method to SPIR-V via `PVKernelCompiler` then calls `on:spirv:`.
- `PVComputeTest >> testVectorAddFromCompiledMethod` — end-to-end test using the
  high-level API.

---

## Phase 6.5 — Housekeeping and Foundation Strengthening ✅ DONE

These tasks were identified after Phase 6B (GLSL DSL) as high-value, low-risk
improvements to do before entering the open-ended Phase 7.

### 6.5-A  spirv-val integration (confidence) ✅ DONE

Pipe every compiled SPIR-V `ByteArray` through the `spirv-val` CLI tool in
a dedicated test. Currently tests only check the 4-byte magic header — a
malformed module would pass. `spirv-val` catches bad IDs, missing decorations,
wrong instruction ordering, and structural violations.

- Write `PVSpirvValidatorTest` that compiles each `PVKernelExamples` method
  and shells out to `spirv-val --target-env vulkan1.3`.
- Mark the test as skipped (not failed) when `spirv-val` is absent so the CI
  does not break on minimal installs.
- Fix any validation errors found.

**Delivered**: `PVSpirvValidatorTest`, 5 tests, each skipping via
`spirvValAvailable` when the tool is missing. No validation errors were found.
It validates 5 of the 19 kernel examples by design, not by omission: the other
14 are scalar `<gpu>` methods, which compile to SPIR-V functions with no
`OpEntryPoint`, so standalone `spirv-val` must reject them. Do not chase 19/19.
Open defect: `spirvValExecutable` hardcodes `/usr/bin/spirv-val`, so a
`spirv-val` elsewhere on `PATH` still silently skips every test.

### 6.5-B  Parametric vertex input layout (flexibility) ✅ DONE

`VkGraphicsPipeline` hardcodes stride 20 (vec2 position + vec3 color).
Any custom shader with a different vertex layout must subclass and re-implement
the full pipeline creation.

- Extract the vertex binding and attribute descriptions into overridable
  methods: `vertexBindingDescriptions` and `vertexAttributeDescriptions`.
- Keep the existing default (stride 20, location 0 = vec2, location 1 = vec3)
  so all current tests and scenes pass unchanged.

**Delivered**: `VkGraphicsPipeline >> vertexBindingDescriptions` and
`vertexAttributeDescriptions`, read by the pipeline creation method. The stride-20
default is unchanged, so a custom layout is now an override rather than a rewrite.

### 6.5-C  Control flow in fragment/vertex shaders (expressiveness) ✅ DONE

Selection (`ifTrue:ifFalse:`) and loops are currently only compiled in compute
kernels (`<gpu>`). The compiler routes `<gpuVertex>` and `<gpuFragment>` to the
straight-line emitter regardless of CFG shape.

- Route vertex/fragment shaders through `PVStructuredCFGRecognizer` the same
  way compute kernels with control flow are handled.
- Add a `PVKernelExamples >> alphaClip: color threshold: t` fragment example
  that uses `ifTrue:ifFalse:` to discard fragments below a threshold.
- Add a corresponding `PVCompilerTest >> testAlphaClipFragmentCompiles` test.

**Delivered**: all three. `PVKernelCompiler` runs `PVStructuredCFGRecognizer` for
`<gpuVertex>` and `<gpuFragment>` as well, signalling
`'Unrecognized CFG shape in vertex shader'` or `'… in fragment shader'` when the
shape is refused. The recogniser's limit applies here too: exactly one
`ifTrue:ifFalse:` or one `whileTrue:` per shader, nesting and sequence both
refused — see `CFG-PLAN.md` and `PVCfgShapeFixture`.

---

## Phase 7 — Cooperative Matrix + Performance

**Goal**: AI-grade matmul using `VK_KHR_cooperative_matrix`, float16,
subgroup reductions.

**Packages**: extend `PharoVulkan-Compute`, extend `PharoVulkan-Compiler`

**Done when** (rewritten 10 October 2026, after the device probe of 7-A; the
original wording is kept below it): device capabilities are queried and
reported; compute kernels support one control-flow construct; a float32 matmul
produces correct output and a benchmark number; a float16 matmul produces
correct output and is benchmarked against it; a subgroup reduction produces
correct output; cooperative matrix support is queried per device, the hardware
device here is skipped with a stated reason because it lacks the extension, and
the cooperative matrix path runs for correctness on the one device that does
offer it.

Original wording, not deliverable on this machine: *cooperative matmul produces
correct output and benchmarks show speedup over Phase 5 scalar matmul.* The
hardware device here, an Intel Iris Plus (ICL GT2), reports no
`VK_KHR_cooperative_matrix` and no `VK_NV_cooperative_matrix`, and it has no
matrix unit, so no speedup claim could be honest even if a path existed.

Minimum spec, with what was delivered:
- ✅ Query `VK_KHR_cooperative_matrix` support; skip on devices that lack it.
  `VkPhysicalDevice >> supportsCooperativeMatrix`, `VkContext >>
  cooperativeMatrixAvailable` and `PVCooperativeMatrixSurvey`, which surveys
  every device the loader offers and states the reason for the skip.
- ✅ Add the cooperative matrix types to `PVSelectorTable` (7-H, 10 October 2026).
  Mesa's `lavapipe` (`llvmpipe`) on this machine reports the extension, so the
  correctness-only target was taken. The operand role rides on the parameter
  type — `#matrixABufferOf_f16`, `#matrixBBufferOf_f16`,
  `#accumulatorBufferOf_f32` — because one cooperative matrix type is fixed to
  one role in SPIR-V, so a load of the A factor and a load of the B factor are
  different types and cannot share one mapping.
- ✅ Add `coopMatLoad:`, `coopMatStore:`, `coopMatMulAdd:` selectors (7-H).
  `PVKernelExamples >> coopMatrixProductOf:by:into:` is the kernel in Pharo
  source; it validates under spirv-val, runs on lavapipe, and matches both the
  CPU reference and the hand-built module. `PVCooperativeMatrix` and two
  extension methods on `SequenceableCollection` give the same three selectors an
  honest meaning in the image, so the kernel body is runnable Pharo and not a
  set of markers for the compiler.
- ⏸ Benchmark 512×512 float16 matmul against the scalar baseline — the float16
  matmul is benchmarked against float32 in 7-D (1.0 to 1.1, not the expected
  1.5 to 2), but not through cooperative matrix. The only device here offering
  cooperative matrix is a CPU implementation, and its fixed configurations are
  all M8 N8 K8, so a 512×512 figure from it would measure llvmpipe rather than a
  matrix unit.

See `PHASE7-PLAN.md` §7-F for the device survey and §7-H for the cooperative
matrix work it opened.

Beyond the minimum spec, 7-G delivered the tiled matmul with shared memory
(10 October 2026). The emitter gained the `Workgroup` storage class, fixed-length
array types and `OpControlBarrier`; the DSL gained `<shared: #f32 named: #tile
count: n>`, `wi localX/localY/localZ` and `wi barrier`; and the recogniser gained
exactly one nesting pattern, an outer loop whose body is an inner loop
(`PVNestedLoopNode`). At N = 512 on the Intel Iris Plus the tiled kernel runs
7.5 ms against 34.8 ms for the naive baseline — **4.6× faster** — and the kernel
written in Pharo source matches the hand-built module to the millisecond and to
the last bit of output, so going through the DSL costs 1.0.

7-H then closed the cooperative matrix path for correctness (10 October 2026).
`VkContext class >> cooperativeMatrixContext` selects a device by capability
rather than by position; `VkPhysicalDeviceCooperativeMatrixFeaturesKHR` and
`VkPhysicalDeviceVulkanMemoryModelFeatures` are enabled together, because
spirv-val refuses `CooperativeMatrixKHR` in a Shader module without
`VulkanMemoryModel`; the reported configurations are read rather than assumed,
and the kernel uses the f16 × f16 + f32 → f32 one at M8 N8 K8 subgroup scope
that lavapipe offers. The emitter gained `SpvCooperativeMatrixShape`,
`SpvCooperativeMatrixType` and the load, store and mul-add instructions. One
dispatch each: 2 ms hand-built, 3 ms compiled, both 6.7e-4 from the float
reference and identical to each other. Those numbers show only that the kernel
runs; the device is a CPU implementation, so the 4.6× from 7-G on real hardware
remains this project's only speedup claim.

---

## Key algorithms reference

### Braun et al. SSA construction (Stage ⑤)

Source: M. Braun, S. Buchwald, S. Hack, R. Leißa, C. Mallon, A. Zwinkau,
"Simple and Efficient Construction of Static Single Assignment Form",
CC 2013.

The algorithm maintains two maps:
- `currentDef[variable][block]` → current SSA value.
- `incompletePhis[block]` → phis awaiting operand filling.

```
writeVariable(var, block, value):
    currentDef[var][block] := value

readVariable(var, block):
    if currentDef[var][block] exists:
        return currentDef[var][block]
    return readVariableRecursive(var, block)

readVariableRecursive(var, block):
    if block not yet sealed:
        val := new incomplete phi in block
        incompletePhis[block][var] := val
    elif block has one predecessor:
        val := readVariable(var, predecessor)
    else:
        val := new phi in block
        writeVariable(var, block, val)   "break cycles"
        val := addPhiOperands(var, val)
    writeVariable(var, block, val)
    return val

addPhiOperands(var, phi):
    for each predecessor of phi.block:
        phi.addOperand(readVariable(var, predecessor))
    return tryRemoveTrivialPhi(phi)

tryRemoveTrivialPhi(phi):
    "A phi is trivial if all operands are the same value or the phi itself."
    ...
```

### SPIR-V structured control flow

SPIR-V requires structured control flow: every loop and selection must be
preceded by a merge instruction.

For a selection (`ifTrue:ifFalse:`):
```
<header block>
    OpSelectionMerge %merge None
    OpBranchConditional %cond %thenBlock %elseBlock
<then block>
    ...
    OpBranch %merge
<else block>
    ...
    OpBranch %merge
<merge block>
    ...
```

For a loop (`to:do:`, `whileTrue:`):
```
<pre-header block>
    OpBranch %header
<header block>
    OpLoopMerge %merge %continue None
    OpBranchConditional %cond %body %merge
<body block>
    ...
    OpBranch %continue
<continue block>
    ...increment...
    OpBranch %header
<merge block>
    ...
```

### SPIR-V binary encoding

Magic: `0x07230203`
Version 1.5: `0x00010500`

Instruction encoding:
```
word0 = (wordCount << 16) | opcode
word1 = resultType id  (if instruction has a type)
word2 = result id      (if instruction has a result)
word3..N = operands
```

String literals are null-terminated, padded to 4-byte alignment, packed
as words. Each character is one byte; padding bytes are 0x00.

Storage class constants — expose via `SpvStorageClass class` methods:
- `uniformConstant` = 0
- `input` = 1
- `uniform` = 2
- `output` = 3
- `workgroup` = 4
- `storageBuffer` = 12

Execution model constants — expose via `SpvExecutionModel class` methods:
- `vertex` = 0
- `fragment` = 4
- `glCompute` = 5

Built-in variable constants — expose via `SpvBuiltIn class` methods:
- `position` = 0
- `vertexIndex` = 42
- `globalInvocationId` = 28
- `localInvocationId` = 27
- `workgroupId` = 26

These classes are thin SharedPool-style constant holders generated from
`spirv.core.grammar.json` by `SpvBuilderGenerator`. No raw integers
appear anywhere in emitter or builder code.
