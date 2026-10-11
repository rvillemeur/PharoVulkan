"
Vulkan render pass. Defines one colour attachment with CLEAR/STORE ops and PRESENT_SRC_KHR final layout. Key method: createColorPassDevice:format:.
"
Class {
	#name : 'VkRenderPass',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'instance creation' }
VkRenderPass class >> createColorPassDevice: aVkDevice format: colorFormat [
    ^ self new initializeDevice: aVkDevice format: colorFormat
]

{ #category : 'instance creation' }
VkRenderPass class >> createOffscreenColorPassDevice: aVkDevice format: colorFormat [
	"The offscreen variant: the attachment ends up ready to be copied out, which is why the
	 readback path needs no image barrier of its own."

	^ self new
		  initializeDevice: aVkDevice
		  format: colorFormat
		  finalLayout: VkImageLayout transferSrcOptimal
]

{ #category : 'lifecycle' }
VkRenderPass >> destroy [

	handle ifNotNil: [
			Vk
				destroyRenderPass: device handle
				renderPass: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkRenderPass >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkRenderPass >> initializeDevice: aVkDevice format: colorFormat [
	"The window variant: the attachment ends up ready to present."

	^ self
		  initializeDevice: aVkDevice
		  format: colorFormat
		  finalLayout: VkImageLayout presentSrcKHR
]

{ #category : 'initialization' }
VkRenderPass >> initializeDevice: aVkDevice format: colorFormat finalLayout: finalLayout [
	"finalLayout is where the render pass leaves the attachment when the subpass ends. The
	 window path asks for presentSrcKHR, the offscreen path for transferSrcOptimal; because the
	 render pass performs that transition itself, a copy out of the image needs no image barrier
	 in front of it.
	 VkAttachmentDescription (36 bytes): flags format samples loadOp storeOp stencilLoadOp stencilStoreOp initialLayout finalLayout
	 VkAttachmentReference (8 bytes): 0:attachment  4:layout
	 VkSubpassDescription (72 bytes): 0:flags 4:bindPoint 8:inputCount 16:pInputAttachments 24:colorCount 32:pColorAttachments 40:pResolveAttachments 48:pDepthStencilAttachment 56:preserveCount 64:pPreserveAttachments
	 VkRenderPassCreateInfo (64 bytes): 0:sType 8:pNext 16:flags 20:attachmentCount 24:pAttachments 32:subpassCount 40:pSubpasses 48:dependencyCount 56:pDependencies"

	| attachDesc attachRef subpassDesc subpassInfoBuf result outBuf |
	device := aVkDevice.
	attachDesc := ExternalAddress allocate: 36.
	handle := [
	          attachDesc unsignedLongAt: 1 put: 0.
	          attachDesc unsignedLongAt: 5 put: colorFormat.
	          attachDesc
		          unsignedLongAt: 9
		          put: VkRenderConfig sampleCount1Bit.
	          attachDesc
		          unsignedLongAt: 13
		          put: VkAttachmentOp loadClear.
	          attachDesc
		          unsignedLongAt: 17
		          put: VkAttachmentOp storeStore.
	          attachDesc
		          unsignedLongAt: 21
		          put: VkAttachmentOp loadDontCare.
	          attachDesc
		          unsignedLongAt: 25
		          put: VkAttachmentOp storeDiscard.
	          attachDesc unsignedLongAt: 29 put: VkImageLayout undefined.
	          attachDesc unsignedLongAt: 33 put: finalLayout.
	          attachRef := ExternalAddress allocate: 8.
	          [
	          attachRef unsignedLongAt: 1 put: 0.
	          attachRef
		          unsignedLongAt: 5
		          put: VkImageLayout colorAttachmentOptimal.
	          subpassDesc := ExternalAddress allocate: 72.
	          [
	          subpassDesc unsignedLongAt: 1 put: 0.
	          subpassDesc unsignedLongAt: 5 put: 0.
	          subpassDesc unsignedLongAt: 9 put: 0.
	          subpassDesc pointerAt: 17 put: ExternalAddress null.
	          subpassDesc unsignedLongAt: 25 put: 1.
	          subpassDesc pointerAt: 33 put: attachRef.
	          subpassDesc pointerAt: 41 put: ExternalAddress null.
	          subpassDesc pointerAt: 49 put: ExternalAddress null.
	          subpassDesc unsignedLongAt: 57 put: 0.
	          subpassDesc pointerAt: 65 put: ExternalAddress null.
	          subpassInfoBuf := ExternalAddress allocate: 64.
	          [
	          subpassInfoBuf
		          unsignedLongAt: 1
		          put: VkStructureType renderPassCreateInfo.
	          subpassInfoBuf pointerAt: 9 put: ExternalAddress null.
	          subpassInfoBuf unsignedLongAt: 17 put: 0.
	          subpassInfoBuf unsignedLongAt: 21 put: 1.
	          subpassInfoBuf pointerAt: 25 put: attachDesc.
	          subpassInfoBuf unsignedLongAt: 33 put: 1.
	          subpassInfoBuf pointerAt: 41 put: subpassDesc.
	          subpassInfoBuf unsignedLongAt: 49 put: 0.
	          subpassInfoBuf pointerAt: 57 put: ExternalAddress null.
	          outBuf := ExternalAddress allocate: 8.
	          [
	          result := Vk
		                    createRenderPass: device handle
		                    createInfo: subpassInfoBuf
		                    allocator: ExternalAddress null
		                    pRenderPass: outBuf.
	          Vk checkResult: result.
	          VkRenderPass_H fromHandle: (outBuf pointerAt: 1) ]
		          ensure: [ outBuf free ] ] ensure: [
		          subpassInfoBuf free ] ] ensure: [ subpassDesc free ] ]
		          ensure: [ attachRef free ] ] ensure: [ attachDesc free ]
]
