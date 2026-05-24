"
SDL2 backend window subclass that adds Vulkan surface support. Overrides createSurface to call SDL_Vulkan_CreateSurface, provides requiredInstanceExtensions from SDL, and returns the drawable extent for Wayland-safe swapchain sizing.
"
Class {
	#name : 'OSSDL2VulkanBackendWindow',
	#superclass : 'OSSDL2BackendWindow',
	#category : 'PharoVulkan-SDL2',
	#package : 'PharoVulkan-SDL2'
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

{ #category : 'accessing' }
OSSDL2VulkanBackendWindow >> requiredInstanceExtensions [

	| pCount result count names |
	pCount := ExternalAddress allocate: 4.
	^ [
		  result := SDL2Vulkan
			            getInstanceExtensions: sdl2Window getHandle
			            count: pCount
			            names: ExternalAddress null.
		  result = 0 ifTrue: [
			  Error signal: 'SDL_Vulkan_GetInstanceExtensions (count) failed' ].
		  count := pCount unsignedLongAt: 1.
		  names := ExternalAddress allocate: count * 8.
		  [
			  result := SDL2Vulkan
				            getInstanceExtensions: sdl2Window getHandle
				            count: pCount
				            names: names.
			  result = 0 ifTrue: [
				  Error signal: 'SDL_Vulkan_GetInstanceExtensions (names) failed' ].
			  (1 to: count) collect: [ :i |
				  (names pointerAt: i - 1 * 8 + 1) readString asString ] ]
			  ensure: [ names free ] ] ensure: [ pCount free ]
]

{ #category : 'accessing' }
OSSDL2VulkanBackendWindow >> sdl2WindowHandle [
    ^ sdl2Window
]

{ #category : 'surface' }
OSSDL2VulkanBackendWindow >> vulkanDrawableExtent [
    | pw ph |
    pw := ExternalAddress allocate: 4.
    ph := ExternalAddress allocate: 4.
    [
        SDL2Vulkan getDrawableSize: sdl2Window getHandle w: pw h: ph.
        ^ (pw signedLongAt: 1) @ (ph signedLongAt: 1)
    ] ensure: [ pw free. ph free ]
]
