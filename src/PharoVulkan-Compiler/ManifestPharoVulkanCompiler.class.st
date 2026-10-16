"
Compiles a Pharo method into SPIR-V. `PVKernelCompiler compile:` is the front door: it decodes the method's Sista bytecode, turns the stack machine into a register IR, builds a control flow graph, recognises the loop and selection shapes the Pharo compiler produces, puts the registers into SSA form and hands the result to `PVSPIRVEmitter`, which writes the module through `PharoVulkan-SPIRV`. Nothing here talks to a driver: the package answers bytes, and `PharoVulkan-Compute` and `PharoVulkan-Graphics` are what load them onto a device.

The tags follow the stages. `Pipeline` holds the eight stage classes, in the order they run: `PVBytecodeDecoder`, `PVStackSimulator`, `PVCFGBuilder`, `PVStructuredCFGRecognizer`, `PVSSAConstructor`, `PVTypeInferencer`, `PVSPIRVEmitter` and the `PVKernelCompiler` that drives them. `Bytecode` and `SSA` hold what the early stages pass between them, `Graph` the control flow graph and the loop and selection nodes a recogniser answers, `Annotations` the three pragma readers that carry a kernel's declared parameter and output types, `Selectors` the table mapping a Pharo message send to a SPIR-V operation, `Types` the host-side type tokens and `PVWorkItem` — a kernel method runs on the host against these to produce the reference result a device run is compared against — and `Validation` the wrapper around the `spirv-val` command-line tool.

The package depends on `PharoVulkan-SPIRV` alone. It may not reference a driver class or a kernel: the one edge into `PharoVulkan-Compute` was the cooperative matrix order, which decision D3 moved down to `SpvCooperativeMatrixShape class >> canonicalOrder`.
"
Class {
	#name : 'ManifestPharoVulkanCompiler',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Compiler-Manifest',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Manifest'
}
