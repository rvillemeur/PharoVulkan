"
SharedPool of FFIArray type constants for fixed-size Vulkan struct fields (Uint8_16, Uint8_32, Uint8_64, etc.). Initialized at class load; imported by VkStructure subclasses with array-typed members.
"
Class {
	#name : 'VkTypes',
	#superclass : 'SharedPool',
	#classVars : [
		'Uint32_2',
		'Uint8_128',
		'Uint8_16',
		'Uint8_20',
		'Uint8_256',
		'Uint8_32',
		'Uint8_504',
		'Uint8_64'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'class initialization' }
VkTypes class >> initialize [
    "Initialise fixed-size array type constants used by Vulkan struct field declarations."
    Uint8_16  := FFIArray ofType: #uint8 size: 16.
    Uint8_20  := FFIArray ofType: #uint8 size: 20.
    Uint8_32  := FFIArray ofType: #uint8 size: 32.
    Uint8_64  := FFIArray ofType: #uint8 size: 64.
    Uint8_128 := FFIArray ofType: #uint8 size: 128.
    Uint8_256 := FFIArray ofType: #uint8 size: 256.
    Uint8_504 := FFIArray ofType: #uint8 size: 504.
    Uint32_2  := FFIArray ofType: #uint32 size: 2
]
