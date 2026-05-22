"
Base class for all opaque Vulkan handle types (VkInstance_H, VkDevice_H, etc.).
Wraps a raw pointer provided by the Vulkan loader.
Key methods: isNull, printOn:.
"
Class {
	#name : 'VkHandle',
	#superclass : 'FFIExternalObject',
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'as yet unclassified' }
VkHandle class >> finalizeResourceData: handle [
    "Vulkan handles are driver-owned. Do not free."
]

{ #category : 'as yet unclassified' }
VkHandle >> finalize [
    "no-op — Vulkan handles are destroyed via vkDestroy* API only"
]

{ #category : 'testing' }
VkHandle >> isNull [
    "True when this handle is null — creation failed or not yet initialised."
    ^ handle isNil or: [ handle isNull ]
]

{ #category : 'printing' }
VkHandle >> printOn: aStream [
    aStream
        nextPutAll: self class name;
        nextPutAll: '(0x';
        nextPutAll: (handle isNil ifTrue: [ '0' ] ifFalse: [ handle printString ]);
        nextPut: $)
]
