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
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkMemoryRequirements class >> exampleRequirementsOfAColorAttachmentOnThisMachine [
	"One click: what this machine's driver demands to back a 64 by 64 colour attachment, next
	 to the arithmetic size of its pixels. The driver's number is the larger of the two here,
	 which is why VkImage binds what it is told and never width * height * 4."

	<sampleInstance>
	| context |
	context := VkContext offscreenGraphicsContext.
	^ [
	  | image requirements |
	  image := VkImage
		           on: context device
		           format: VkFormat b8g8r8a8Unorm
		           extent: 64 @ 64
		           usage: VkImageUsage colorAttachmentBit.
	  requirements := [ image memoryRequirements ] ensure: [ image destroy ].
	  {
		  (#requirements -> requirements).
		  (#arithmeticSize -> (64 * 64 * 4)) } ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkMemoryRequirements class >> exampleRequirementsOfAStorageBufferOnThisMachine [
	"One click: what this machine's driver demands to back a small storage buffer. The numbers
	 are the device's, not the project's — the request is for four floats, and the driver is
	 free to ask for more bytes and for an alignment of its choosing."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  | buffer |
	  buffer := VkBuffer
		            on: context device
		            size: VkBuffer exampleByteSize
		            usage: VkBuffer storageBufferUsage.
	  [ buffer memoryRequirements ] ensure: [ buffer destroy ] ] ensure: [
		  context destroy ]
]

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
