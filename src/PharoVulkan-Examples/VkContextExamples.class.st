"
Examples that ask this machine what it is: the device a capability search chooses, the offscreen context built on it, the extensions and the memory types the physical device reports, a signalled fence, a semaphore, and a shader module loaded from the compiled vector-add kernel.

Every one of these talks to the installed driver, so what it answers is a property of the machine it is clicked on rather than a fixed value. Each builds its objects fresh and destroys the ones it owns before answering, which is why clicking one twice is safe. On a machine with no Vulkan driver they raise rather than answer, and that is the honest result.
"
Class {
	#name : 'VkContextExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Core',
	#package : 'PharoVulkan-Examples',
	#tag : 'Core'
}

{ #category : 'examples' }
VkContextExamples class >> deviceChosenByCapabilityOnThisMachine [
	"One click: the context a cooperative matrix kernel would run on, destroyed before it is
	 handed over. The Device choice tab names the requirement and the device that met it,
	 which on this machine is not the first device enumerated. Falls back to the plain
	 compute context where no device offers the extension."
	<sampleInstance>
	| context |
	context := [ VkContext cooperativeMatrixContext ]
		           on: VkError
		           do: [ :signal | VkContext computeContext ].
	context destroy.
	^ context
]

{ #category : 'examples' }
VkContextExamples class >> extensionsOfThisMachine [
    "One click: the extension list of whatever device this image finds. The names are cached
     in the instance, so the object still answers them after the context is destroyed, which
     is why the example can hand back a device whose handle has gone."
    <sampleInstance>
    | context |
    context := VkContext computeContext.
    ^ [ context physicalDevice
            extensionNames;
            yourself ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkContextExamples class >> memoryTypesOfThisMachine [
	"One click: the memory-type table of whatever device this image finds. The properties
	 buffer is read once at construction and never freed by the context, which is why the
	 example can hand back a device whose context has gone."
	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ context physicalDevice ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkContextExamples class >> moduleOfTheVectorAddKernelOnThisMachine [
	"One click: the kernel the README's playground builds, compiled to SPIR-V and loaded as a
	 shader module on whichever device is here, then destroyed with its context. The byte
	 count lives in the instance, so the Module tab still answers afterwards. Where no device
	 is available it answers an empty module, which is what the inspector should show on such
	 a machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ VkShaderModule new ].
	^ [
	  | module |
	  module := VkShaderModule
		            fromBytes:
			            (PVKernelCompiler compile:
				             PVComputeKernel exampleKernelMethod)
		            device: context device.
	  module destroy.
	  module ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkContextExamples class >> offscreenContextOnThisMachine [
	"One click: the context an offscreen graphics render would use on whatever device
	 this image finds, destroyed before it is handed back. The Device choice tab names
	 the requirement (supportsGraphicsAndComputeOnOneQueue) and the device that met it,
	 which destroy does not clear."
	<sampleInstance>
	| context |
	context := VkContext offscreenGraphicsContext.
	context destroy.
	^ context
]

{ #category : 'examples' }
VkContextExamples class >> semaphoreOnThisMachine [
	"One click: one of the two semaphores a frame loop uses to order acquire against present,
	 created on this machine and destroyed with its context. Where no device is available it
	 answers an uncreated semaphore, which is what the inspector should show on such a
	 machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ VkSemaphoreWrapper new ].
	^ [
	  | semaphore |
	  semaphore := VkSemaphoreWrapper createDevice: context device.
	  semaphore destroy.
	  semaphore ] ensure: [ context destroy ]
]

{ #category : 'examples' }
VkContextExamples class >> signalledFenceOnThisMachine [
	"One click: the fence a frame loop starts with, created already signalled so the first wait
	 returns at once, then destroyed with its context. The flags live in the instance, so the
	 Fence tab still names the bit afterwards. Where no device is available it answers an
	 uncreated fence, which is what the inspector should show on such a machine."

	<sampleInstance>
	| context |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ VkFenceWrapper new ].
	^ [
	  | fence |
	  fence := VkFenceWrapper createSignaledDevice: context device.
	  fence destroy.
	  fence ] ensure: [ context destroy ]
]
