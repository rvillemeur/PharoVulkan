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
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'constants' }
VkFramebuffer class >> attachmentByteCount [
	"An attachment entry is one handle wide. The run has no field specification to read a
	 width from, because uFFI in this image cannot declare an array field, so the stride is
	 named here."

	^ ExternalAddress wordSize
]

{ #category : 'instance creation' }
VkFramebuffer class >> attachmentsOutsideObjectMemory: aCollectionOfViews [
	"The attachment views as the run of handles the request points at, outside object memory
	 so the garbage collector cannot move them while the driver reads them. The caller owns
	 the block and must free it."

	| run |
	run := ExternalAddress allocate:
		       aCollectionOfViews size * self attachmentByteCount.
	aCollectionOfViews doWithIndex: [ :each :index |
		run
			pointerAt: index - 1 * self attachmentByteCount + 1
			put: each getHandle ].
	^ run
]

{ #category : 'constants' }
VkFramebuffer class >> attachmentsPerFramebuffer [
	"One colour attachment per framebuffer: no path here renders into more than one image at
	 a time, and none has a depth attachment."

	^ 1
]

{ #category : 'instance creation' }
VkFramebuffer class >> createInfoForRenderPass: aRenderPassHandle attachments: anAttachmentRun extent: aPoint [
	"The request every framebuffer here is created from. The attachment run is written by
	 attachmentsOutsideObjectMemory: and stays the caller's to free; this request only points
	 at it. The flags are the zeros a fresh block holds. The caller frees getHandle."

	| info |
	info := VkFramebufferCreateInfo externalInstance.
	info
		renderPass: aRenderPassHandle;
		attachmentCount: self attachmentsPerFramebuffer;
		pAttachments: anAttachmentRun;
		width: aPoint x;
		height: aPoint y;
		layers: self layersPerFramebuffer.
	^ info
]

{ #category : 'instance creation' }
VkFramebuffer class >> handleForCreateInfo: aCreateInfo on: aDevice [
	"The one call to vkCreateFramebuffer in the project. The out parameter is freed whichever
	 way the call goes, and the result is checked before the handle is read: reading it after
	 a failed call would dereference whatever the out parameter held."

	| out result |
	out := ExternalAddress allocate: ExternalAddress wordSize.
	^ [ result := Vk
		           createFramebuffer: aDevice handle
		           createInfo: aCreateInfo getHandle
		           allocator: ExternalAddress null
		           pFramebuffer: out.
	  Vk checkResult: result.
	  VkFramebuffer_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'constants' }
VkFramebuffer class >> layersPerFramebuffer [
	"One layer: neither the window path nor the offscreen target renders into a layered
	 image."

	^ 1
]

{ #category : 'instance creation' }
VkFramebuffer class >> on: aVkDevice renderPass: aRenderPass imageView: anImageView extent: aPoint [
	"The extent is one point rather than a width and a height: the request takes a point, and
	 both callers had one to begin with."

	^ self new
		  initializeDevice: aVkDevice
		  renderPass: aRenderPass
		  imageView: anImageView
		  extent: aPoint
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
VkFramebuffer >> initializeDevice: aVkDevice renderPass: aRenderPass imageView: anImageView extent: aPoint [
	"One framebuffer binding one view to a render pass. The attachment run and the request
	 are both freed whichever way the creation goes, innermost first: the driver reads both
	 during the call and neither afterwards."

	| run |
	device := aVkDevice.
	run := self class attachmentsOutsideObjectMemory: { anImageView }.
	handle := [ | info |
	          info := self class
		                  createInfoForRenderPass: aRenderPass handle
		                  attachments: run
		                  extent: aPoint.
	          [ self class handleForCreateInfo: info on: device ] ensure: [
		          info getHandle free ] ] ensure: [ run free ]
]
