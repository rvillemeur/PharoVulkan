"
The Vulkan API as this image declares it: every uFFI structure, handle, enumeration and foreign call that the layers above are written against.

The package holds four kinds of thing. The `Bindings` tag holds the declared structures, one `VkStructure` subclass per Vulkan structure, the handle classes, and `Vk`, the class on which every foreign call to `libvulkan.so.1` is declared. The `Constants` tag holds the enumerations and the project's own render configuration, `VkRenderConfig`, which names the choices this project makes where Vulkan offers several. The `Exceptions` tag holds `VkError`, raised wherever a driver answers a result code that is not success.

Nothing here reaches any other PharoVulkan package: the bindings are the bottom of the stack, and `VkBindingsTest >> testNoBindingReachesAnotherPharoVulkanPackage` states that fact. A structure therefore reports itself through its own accessors and through the constant classes, and asks `VkRenderConfig` for a policy constant rather than asking a lifecycle class above it.

A structure declares its fields field by field, never an array field, because uFFI in this image cannot declare one; where a field points at a run of values, the structure that declares the pointer also names the stride of an entry. Nothing is written in `initialize`, because a struct-pointer getter runs `fromHandle:`; a structure that must set constant fields does so in `initializeConstantFields`.

The generator writes the structures, handles and enumerations from `vk.xml` into this package. A generated class is never edited here by hand unless the generator is taught the same change.
"
Class {
	#name : 'ManifestPharoVulkanBindings',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Bindings-Manifest',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Manifest'
}
