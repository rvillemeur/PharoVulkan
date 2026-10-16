"
The Vulkan objects every path needs, compute or graphics: the instance, the physical device, the logical device and its queue, command pools and command buffers, fences and semaphores, device memory buffers and shader modules. `VkContext computeContextForExtensions:` and `graphicsContextForExtensions:` are the front doors — a context owns the instance, picks a physical device and a queue family, creates the device and retrieves the queue.

The tags say what a class is for. `Device` holds the context, the two device classes and `VkExtensionCommand`, which reaches a command the loader does not export as a symbol through `vkGetInstanceProcAddr`. `Commands` holds the queue, the pool, the buffer that records a submission and the two synchronisation wrappers. `Resources` holds `VkBuffer`, `VkShaderModule` and the `PVFloat16` codec a half-precision storage buffer is read and written through. `CooperativeMatrix` holds what a device reports for VK_KHR_cooperative_matrix: the survey over every physical device, one reported shape, and the two Vulkan enumerations naming a component type and a scope — the SPIR-V enumerations of the same names carry different values and live in `PharoVulkan-SPIRV`.

The package sits on `PharoVulkan-Bindings` and raises `PVTypeError` from `PharoVulkan-SPIRV` when a buffer is read as a type it was not written as. It may not reference a descriptor pool, a pipeline or a kernel: those belong to the compute and graphics packages above it. Decision D2 removed the one edge of that kind, a dead `VkDevice` method that answered a `VkDescriptorPool`.
"
Class {
	#name : 'ManifestPharoVulkanCore',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Core-Manifest',
	#package : 'PharoVulkan-Core',
	#tag : 'Manifest'
}
