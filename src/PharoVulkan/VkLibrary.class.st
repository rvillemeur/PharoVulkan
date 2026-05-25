"
I locate the Vulkan loader shared library on each platform.
All Vulkan FFI calls route through me via VkLibrary uniqueInstance.

Key methods: unixLibraryName, win32LibraryName, macLibraryName.
"
Class {
	#name : 'VkLibrary',
	#superclass : 'FFILibrary',
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'library-names' }
VkLibrary class >> unixLibraryName [
    ^ 'libvulkan.so.1'
]

{ #category : 'library-names' }
VkLibrary >> macLibraryName [
    ^ 'libMoltenVK.dylib'
]

{ #category : 'library-names' }
VkLibrary >> unixLibraryName [
    ^ 'libvulkan.so.1'
]

{ #category : 'library-names' }
VkLibrary >> win32LibraryName [
    ^ 'vulkan-1.dll'
]
