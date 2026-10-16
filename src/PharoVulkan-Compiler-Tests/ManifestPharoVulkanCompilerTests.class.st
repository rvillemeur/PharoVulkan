"
Tests for PharoVulkan-Compiler: that a Pharo method annotated for the GPU compiles to a module the validator accepts, and that the stages refuse what they cannot compile.

`PVCompilerTest` walks the pipeline stage by stage — bytecode, SSA, control flow, type inference, emission — and `PVSpirvValidatorTest` covers the wrapper around `spirv-val` itself, including the case where the tool is missing, which `PVMissingToolValidatorStub` stands in for.

`PVCfgShapeFixture` is the boundary of `PVStructuredCFGRecognizer` written down as kernels: one method per control-flow shape, each with a known verdict. Nobody runs them for their results. They live here rather than in the examples because a shape that must be refused is not an example of anything, and `PharoVulkan-Tests-Compute` reads two of them to run the shapes it does accept on a device.
"
Class {
	#name : 'ManifestPharoVulkanCompilerTests',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Compiler-Tests-Manifest',
	#package : 'PharoVulkan-Compiler-Tests',
	#tag : 'Manifest'
}
