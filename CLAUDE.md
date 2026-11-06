# PharoVulkan — CLAUDE.md

## Project overview

PharoVulkan is a Vulkan binding and DSL for Pharo Smalltalk. It has two goals:
(1) expose the full Vulkan API via uFFI with no third-party Pharo packages, and
(2) provide a DSL that compiles Pharo methods to SPIR-V, targeting both compute
(AI/ML) and graphics workloads. SDL2 surface creation extends OSWindow via the
existing `OSSDL2BackendWindow` infrastructure.

## Current state

Phases 1 to 7, the graphics items G-0 to G-6, `DEFECTS-PLAN.md`, `LAYOUT-PLAN.md` and
`PACKAGE-PLAN.md` are all done. The suite is 647 tests over eleven test classes and passes.
`doc/REVIEW-PLAN.md` holds the architecture and code review, and says which of its points are done.
`prompt.md` holds the original phase specs; `PACKAGE-PLAN.md` holds the package split and the
rules it set.

## Package layout

Sixteen packages: nine of code, seven of tests. Source layout `src/<PackageName>/` in Tonel
format. Iceberg manages commits of `src/` — do not use git directly for it.

| Package | Classes | Purpose |
|---|---|---|
| `PharoVulkan-Bindings` | 144 | Generated Vulkan uFFI bindings: commands, structures, handles, the named constant classes (tag `Constants`), `VkResult` and `VkError` |
| `PharoVulkan-SPIRV` | 51 | SPIR-V binary builder: module, builder, IR, types, constant pool, serialiser, validator, `PVTypeError` |
| `PharoVulkan-Compiler` | 27 | Pharo bytecode → SPIR-V in seven stages (tag `Pipeline`), the DSL selector table, and the `spirv-val` wrapper |
| `PharoVulkan-Core` | 17 | Vulkan lifecycle: instance, physical device, device, queue, buffer, memory, command pool and buffer, shader module, pipeline layout |
| `PharoVulkan-Compute` | 17 | Compute path: descriptor layout and pool, compute pipeline, kernel runner, cooperative matrix, benchmarks, and the two abstract superclasses of the hand-built kernels (`PVSpirvKernel`) and of the runs that allocate their buffers around a dispatch (`PVDeviceRun`) |
| `PharoVulkan-Graphics` | 17 | Graphics path: surface, swapchain, render pass, framebuffer, graphics pipeline, offscreen targets, scenes, and the SDL2 integration (tag `SDL2`) |
| `PharoVulkan-Generator` | 13 | Reads `vk.xml` and `spirv.core.grammar.json` and emits binding classes. Dev time only, outside `default` |
| `PharoVulkan-Examples` | 19 | One `<Subject>Examples` class per subject, holding the `<sampleInstance>` examples the inspector views and the tests read |
| `PharoVulkan-Inspector` | 1 | `PVFactRow`, one line of the two-column fact table every inspector view of this project shows, and the one declaration of that table. Depends on nothing, so every other package may require it |

| Test package | Test classes | Fixtures |
|---|---|---|
| `PharoVulkan-Bindings-Tests` | `VkBindingsTest` (286) | — |
| `PharoVulkan-SPIRV-Tests` | `SpvBuilderTest` (24), `SpvEmitterTest` (2) | — |
| `PharoVulkan-Compiler-Tests` | `PVCompilerTest` (83), `PVSpirvValidatorTest` (33) | `PVCfgShapeFixture`, `PVMissingToolValidatorStub` |
| `PharoVulkan-Core-Tests` | `VkCoreTest` (68) | `PVQueueFamilyStub` |
| `PharoVulkan-Compute-Tests` | `PVComputeTest` (63) | `PVNoSubgroupArithmeticStub` |
| `PharoVulkan-Graphics-Tests` | `PVGraphicsTest` (53), `VkImageTest` (8) | `PVFailingTriangleSceneStub`, `PVRecordingContextStub` |
| `PharoVulkan-Tests` | `PVArchitectureTest` (22), `PVFactRowTest` (5) | `PVNestedBlockReferenceFixture` |

A test package is named for the package it covers and ends in `-Tests`, which is what Pharo's
tools and Renraku's `ReTestClassNotInPackageWithTestEndingNameRule` expect. Its `Tests` tag holds
test classes and its `Fixtures` tag holds the stubs those tests build.

### Which package may depend on which

This file does not say. `PVArchitectureTest class >> allowedDependencies` does, with one entry per
package, and twenty-one tests hold both the code and the baseline to it: sixteen read each package's
own methods — `package methods`, so extension methods on base classes are read too — four check
the table against the organiser, against what the code really references and against
`BaselineOfPharoVulkan`, and one proves the scan finds a reference planted inside three nested
blocks. Adding a dependency means stating it in the table and in the baseline, in the commit that
needs it; adding a package means giving it an entry, or the meta test fails.

The baseline's groups: `bindings`, `spirv`, `compiler` (SPIR-V and compiler, no driver code, so it
loads on a machine with no `libvulkan.so.1`), `core`, `compute`, `graphics`, `default` (Bindings,
Core, Compute and Graphics), `generator`, `examples` and `tests`. `PharoVulkan-Inspector` is in no
group of its own: the packages that build rows require it, so every group that loads one loads it.

## Working on a phase

1. Read `prompt.md` for the target phase spec before writing any code.
2. Use the Pharo MCP tools to create and verify classes in the live image.
3. Write tests first; a phase is done when its tests pass.
4. Do not start the next phase until the current one is fully testable.
5. Keep generated code in `PharoVulkan-Bindings` and `PharoVulkan-SPIRV`
   separate from hand-written code — regeneration must not destroy edits.

## MCP usage

Use `mcp__pharo__evaluate_pharo` to:
- Create classes: `Object subclass: #Foo instanceVariableNames: '...' ...`
- Add methods: `Foo extend [ myMethod [ ... ] ]` or direct method definition
- Run tests: `TestRunner runClass: FooTest`
- Inspect results: evaluate any expression and inspect the result string

Use `mcp__pharo__list_classes` to check what already exists before creating.
Use `mcp__pharo__list_methods` to inspect existing method lists.
Use `mcp__pharo__method_source` to read existing method source.
Use `mcp__pharo__class_definition` to read existing class definitions.

Always verify class creation succeeded by listing classes afterward.

## Coding conventions

These are hard constraints — not suggestions.

- **Idiomatic Pharo Smalltalk.** No Java-style getter/setter pairs; use direct
  accessors. Prefer message sends over conditionals where natural.
- **CR-only line endings in all Pharo source.** LF is forbidden. Every string
  literal that embeds a newline must use `Character cr` or `String cr`. When
  writing method source passed to `compile:classified:` via the MCP tool, use
  `\r` (CR, ASCII 13) as the line separator in the JSON string — NOT `\n` (LF).
  In practice: write multi-line method bodies with `\r` between lines when
  calling `compile:classified:`.
- **Every class has a class comment.** One paragraph: purpose + key methods.
  Write it via the `comment:` class-side message or the class definition.
- **No WHAT comments.** Only WHY comments for non-obvious invariants,
  constraints, or workarounds. Well-named identifiers are self-documenting.
- **All public API covered by tests.** Use SUnit (`TestCase` subclass). One
  test class per package, in that package's `-Tests` package, named for what it
  covers (`VkBindingsTest`, `SpvBuilderTest`).
  Example classes (`*Example`) are acceptable additions but not substitutes.
- **No magic values.** Every numeric or string constant that carries meaning
  must be declared as a named class-side method or a pool constant — never
  written inline. Examples:
  - Wrong: `flags := flags | 16r10000000`
  - Right: `flags := flags | self sdlWindowVulkan`
  - Wrong: `header nextPutAll: #[3 2 35 7]`
  - Right: `header nextPutAll: SpvModule magic`
  This applies to opcodes, bitmasks, enum values, SPIR-V word counts,
  Vulkan structure types, and layout binding indices.
- **Phased discipline.** Each phase must be independently runnable and testable.
  Do not introduce classes from Phase N+1 into Phase N.
- **No modifications to existing Pharo code.** Never edit a method or class
  defined outside this project. Two legitimate extension mechanisms exist:
  - **Class extension methods**: add new methods to an existing class by
    defining them inside a `PharoVulkan-*` package. In Pharo/Iceberg these
    appear with a `*pharovulkan-*` protocol tag. Use this for adding
    accessors or hooks that existing classes do not have.
  - **Subclassing**: when overriding existing behaviour (e.g. a driver
    method), subclass the existing class and register the subclass.
    Never patch or wrap the original method.
  Every extension method must carry a comment naming the target class and
  the reason the extension is here rather than upstream.
  When in doubt, subclass over extending.
- **No third-party Pharo packages.** System libraries (`libvulkan.so.1`,
  `libSDL2.so`) are acceptable. Pharo packages from external repositories
  are not.

## Key design decisions (frozen)

These were decided in the design notes and must not be revisited without
updating this file.

| Decision | Choice | Reason |
|---|---|---|
| Type annotations | Pragmas: `<gpu>`, `<param: #f32 named: #x>` | Minimal syntax, parsed at compile time |
| `globalId` access | `WorkItem` object passed as method parameter | Clean OOP, no pseudo-globals |
| Sync API | `VK_KHR_synchronization2` only | No legacy sync primitives |
| SSA algorithm | None. `PVSPIRVEmitter` saves and restores its register map at a merge point and writes `OpPhi` itself | The Braun et al. stage of `prompt.md` and `design-notes.md` was an identity function that nothing read; removed 2026-11-06 |
| CFG structuring | Pattern recognizer (not general) | Pharo compiler is sole producer |
| DSL scope | Monomorphic calls only, Phase 1–6 | Eliminates devirtualization |

## SPIR-V binary format

SPIR-V is a little-endian stream of 32-bit words.

Header (5 words):
```
0x07230203   magic
version      0x00010500 = 1.5
generator    0x00000000 (custom)
bound        highest result id + 1
schema       0
```

Instruction encoding: `[(wordCount << 16) | opcode]` then operands.
All types, constants, and decorations must appear before functions.
`spirv-val` must pass on every emitted module — treat failures as compiler bugs.

## Vulkan init sequence (compute, minimal)

```
vkCreateInstance
  → vkEnumeratePhysicalDevices → pick first with compute queue
  → vkGetPhysicalDeviceQueueFamilyProperties → find compute queue family
  → vkCreateDevice (with compute queue)
  → vkGetDeviceQueue
  → vkCreateCommandPool
  → vkCreateDescriptorPool
  → [allocate buffers, map memory, fill data]
  → vkCreateShaderModule (SPIR-V bytes)
  → vkCreateDescriptorSetLayout → vkCreatePipelineLayout → vkCreateComputePipeline
  → vkAllocateDescriptorSets → vkUpdateDescriptorSets
  → vkAllocateCommandBuffers → record (bind pipeline, bind sets, dispatch)
  → vkQueueSubmit2KHR (synchronization2)
  → vkQueueWaitIdle
  → [map result buffer, read back]
  → destroy everything in reverse order
```

## SDL2 Vulkan surface (graphics path, Phase 6)

SDL2 >= 2.0.6 exposes `SDL_Vulkan_*` functions. These are NOT in Pharo's
existing SDL2 bindings and are declared via uFFI in the `SDL2` tag of
`PharoVulkan-Graphics`, which is where the one window this project opens is built.

The integration point is `OSSDL2Driver >> createWindowWithAttributes:osWindow:`.
When `attributes vulkanAttributes` is not nil, add `SDL_WINDOW_VULKAN` to the
flags before calling `SDL2 createWindow:...`. Return an
`OSSDL2VulkanBackendWindow` instead of `OSSDL2BackendWindow`.

`SDL_WINDOW_VULKAN` value: `0x10000000`. Expose as `SDL2Vulkan class >> sdlWindowVulkan`.
