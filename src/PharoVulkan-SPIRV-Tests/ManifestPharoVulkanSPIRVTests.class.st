"
Tests for PharoVulkan-SPIRV: that the builder emits the word stream the specification describes.

`SpvBuilderTest` covers the builder, the type registry and the constant pool; `SpvEmitterTest` covers the module emitter and the serialiser, where the words become bytes. A module these tests build is handed to `spirv-val` wherever the tool is installed, and the test skips rather than fails when it is not, so a machine without the SPIR-V tools still runs the suite honestly.

No test here touches Vulkan. SPIR-V is bytes, and bytes can be checked without a driver.
"
Class {
	#name : 'ManifestPharoVulkanSPIRVTests',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-SPIRV-Tests-Manifest',
	#package : 'PharoVulkan-SPIRV-Tests',
	#tag : 'Manifest'
}
