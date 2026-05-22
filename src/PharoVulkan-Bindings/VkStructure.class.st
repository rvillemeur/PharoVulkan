"
Base class for all Vulkan struct types. Includes VkTypes shared pool for
fixed-size array field types (Uint8_256, etc.). Subclasses define field layout via fieldsDesc.
Subclasses whose struct has an sType field must override initialize to set it.
Key methods: fieldsDesc (class-side, subclass responsibility), initialize.
"
Class {
	#name : 'VkStructure',
	#superclass : 'FFIExternalStructure',
	#pools : [
		'VkTypes'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}
