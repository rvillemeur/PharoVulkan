Class {
	#name : 'VkRenderPass',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device'
	],
	#category : 'Pharovulkan-graphics',
	#package : 'Pharovulkan-graphics'
}

{ #category : 'instance creation' }
VkRenderPass class >> createColorPassDevice: aVkDevice format: colorFormat [
    ^ self new initializeDevice: aVkDevice format: colorFormat
]

{ #category : 'lifecycle' }
VkRenderPass >> destroy [
    handle ifNotNil: [
        Vk destroyRenderPass: device handle renderPass: handle allocator: ExternalAddress null.
        handle := nil ]
]

{ #category : 'accessing' }
VkRenderPass >> handle [
    ^ handle
]

{ #category : 'initialize-release' }
VkRenderPass >> initializeDevice: aVkDevice format: colorFormat [
    | attachDesc attachRef subpassDesc subpassInfoBuf result outBuf |
    device := aVkDevice.
    "VkAttachmentDescription (36 bytes)"
    attachDesc := ExternalAddress allocate: 36.
    [
        attachDesc unsignedLongAt: 1  put: 0.            "flags"
        attachDesc unsignedLongAt: 5  put: colorFormat.  "format"
        attachDesc unsignedLongAt: 9  put: 1.            "samples=1"
        attachDesc unsignedLongAt: 13 put: 1.            "loadOp=CLEAR"
        attachDesc unsignedLongAt: 17 put: 0.            "storeOp=STORE"
        attachDesc unsignedLongAt: 21 put: 2.            "stencilLoadOp=DONT_CARE"
        attachDesc unsignedLongAt: 25 put: 1.            "stencilStoreOp=DONT_CARE"
        attachDesc unsignedLongAt: 29 put: 0.            "initialLayout=UNDEFINED"
        attachDesc unsignedLongAt: 33 put: 1000001002.   "finalLayout=PRESENT_SRC_KHR"
        "VkAttachmentReference (8 bytes): attachment=0, layout=COLOR_ATTACHMENT_OPTIMAL=2"
        attachRef := ExternalAddress allocate: 8.
        [
            attachRef unsignedLongAt: 1 put: 0.
            attachRef unsignedLongAt: 5 put: 2.
            "VkSubpassDescription (72 bytes)"
            subpassDesc := ExternalAddress allocate: 72.
            [
                subpassDesc unsignedLongAt: 1  put: 0.  "flags"
                subpassDesc unsignedLongAt: 5  put: 0.  "pipelineBindPoint=GRAPHICS"
                subpassDesc unsignedLongAt: 9  put: 0.  "inputAttachmentCount"
                subpassDesc pointerAt:   17 put: ExternalAddress null.
                subpassDesc unsignedLongAt: 25 put: 1.  "colorAttachmentCount"
                subpassDesc pointerAt:   33 put: attachRef.
                subpassDesc pointerAt:   41 put: ExternalAddress null.  "pResolveAttachments"
                subpassDesc pointerAt:   49 put: ExternalAddress null.  "pDepthStencilAttachment"
                subpassDesc unsignedLongAt: 57 put: 0.  "preserveAttachmentCount"
                subpassDesc pointerAt:   65 put: ExternalAddress null.
                "VkRenderPassCreateInfo (64 bytes)"
                subpassInfoBuf := ExternalAddress allocate: 64.
                [
                    subpassInfoBuf unsignedLongAt: 1  put: 38.  "VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO"
                    subpassInfoBuf pointerAt:   9  put: ExternalAddress null.
                    subpassInfoBuf unsignedLongAt: 17 put: 0.   "flags"
                    subpassInfoBuf unsignedLongAt: 21 put: 1.   "attachmentCount"
                    subpassInfoBuf pointerAt:   25 put: attachDesc.
                    subpassInfoBuf unsignedLongAt: 33 put: 1.   "subpassCount"
                    subpassInfoBuf pointerAt:   41 put: subpassDesc.
                    subpassInfoBuf unsignedLongAt: 49 put: 0.   "dependencyCount"
                    subpassInfoBuf pointerAt:   57 put: ExternalAddress null.
                    outBuf := ExternalAddress allocate: 8.
                    [
                        result := Vk createRenderPass: device handle createInfo: subpassInfoBuf allocator: ExternalAddress null pRenderPass: outBuf.
                        Vk checkResult: result.
                        handle := VkRenderPass_H fromHandle: (outBuf pointerAt: 1)
                    ] ensure: [ outBuf free ]
                ] ensure: [ subpassInfoBuf free ]
            ] ensure: [ subpassDesc free ]
        ] ensure: [ attachRef free ]
    ] ensure: [ attachDesc free ]
]
