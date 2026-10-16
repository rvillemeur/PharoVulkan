"
Tests for PharoVulkan-Bindings: that a declared structure writes the bytes Vulkan says it writes, and that the bottom of the stack stays the bottom.

`VkBindingsTest` is one test class for one package, as the convention asks, and it is large because the package is: a structure is covered by asking it for a field it has just been given and by measuring the span its writers touch, which is how this project found the eight-byte overrun that used to crash the image. Two of its tests state architecture rather than behaviour: no class of the bindings may reach another PharoVulkan package, and the generator must install into a package that exists.

A test here never opens a device. Everything it needs is a structure it fills itself, so the class runs with no driver and no window.
"
Class {
	#name : 'ManifestPharoVulkanBindingsTests',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Bindings-Tests-Manifest',
	#package : 'PharoVulkan-Bindings-Tests',
	#tag : 'Manifest'
}
