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
        Vk destroyFramebuffer: device handle framebuffer: handle allocator: ExternalAddress null.
        handle := nil ]
]

{ #category : 'accessing' }
VkFramebuffer >> handle [
    ^ handle
]

{ #category : 'initialize-release' }
VkFramebuffer >> initializeDevice: aVkDevice renderPass: aRenderPass imageView: anImageView width: w height: h [
    | ivBuf fbInfo outBuf result |
    device := aVkDevice.
    ivBuf := ExternalAddress allocate: 8.
    [
        ivBuf pointerAt: 1 put: anImageView.
        fbInfo := ExternalAddress allocate: 64.
        [
            fbInfo unsignedLongAt: 1  put: 37.   "VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO"
            fbInfo pointerAt:   9  put: ExternalAddress null.
            fbInfo unsignedLongAt: 17 put: 0.
            fbInfo pointerAt:   25 put: aRenderPass handle.
            fbInfo unsignedLongAt: 33 put: 1.
            fbInfo pointerAt:   41 put: ivBuf.
            fbInfo unsignedLongAt: 49 put: w.
            fbInfo unsignedLongAt: 53 put: h.
            fbInfo unsignedLongAt: 57 put: 1.
            outBuf := ExternalAddress allocate: 8.
            [
                result := Vk createFramebuffer: device handle createInfo: fbInfo allocator: ExternalAddress null pFramebuffer: outBuf.
                Vk checkResult: result.
                handle := VkFramebuffer_H fromHandle: (outBuf pointerAt: 1)
            ] ensure: [ outBuf free ]
        ] ensure: [ fbInfo free ]
    ] ensure: [ ivBuf free ]
]
