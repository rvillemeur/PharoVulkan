"
The answer written by `vkGetBufferMemoryRequirements` and `vkGetImageMemoryRequirements`: how many bytes the resource needs, what address alignment it demands and a mask of the memory types that can hold it. This project only reads the block, so unlike the create infos the class declares no `initializeConstantFields`: an initializer would write over the driver's answer every time the block was read back through `fromHandle:`. There is no chain header either — the structure is three plain numbers.

`memoryTypeBits` is the argument to `VkPhysicalDevice >> findMemoryType:properties:`, and `size` feeds `VkMemoryAllocateInfo >> allocationSize:`. The `size` accessor overrides `Object >> size` for this class only, which is deliberate: the field is called `size` in Vulkan and the structure is never asked for a collection size.
"
Class {
	#name : 'VkMemoryRequirements',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ALIGNMENT',
		'OFFSET_MEMORYTYPEBITS',
		'OFFSET_SIZE'
	],
	#category : 'PharoVulkan-Bindings-Bindings',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkMemoryRequirements class >> fieldsDesc [
	"The driver writes all three fields: there is no chain header to carry a structure type.
	 size and alignment are VkDeviceSize values, memoryTypeBits a mask of the memory types the
	 resource can live in."

	^ #( uint64 size; uint64 alignment; uint32 memoryTypeBits )
]

{ #category : 'accessing - structure variables' }
VkMemoryRequirements >> alignment [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_ALIGNMENT
]

{ #category : 'accessing - structure variables' }
VkMemoryRequirements >> alignment: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_ALIGNMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkMemoryRequirements >> memoryTypeBits [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MEMORYTYPEBITS
]

{ #category : 'accessing - structure variables' }
VkMemoryRequirements >> memoryTypeBits: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MEMORYTYPEBITS put: anObject
]

{ #category : 'accessing' }
VkMemoryRequirements >> size [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_SIZE
]

{ #category : 'accessing - structure variables' }
VkMemoryRequirements >> size: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_SIZE put: anObject
]
