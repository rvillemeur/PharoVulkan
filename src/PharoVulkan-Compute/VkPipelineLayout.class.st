Class {
	#name : 'VkPipelineLayout',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'setLayouts',
		'pushConstantRanges'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan-Compute'
}

{ #category : 'factory' }
VkPipelineLayout class >> on: aDevice setLayouts: layouts [
    ^ self new initializeOn: aDevice setLayouts: layouts
]

{ #category : 'lifecycle' }
VkPipelineLayout >> create [
    "VkPipelineLayoutCreateInfo: sType=30, pNext, flags=0, setLayoutCount, pSetLayouts(8), pushCount=0, pPushRanges=null"
    | setsBuf info layoutBuf result |
    setsBuf := ExternalAddress allocate: setLayouts size * 8.
    [ setLayouts doWithIndex: [ :sl :i |
        setsBuf pointerAt: (i - 1) * 8 + 1 put: sl handle getHandle ].
      info := ExternalAddress allocate: 48.
      [ info unsignedLongAt: 1 put: 30.
        info pointerAt: 9 put: ExternalAddress null.
        info unsignedLongAt: 17 put: 0.
        info unsignedLongAt: 21 put: setLayouts size.
        info pointerAt: 25 put: setsBuf.
        info unsignedLongAt: 33 put: 0.
        info pointerAt: 41 put: ExternalAddress null.
        layoutBuf := ExternalAddress allocate: 8.
        [ result := Vk createPipelineLayout: device handle createInfo: info allocator: ExternalAddress null pipelineLayoutOut: layoutBuf.
          Vk checkResult: result.
          handle := VkPipelineLayout_H fromHandle: (layoutBuf pointerAt: 1)
        ] ensure: [ layoutBuf free ]
      ] ensure: [ info free ]
    ] ensure: [ setsBuf free ]
]

{ #category : 'lifecycle' }
VkPipelineLayout >> destroy [
    handle ifNotNil: [ Vk destroyPipelineLayout: device handle pipelineLayout: handle allocator: ExternalAddress null. handle := nil ]
]

{ #category : 'accessing' }
VkPipelineLayout >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkPipelineLayout >> initializeOn: aDevice setLayouts: layouts [
    device := aDevice. setLayouts := layouts. self create
]
