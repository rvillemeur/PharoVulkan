"
SDL2 backend window subclass that adds Vulkan surface support. Overrides createSurface to call SDL_Vulkan_CreateSurface, provides requiredInstanceExtensions from SDL, and returns the drawable extent for Wayland-safe swapchain sizing.
"
Class {
	#name : 'OSSDL2VulkanBackendWindow',
	#superclass : 'OSSDL2BackendWindow',
	#category : 'PharoVulkan-Graphics-SDL2',
	#package : 'PharoVulkan-Graphics',
	#tag : 'SDL2'
}

{ #category : 'surface' }
OSSDL2VulkanBackendWindow >> createVulkanSurface: aVkInstance [
    | pSurface result surfaceHandle |
    pSurface := ExternalAddress allocate: 8.
    [
        result := SDL2Vulkan createSurface: sdl2Window getHandle instance: aVkInstance pSurface: pSurface.
        result = 0 ifTrue: [ Error signal: 'SDL_Vulkan_CreateSurface failed' ].
        surfaceHandle := VkSurfaceKHR_H fromHandle: (pSurface pointerAt: 1).
        ^ surfaceHandle
    ] ensure: [ pSurface free ]
]

{ #category : 'vulkan' }
OSSDL2VulkanBackendWindow >> instanceExtensionsInto: aCountAddress names: aNamesAddress [
	"SDL_Vulkan_GetInstanceExtensions, answering what it answers: a boolean, true when it filled
	 in what was asked of it. Asked with a null names address it writes the count alone.
	 It is a method of its own so that a test can refuse the call, which no window and no
	 argument can make SDL do: it answers true for every window one can build."

	^ SDL2Vulkan
		  getInstanceExtensions: sdl2Window getHandle
		  count: aCountAddress
		  names: aNamesAddress
]

{ #category : 'vulkan' }
OSSDL2VulkanBackendWindow >> requiredInstanceExtensions [
	"The instance extensions a Vulkan surface on this window needs, named by SDL. The call
	 answers a boolean and is sent twice: once with a null names address, which writes the
	 count alone, and once with room for that many pointers. A refusal is false, not zero, and
	 nothing SDL did not write is read afterwards."

	| pCount count names |
	pCount := ExternalAddress allocate: 4.
	^ [
	  (self instanceExtensionsInto: pCount names: ExternalAddress null) ifFalse: [
		  Error signal: 'SDL_Vulkan_GetInstanceExtensions (count) failed' ].
	  count := pCount unsignedLongAt: 1.
	  names := ExternalAddress allocate: count * VkContext pointerSize.
	  [
	  (self instanceExtensionsInto: pCount names: names) ifFalse: [
		  Error signal: 'SDL_Vulkan_GetInstanceExtensions (names) failed' ].
	  (1 to: count) collect: [ :i |
		  (names pointerAt: i - 1 * VkContext pointerSize + 1) readString asString ] ]
		  ensure: [ names free ] ] ensure: [ pCount free ]
]

{ #category : 'surface' }
OSSDL2VulkanBackendWindow >> vulkanDrawableExtent [

	| pw ph |
	pw := ExternalAddress allocate: 4.
	ph := ExternalAddress allocate: 4.
	^ [
		  SDL2Vulkan getDrawableSize: sdl2Window getHandle w: pw h: ph.
		  (pw signedLongAt: 1) @ (ph signedLongAt: 1) ] ensure: [
			  pw free.
			  ph free ]
]
