"
OSWindow driver subclass that registers the Vulkan-capable SDL2 backend. Returned as the preferred driver when Vulkan rendering is requested via OSVulkanAttributes.
"
Class {
	#name : 'PVVulkanDriver',
	#superclass : 'OSSDL2Driver',
	#category : 'PharoVulkan-SDL2',
	#package : 'PharoVulkan-SDL2'
}

{ #category : 'driver management' }
PVVulkanDriver class >> install [

	OSWindowDriver driverClass: self
]

{ #category : 'driver management' }
PVVulkanDriver class >> uninstall [
    OSWindowDriver driverClass: OSSDL2Driver
]

{ #category : 'window creation' }
PVVulkanDriver >> createWindowWithAttributes: attributes osWindow: osWindow [
    | flags handle aBackendWindow glAttributes x y vulkanAttrs |
    vulkanAttrs := (attributes isKindOf: PVWindowAttributes)
        ifTrue: [ attributes vulkanAttributes ]
        ifFalse: [ nil ].
    vulkanAttrs isNil ifTrue: [ ^ super createWindowWithAttributes: attributes osWindow: osWindow ].
    flags := attributes visible ifTrue: [ SDL_WINDOW_SHOWN ] ifFalse: [ SDL_WINDOW_HIDDEN ].
    attributes fullscreen ifTrue: [ flags := flags | SDL_WINDOW_FULLSCREEN_DESKTOP ].
    attributes borderless ifTrue: [ flags := flags | SDL_WINDOW_BORDERLESS ].
    flags := flags | SDL_WINDOW_ALLOW_HIGHDPI.
    glAttributes := attributes glAttributes.
    glAttributes ifNotNil: [ flags := flags | SDL_WINDOW_OPENGL. self setGLAttributes: glAttributes ].
    flags := flags | SDL2Vulkan sdlWindowVulkan.
    x := attributes x. y := attributes y.
    attributes windowCentered ifTrue: [ x := SDL_WINDOWPOS_CENTERED. y := SDL_WINDOWPOS_CENTERED ].
    attributes resizable ifTrue: [ flags := flags | SDL_WINDOW_RESIZABLE ].
    attributes maximized ifTrue: [ flags := flags | SDL_WINDOW_MAXIMIZED ].
    attributes minimized ifTrue: [ flags := flags | SDL_WINDOW_MINIMIZED ].
    WindowMapMutex critical: [
        handle := SDL2 createWindow: attributes title x: x y: y width: attributes width height: attributes height flags: flags.
        aBackendWindow := OSSDL2VulkanBackendWindow newWithHandle: handle attributes: attributes.
        aBackendWindow osWindow: osWindow.
        self registerWindow: aBackendWindow.
        osWindow setJustCreatedHandle: aBackendWindow ].
    ^ aBackendWindow
]
