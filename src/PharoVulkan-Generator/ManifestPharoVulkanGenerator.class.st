"
Reads the two specifications this project is generated from and emits Pharo code from them: `vk.xml` for the Vulkan bindings, and `spirv.core.grammar.json` for the SPIR-V builder.

The `Vulkan` tag holds the XML reader — `PVXmlParser` and `PVXmlElement` are a small parser written here rather than taken from a third-party package — the descriptors it answers (`VkTypeDescriptor`, `VkMemberDescriptor`, `VkCommandDescriptor`, `VkParamDescriptor`, `VkEnumDescriptor`), and `VkBindingGenerator`, which turns a descriptor into an installed class. The `SPIRV` tag holds `SpvGrammarParser` with its two descriptors and `SpvBuilderGenerator`.

Nothing in the project depends on this package: it writes the bindings and the builder, and the code it writes is then edited by hand and committed, so the generator is a tool rather than a layer. It is the one package the default load group leaves out. It depends on `Bindings` for the superclasses it installs under (`VkHandle`, `VkStructure`) and on `SPIRV` for `SpvBuilder`.

A generated class is never regenerated over an edited one: every generate method answers early when the class already exists in the target environment, which is what `VkBindingsTest >> testGeneratorIsIdempotent` pins.
"
Class {
	#name : 'ManifestPharoVulkanGenerator',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Generator-Manifest',
	#package : 'PharoVulkan-Generator',
	#tag : 'Manifest'
}
