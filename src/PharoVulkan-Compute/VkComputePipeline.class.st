Class {
	#name : 'VkComputePipeline',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device',
		'layout',
		'shaderModule',
		'entryPoint'
	],
	#category : 'PharoVulkan-Compute',
	#package : 'PharoVulkan-Compute'
}

{ #category : 'instance creation' }
VkComputePipeline class >> on: aShaderModule layout: aPipelineLayout device: aDevice [
	| p |
	p := self new.
	p shaderModule: aShaderModule.
	p layout: aPipelineLayout.
	p device: aDevice.
	p entryPoint: 'main'.
	p create.
	^ p
]

{ #category : 'lifecycle' }
VkComputePipeline >> create [
	"VkComputePipelineCreateInfo 96 bytes: sType=29, stage inline at byte 25"
	| nameBuf info pipelineBuf result |
	nameBuf := ExternalAddress allocate: entryPoint size + 1.
	[
		1 to: entryPoint size do: [:i | nameBuf byteAt: i put: (entryPoint at: i) asciiValue].
		nameBuf byteAt: entryPoint size + 1 put: 0.
		info := ExternalAddress allocate: 96.
		[
			info unsignedLongAt: 1 put: 29.
			info pointerAt: 9 put: ExternalAddress null.
			info unsignedLongAt: 17 put: 0.
			info unsignedLongAt: 25 put: 18.
			info pointerAt: 33 put: ExternalAddress null.
			info unsignedLongAt: 41 put: 0.
			info unsignedLongAt: 45 put: 32.
			info pointerAt: 49 put: shaderModule handle getHandle.
			info pointerAt: 57 put: nameBuf.
			info pointerAt: 65 put: ExternalAddress null.
			info pointerAt: 73 put: layout handle getHandle.
			info pointerAt: 81 put: ExternalAddress null.
			info unsignedLongAt: 89 put: 16rFFFFFFFF.
			pipelineBuf := ExternalAddress allocate: 8.
			[
				result := Vk createComputePipelines: device handle pipelineCache: ExternalAddress null
					createInfoCount: 1 createInfos: info allocator: ExternalAddress null pipelines: pipelineBuf.
				Vk checkResult: result.
				handle := VkPipeline_H fromHandle: (pipelineBuf pointerAt: 1)
			] ensure: [ pipelineBuf free ]
		] ensure: [ info free ]
	] ensure: [ nameBuf free ]
]

{ #category : 'lifecycle' }
VkComputePipeline >> destroy [
	handle isNil ifTrue: [ ^ self ].
	Vk destroyPipeline: device handle pipeline: handle allocator: ExternalAddress null.
	handle := nil
]

{ #category : 'accessing' }
VkComputePipeline >> device: aDevice [
	device := aDevice
]

{ #category : 'accessing' }
VkComputePipeline >> entryPoint: aString [
	entryPoint := aString
]

{ #category : 'accessing' }
VkComputePipeline >> handle [
	^ handle
]

{ #category : 'accessing' }
VkComputePipeline >> layout: aLayout [
	layout := aLayout
]

{ #category : 'accessing' }
VkComputePipeline >> shaderModule: aSM [
	shaderModule := aSM
]
