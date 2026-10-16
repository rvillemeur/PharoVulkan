"
Examples of the offscreen colour pass this project renders through: the image and image view it draws into, the attachment description and reference, the subpass that reads them, the render pass request, the framebuffer request that binds the view, and the begin info that clears the attachment before the draw.

Every one is built in object memory with its pointers null, so a click frees nothing; the live pass is covered by the image and graphics tests. Read in the order above they are one render pass described from the attachment outwards.
"
Class {
	#name : 'VkRenderPassExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkRenderPassExamples class >> beginInfoForAClearedPass [
	"One click: the begin info every pass in this project opens with, built by the recorder for
	 an example extent and the clear colour the window path uses. No device is touched, so the
	 render pass and the framebuffer are left unset. The clear values are freed with the
	 example, so the copy's pointer to them is cleared rather than left dangling: the Pass tab
	 follows that pointer, and following a freed block is how an image dies. The count stays at
	 one, which is what the recorder writes, and the tab says the values are out of reach."

	<sampleInstance>
	| values |
	values := VkCommandBuffer clearValuesOutsideObjectMemory:
		          VkRenderConfig clearColorBlackOpaque.
	^ [
	  | info |
	  info := VkCommandBuffer
		          renderPassBeginInfoFor: (VkRenderPass_H fromHandle: ExternalAddress null)
		          framebuffer: (VkFramebuffer_H fromHandle: ExternalAddress null)
		          extent: VkBufferImageCopy exampleExtent
		          clearValues: values.
	  [
	  info pClearValues: ExternalAddress null.
	  info copyIntoObjectMemory ] ensure: [ info getHandle free ] ] ensure: [
		  values free ]
]

{ #category : 'examples' }
VkRenderPassExamples class >> colourAttachmentOfTheOffscreenPass [
	"One click: the attachment description the offscreen pass is built from, written by its
	 one writer. No device is touched. The answer is a copy in object memory, so the external
	 block is freed with the example and the Attachment tab reads bytes that are still
	 there."

	<sampleInstance>
	| description |
	description := VkRenderPass
		               attachmentDescriptionForFormat: VkFormat b8g8r8a8Unorm
		               finalLayout: VkImageLayout transferSrcOptimal.
	^ [ description copyIntoObjectMemory ] ensure: [ description getHandle free ]
]

{ #category : 'examples' }
VkRenderPassExamples class >> framebufferRequestBindingOneColourAttachment [
	"One click: the request every framebuffer in this project is created from, built by its
	 writer for the example extent. No device is touched, so the render pass and the
	 attachment handle are left unset and the Framebuffer tab says so. The attachment run is
	 freed with the example, so the copy's pointer to it is cleared rather than left
	 dangling: the tab reads through that pointer, and reading a freed block is how an image
	 dies. The count stays at one, which is what the writer wrote, and the tab then answers no
	 handles."

	<sampleInstance>
	| run |
	run := VkFramebuffer attachmentsOutsideObjectMemory:
		       { (VkImageView_H fromHandle: ExternalAddress null) }.
	^ [ | info |
	  info := VkFramebuffer
		          createInfoForRenderPass: (VkRenderPass_H fromHandle: ExternalAddress null)
		          attachments: run
		          extent: VkImage exampleExtent.
	  [ info pAttachments: ExternalAddress null.
	    info copyIntoObjectMemory ] ensure: [ info getHandle free ] ] ensure: [
		  run free ]
]

{ #category : 'examples' }
VkRenderPassExamples class >> imageRequestForAColourAttachment [
	"One click: the request every image in this project is created from, written by its one
	 writer for the example extent. No device is touched. The answer is a copy in object
	 memory, so the external block is freed with the example and the Image tab reads bytes
	 that are still there; the request points at nothing, so the copy carries no address that
	 has gone."

	<sampleInstance>
	| info |
	info := VkImage
		        createInfoForFormat: VkFormat b8g8r8a8Unorm
		        extent: VkImage exampleExtent
		        usage:
		        (VkImageUsage colorAttachmentBit bitOr: VkImageUsage transferSrcBit).
	^ [ info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'examples' }
VkRenderPassExamples class >> referenceToTheColourAttachment [
	"One click: the reference every subpass here reads, written by its one writer. The answer
	 is a copy in object memory, so the external block is freed with the example."

	<sampleInstance>
	| reference |
	reference := VkRenderPass colorAttachmentReference.
	^ [ reference copyIntoObjectMemory ] ensure: [ reference getHandle free ]
]

{ #category : 'examples' }
VkRenderPassExamples class >> requestForTheOffscreenColourPass [
	"One click: the request every render pass in this project is created from, built by its
	 one writer over the two structures it points at. No device is touched. Both pointers are
	 cleared before the copy is kept, because the structures they point at are freed with the
	 example; the counts stay at one, which is what the writer wrote, and the Request tab
	 then says the runs are not there."

	<sampleInstance>
	| description |
	description := VkRenderPass
		               attachmentDescriptionForFormat: VkFormat b8g8r8a8Unorm
		               finalLayout: VkImageLayout transferSrcOptimal.
	^ [ | reference |
	  reference := VkRenderPass colorAttachmentReference.
	  [ | subpass |
	  subpass := VkRenderPass subpassDescriptionReading: reference.
	  [ | info |
	  info := VkRenderPass createInfoForAttachment: description subpass: subpass.
	  [ info
		    pAttachments: ExternalAddress null;
		    pSubpasses: ExternalAddress null.
	    info copyIntoObjectMemory ] ensure: [ info getHandle free ] ] ensure: [
		  subpass getHandle free ] ] ensure: [ reference getHandle free ] ] ensure: [
		  description getHandle free ]
]

{ #category : 'examples' }
VkRenderPassExamples class >> subpassReadingOneColourAttachment [
	"One click: the one subpass of every pass here, written by its one writer. Its pointer to
	 the reference is cleared before the copy is kept, because the reference is freed with
	 the example: a kept address would say a run is there when its memory has gone back."

	<sampleInstance>
	| reference |
	reference := VkRenderPass colorAttachmentReference.
	^ [ | subpass |
	  subpass := VkRenderPass subpassDescriptionReading: reference.
	  [ subpass pColorAttachments: ExternalAddress null.
	    subpass copyIntoObjectMemory ] ensure: [ subpass getHandle free ] ] ensure: [
		  reference getHandle free ]
]

{ #category : 'examples' }
VkRenderPassExamples class >> viewRequestForAColourAttachment [
	"One click: the request every image view in this project is created from, built by its
	 writer for the format the swapchain uses. No device is touched, so the image stays
	 unset and the View tab says so. The request is copied into object memory and its own
	 block freed, so the example leaves nothing allocated outside the image."

	<sampleInstance>
	| info |
	info := VkImage
		        viewRequestFor: (VkImage_H fromHandle: ExternalAddress null)
		        format: VkFormat b8g8r8a8Unorm.
	^ [ info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]
