"
Loads SPIR-V bytecode into a VkShaderModule_H on the device. Key method: fromBytes:device:. Must be destroyed explicitly with destroy after pipeline creation.
"
Class {
	#name : 'VkShaderModule',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'device'
	],
	#category : 'PharoVulkan-Core',
	#package : 'PharoVulkan-Core'
}

{ #category : 'factory' }
VkShaderModule class >> fromBytes: spirvBytes device: aDevice [
    ^ self new initializeFromBytes: spirvBytes device: aDevice
]

{ #category : 'lifecycle' }
VkShaderModule >> destroy [
    handle ifNotNil: [ Vk destroyShaderModule: device handle shaderModule: handle allocator: ExternalAddress null. handle := nil ]
]

{ #category : 'accessing' }
VkShaderModule >> handle [
    ^ handle
]

{ #category : 'lifecycle' }
VkShaderModule >> initializeFromBytes: spirvBytes device: aDevice [
	"VkShaderModuleCreateInfo: 1:sType 9:pNext 17:flags 25:codeSize(u64) 33:pCode"
	| codeBuf info modBuf result |
	device := aDevice.
	codeBuf := ExternalAddress allocate: spirvBytes size.
	1 to: spirvBytes size do: [:i | codeBuf byteAt: i put: (spirvBytes at: i)].
	[ info := ExternalAddress allocate: 40.
	  [ info unsignedLongAt: 1 put: 16.
	    info pointerAt: 9 put: ExternalAddress null.
	    info unsignedLongAt: 17 put: 0.
	    info unsignedLongLongAt: 25 put: spirvBytes size.
	    info pointerAt: 33 put: codeBuf.
	    modBuf := ExternalAddress allocate: 8.
	    [ result := Vk createShaderModule: device handle
	          createInfo: info allocator: ExternalAddress null shaderModuleOut: modBuf.
	      Vk checkResult: result.
	      handle := VkShaderModule_H fromHandle: (modBuf pointerAt: 1)
	    ] ensure: [ modBuf free ]
	  ] ensure: [ info free ]
	] ensure: [ codeBuf free ]
]
