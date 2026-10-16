"
Compute dispatch: everything between a kernel and the numbers it answers.

PVComputeKernel is the runner — it compiles a Pharo method carrying <gpu> to SPIR-V through PharoVulkan-Compiler, builds a VkComputePipeline over a descriptor set layout, dispatches on a device from PharoVulkan-Core and reads the result buffers back. The Descriptors and Pipeline tags hold the Vulkan objects that path needs: a pool, the sets allocated from it, the layout a shader names its bindings through, and the pipeline layout both this package and the graphics pipeline build on.

The Kernels tag holds the kernel sources themselves. PVKernelExamples is a library of annotated methods rather than a set of examples, which is what decision D4 of PACKAGE-PLAN.md concluded: benchmarks, comparisons and the graphics shaders all compile methods out of it. PVTiledMatmulKernel and PVCooperativeMatrixKernel build their modules instruction by instruction, which is how a compiled module is checked against one written by hand.

Benchmarks and CooperativeMatrix hold the runs that report: timings per precision and per kernel, the tiled matmul against the naive one, the subgroup reduction against the host sum, and the cooperative matrix product run both from a hand-built module and from a compiled one. A run of any of them needs a device, so none of them is a unit test.

This package reaches down to the bindings, the constants, PharoVulkan-Core and the compiler, and nothing reaches it but PharoVulkan-Graphics, the examples and the tests.
"
Class {
	#name : 'ManifestPharoVulkanCompute',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Compute-Manifest',
	#package : 'PharoVulkan-Compute',
	#tag : 'Manifest'
}
