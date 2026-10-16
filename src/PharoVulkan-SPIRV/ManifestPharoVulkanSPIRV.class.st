"
Builds SPIR-V modules and writes them as binary. Everything here is about the SPIR-V specification alone: it names no Vulkan structure, calls no driver and reads nothing of the image's own compiler, which is why the package depends on no other package in this project.

`SpvBuilder` is the front door — a module, its constant pool, its type registry and its functions are built through it, and `SpvModuleEmitter` and `SpvSerializer` turn what was built into words. `SpvType` and its subclasses are the type lattice; the `SpvIR*` classes are the intermediate form the Pharo compiler lowers into before any of this is reached; the remaining classes are the specification's own enumerations, one class per set of values (`SpvOpcode`, `SpvStorageClass`, `SpvDecoration`, `SpvBuiltIn`, `GlslStd450` and the rest), so that no caller writes a raw word.

`SpvValidator` reads a built module back and raises `SpvValidationError`, which lives here because this is the only package that signals it.

`PVTypeError` lives here too, for a reason worth stating: it is an empty signal raised both by the bindings reading a buffer as an element type it does not know and by the compiler inferring a type it cannot emit. Those two are in different layers, and SPIR-V types are the only thing below both of them, so the signal belongs here rather than in whichever layer happened to raise it first.
"
Class {
	#name : 'ManifestPharoVulkanSPIRV',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-SPIRV-Manifest',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Manifest'
}
