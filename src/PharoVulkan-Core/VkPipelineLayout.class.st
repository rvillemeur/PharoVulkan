"
Vulkan pipeline layout. Combines descriptor set layouts and optional push constant ranges into a VkPipelineLayout_H used when creating pipelines. Key method: initializeOn:setLayouts:.
"
Class {
	#name : 'VkPipelineLayout',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'setLayouts'
	],
	#category : 'PharoVulkan-Core-Resources',
	#package : 'PharoVulkan-Core',
	#tag : 'Resources'
}

{ #category : 'factory' }
VkPipelineLayout class >> on: aDevice setLayouts: layouts [
    ^ self new initializeOn: aDevice setLayouts: layouts
]

{ #category : 'lifecycle' }
VkPipelineLayout >> create [
	"VkPipelineLayoutCreateInfo (48 bytes):
     0:sType  8:pNext  16:flags  20:setLayoutCount  24:pSetLayouts(ptr)  32:pushConstantRangeCount  40:pPushConstantRanges(ptr)"

	| setsBuf info layoutBuf result |
	setsBuf := ExternalAddress allocate: setLayouts size * 8.
	handle := [
		          setLayouts doWithIndex: [ :sl :i |
			          setsBuf pointerAt: i - 1 * 8 + 1 put: sl handle getHandle ].
		          info := ExternalAddress allocate: 48.
		          [
			          info
				          unsignedLongAt: 1
				          put: VkStructureType pipelineLayoutCreateInfo.
			          info pointerAt: 9 put: ExternalAddress null.
			          info unsignedLongAt: 17 put: 0.
			          info unsignedLongAt: 21 put: setLayouts size.
			          info pointerAt: 25 put: setsBuf.
			          info unsignedLongAt: 33 put: 0.
			          info pointerAt: 41 put: ExternalAddress null.
			          layoutBuf := ExternalAddress allocate: 8.
			          [
				          result := Vk
					                    createPipelineLayout: device handle
					                    createInfo: info
					                    allocator: ExternalAddress null
					                    pipelineLayoutOut: layoutBuf.
				          Vk checkResult: result.
				          VkPipelineLayout_H fromHandle: (layoutBuf pointerAt: 1) ]
				          ensure: [ layoutBuf free ] ] ensure: [ info free ] ]
		          ensure: [ setsBuf free ]
]

{ #category : 'lifecycle' }
VkPipelineLayout >> destroy [

	handle ifNotNil: [
			Vk
				destroyPipelineLayout: device handle
				pipelineLayout: handle
				allocator: ExternalAddress null.
			handle invalidate.
			handle := nil ]
]

{ #category : 'accessing' }
VkPipelineLayout >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkPipelineLayout >> initializeOn: aDevice setLayouts: layouts [
    device := aDevice. setLayouts := layouts. self create
]
