"
Vulkan framebuffer. Wraps a VkFramebuffer_H binding one image view to a render pass for a specific extent. Created per swapchain image. Key method: initializeDevice:renderPass:imageView:width:height:.
"
Class {
	#name : 'VkFramebuffer',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device'
	],
	#category : 'Pharovulkan-graphics',
	#package : 'Pharovulkan-graphics'
}

{ #category : 'instance creation' }
VkFramebuffer class >> on: aVkDevice renderPass: aRenderPass imageView: anImageView width: w height: h [
    ^ self new initializeDevice: aVkDevice renderPass: aRenderPass imageView: anImageView width: w height: h
]

{ #category : 'lifecycle' }
VkFramebuffer >> destroy [

	handle ifNotNil: [
			Vk
				destroyFramebuffer: device handle
				framebuffer: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkFramebuffer >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkFramebuffer >> initializeDevice: aVkDevice renderPass: aRenderPass imageView: anImageView width: w height: h [
	"VkFramebufferCreateInfo (64 bytes):
     0:sType  8:pNext  16:flags  24:renderPass  32:attachmentCount  40:pAttachments  48:width  52:height  56:layers"

	| ivBuf fbInfo outBuf result |
	device := aVkDevice.
	ivBuf := ExternalAddress allocate: 8.
	handle := [
		          ivBuf pointerAt: 1 put: anImageView getHandle.
		          fbInfo := ExternalAddress allocate: 64.
		          [
			          fbInfo
				          unsignedLongAt: 1
				          put: VkStructureType framebufferCreateInfo.
			          fbInfo pointerAt: 9 put: ExternalAddress null.
			          fbInfo unsignedLongAt: 17 put: 0.
			          fbInfo pointerAt: 25 put: aRenderPass handle getHandle.
			          fbInfo unsignedLongAt: 33 put: 1.
			          fbInfo pointerAt: 41 put: ivBuf.
			          fbInfo unsignedLongAt: 49 put: w.
			          fbInfo unsignedLongAt: 53 put: h.
			          fbInfo unsignedLongAt: 57 put: 1.
			          outBuf := ExternalAddress allocate: 8.
			          [
				          result := Vk
					                    createFramebuffer: device handle
					                    createInfo: fbInfo
					                    allocator: ExternalAddress null
					                    pFramebuffer: outBuf.
				          Vk checkResult: result.
				          VkFramebuffer_H fromHandle: (outBuf pointerAt: 1) ]
				          ensure: [ outBuf free ] ] ensure: [ fbInfo free ] ]
		          ensure: [ ivBuf free ]
]
