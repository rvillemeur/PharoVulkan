"
Vulkan render pass with one colour attachment: cleared on load, kept on store, and left in the layout the variant asks for — presentSrcKHR for the window path, transferSrcOptimal for the offscreen path, which is why a copy out of an offscreen image needs no barrier in front of it. Build one with createColorPassDevice:format: or createOffscreenColorPassDevice:format:. The four structures the driver reads are declared rather than counted out in bytes, and the class side holds one writer for each: attachmentDescriptionForFormat:finalLayout:, colorAttachmentReference, subpassDescriptionReading: and createInfoForAttachment:subpass:, with handleForCreateInfo:on: the only caller of vkCreateRenderPass.
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
VkRenderPass class >> attachmentDescriptionForFormat: aFormat finalLayout: aLayout [
	"The one colour attachment of every pass here: cleared on load, kept on store, its
	 stencil halves unused, entering the pass undefined and leaving it in the layout the
	 caller names. That layout is the only thing the two pass variants differ in. The flags
	 are the zeros a fresh block holds. The caller frees getHandle."

	| description |
	description := VkAttachmentDescription externalInstance.
	description
		format: aFormat;
		samples: VkRenderConfig sampleCount1Bit;
		loadOp: VkAttachmentOp loadClear;
		storeOp: VkAttachmentOp storeStore;
		stencilLoadOp: VkAttachmentOp loadDontCare;
		stencilStoreOp: VkAttachmentOp storeDiscard;
		initialLayout: VkImageLayout undefined;
		finalLayout: aLayout.
	^ description
]

{ #category : 'constants' }
VkRenderPass class >> attachmentsPerPass [
	"One attachment per pass: every pass here renders into a single colour image and none has
	 a depth attachment."

	^ 1
]

{ #category : 'instance creation' }
VkRenderPass class >> colorAttachmentReference [
	"Which attachment the subpass reads, and in which layout. The attachment index is zero,
	 which a fresh block already holds, and it is written anyway so the reference says which
	 attachment it means rather than relying on the block. The caller frees getHandle."

	| reference |
	reference := VkAttachmentReference externalInstance.
	reference
		attachment: self firstAttachmentIndex;
		layout: VkImageLayout colorAttachmentOptimal.
	^ reference
]

{ #category : 'constants' }
VkRenderPass class >> colorAttachmentsPerSubpass [
	"The one attachment of the pass is the one colour attachment of its subpass."

	^ 1
]

{ #category : 'instance creation' }
VkRenderPass class >> createColorPassDevice: aVkDevice format: colorFormat [
    ^ self new initializeDevice: aVkDevice format: colorFormat
]

{ #category : 'instance creation' }
VkRenderPass class >> createInfoForAttachment: anAttachmentDescription subpass: aSubpassDescription [
	"The request every render pass here is created from. Both structures stay the caller's
	 to free; this request only points at them. The flags, the dependency count and the
	 dependency pointer are what a fresh block holds: a pass with one subpass has nothing
	 for a dependency to order. The caller frees getHandle."

	| info |
	info := VkRenderPassCreateInfo externalInstance.
	info
		attachmentCount: self attachmentsPerPass;
		pAttachments: anAttachmentDescription;
		subpassCount: self subpassesPerPass;
		pSubpasses: aSubpassDescription.
	^ info
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

{ #category : 'constants' }
VkRenderPass class >> firstAttachmentIndex [
	"A reference names an attachment by its index in the request's attachment run, and the
	 only attachment of these passes is the first. Zero, so a zeroed reference already names
	 it, but it is named here because the value is an index rather than an absence."

	^ 0
]

{ #category : 'instance creation' }
VkRenderPass class >> handleForCreateInfo: aCreateInfo on: aDevice [
	"The one call to vkCreateRenderPass in the project. The out parameter is freed whichever
	 way the call goes, and the result is checked before the handle is read: reading it after
	 a failed call would dereference whatever the out parameter held."

	| out result |
	out := ExternalAddress allocate: ExternalAddress wordSize.
	^ [ result := Vk
		           createRenderPass: aDevice handle
		           createInfo: aCreateInfo getHandle
		           allocator: ExternalAddress null
		           pRenderPass: out.
	  Vk checkResult: result.
	  VkRenderPass_H fromHandle: (out pointerAt: 1) ] ensure: [ out free ]
]

{ #category : 'instance creation' }
VkRenderPass class >> subpassDescriptionReading: anAttachmentReference [
	"The one subpass of every pass here: it binds the graphics slot and reads the reference
	 as its only colour attachment. The bind point is zero, so the zeroed block already asks
	 for graphics and nothing is written for it. The input, resolve, depth-stencil and
	 preserved attachments stay the null pointers and zero counts of the fresh block. The
	 reference stays the caller's to free; this description only points at it. The caller
	 frees getHandle."

	| description |
	description := VkSubpassDescription externalInstance.
	description
		pipelineBindPoint: VkPipelineBindPoint graphics;
		colorAttachmentCount: self colorAttachmentsPerSubpass;
		pColorAttachments: anAttachmentReference.
	^ description
]

{ #category : 'constants' }
VkRenderPass class >> subpassesPerPass [
	"One subpass, which is why no pass here needs a dependency: there is nothing for a
	 dependency to order."

	^ 1
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
	 window path asks for presentSrcKHR, the offscreen path for transferSrcOptimal; because
	 the render pass performs that transition itself, a copy out of the image needs no image
	 barrier in front of it.
	 The four structures are freed whichever way the creation goes, innermost first: the
	 driver reads all of them during the call and none of them afterwards, and each one is
	 pointed at by the one built after it, so none may go before the call returns."

	| description reference |
	device := aVkDevice.
	description := self class
		               attachmentDescriptionForFormat: colorFormat
		               finalLayout: finalLayout.
	handle := [
	          reference := self class colorAttachmentReference.
	          [ | subpass |
	          subpass := self class subpassDescriptionReading: reference.
	          [ | info |
	          info := self class
		                  createInfoForAttachment: description
		                  subpass: subpass.
	          [ self class handleForCreateInfo: info on: device ] ensure: [
		          info getHandle free ] ] ensure: [ subpass getHandle free ] ]
		          ensure: [ reference getHandle free ] ] ensure: [
		          description getHandle free ]
]
