"
Rendering: a render pass, a graphics pipeline, the targets they draw into and the window that shows the result.

The Pipeline tag holds the two objects a draw needs declared up front — VkRenderPass, which says what the attachments are and what happens to them, and VkGraphicsPipeline, which fixes every stage of the fixed-function state. Presentation holds VkSurface and VkSwapchain, the pair that turns a window into images the device can render into and the queue can present. Targets holds what is drawn into when there is no window: VkImage, VkFramebuffer and PVOffscreenTarget, which is how a scene renders to a Form in a headless image.

Scenes are runnable: each one builds a context, a render pass, a pipeline and a target, draws one frame and tears everything down in reverse. PVTriangleScene declares that sequence and its three subclasses vary one step of it — a window, an offscreen target, or shaders compiled from Pharo rather than written as SPIR-V by hand. PVGlslTriangleShaders answers the two modules the GLSL path uses, which it compiles out of the kernel source library in PharoVulkan-Compute.

The SDL2 tag is the window. SDL2 2.0.6 and later expose SDL_Vulkan_CreateSurface and SDL_Vulkan_GetInstanceExtensions, which Pharo's own SDL2 bindings do not declare, so SDL2Vulkan declares them; the other four classes are subclasses of the OSWindow and SDL2 driver classes, because this project extends that driver rather than patching it. Five classes are too few to be a package of their own when the only window they open is this one's, so they stay a tag here.

This package sits above everything but the generator and the examples. It is the only package that reaches PharoVulkan-Compute, and it does so for the kernel sources the GLSL shaders compile.
"
Class {
	#name : 'ManifestPharoVulkanGraphics',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Graphics-Manifest',
	#package : 'PharoVulkan-Graphics',
	#tag : 'Manifest'
}
