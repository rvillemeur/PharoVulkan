"
OSWindow driver subclass that registers the Vulkan-capable SDL2 backend. Returned as the preferred driver when Vulkan rendering is requested via OSVulkanAttributes.
"
Class {
	#name : 'PVVulkanDriver',
	#superclass : 'OSSDL2Driver',
	#category : 'PharoVulkan-Graphics-SDL2',
	#package : 'PharoVulkan-Graphics',
	#tag : 'SDL2'
}

{ #category : 'driver management' }
PVVulkanDriver class >> install [
	"Prefer installDuring:, which cannot leave the driver swapped if the caller raises."

	self quietlySetDriverClass: self
]

{ #category : 'driver management' }
PVVulkanDriver class >> installDuring: aBlock [
	"Install self as the OSWindow driver for the duration of aBlock, then restore
	 whatever was installed before. Callers must use this rather than install and
	 uninstall: a raise between the two leaves the image with a swapped driver and a
	 registered window that SDL keeps dispatching events to."

	| previous |
	previous := OSWindowDriver driverClass.
	self quietlySetDriverClass: self.
	^ aBlock ensure: [ self quietlySetDriverClass: previous ]
]

{ #category : 'driver management' }
PVVulkanDriver class >> quietlySetDriverClass: aDriverClass [
	"Swap the OSWindow driver without the dialog Pharo shows on every swap.
	 OSWindowDriver class >> driverClassFromSystem: ends with an inform: telling the
	 user to restart the image; that advice does not apply here, because the same
	 method also nils the cached driver instance, so the swap takes effect on the next
	 window creation. An example swaps twice, which would mean two dialogs per run.
	 The non-interactive manager is posed here rather than through
	 UIManager class >> nonInteractiveDuring:, which cannot run on Pharo 14: the base
	 UIManager >> nonInteractiveManager it reaches sends beDefault to the
	 NonInteractiveUIManager class, and that class-side method is gone from this image.
	 Only the swap itself runs non-interactively, never caller code, so a genuine error
	 raised inside an installDuring: block still opens a debugger as usual."
	| previous |
	previous := UIManager default.
	NonInteractiveUIManager new beDefault.
	[ OSWindowDriver driverClass: aDriverClass ] ensure: [ previous beDefault ]
]

{ #category : 'driver management' }
PVVulkanDriver class >> uninstall [
	"Restores the stock SDL2 driver. Only correct if that is what was installed before;
	 installDuring: restores the actual previous driver instead."

	self quietlySetDriverClass: OSSDL2Driver
]

{ #category : 'window creation and deletion' }
PVVulkanDriver >> createWindowWithAttributes: attributes osWindow: osWindow [

	| flags handle aBackendWindow glAttributes x y vulkanAttrs |
	vulkanAttrs := (attributes isKindOf: PVWindowAttributes) ifTrue: [
		               attributes vulkanAttributes ].
	vulkanAttrs ifNil: [
		^ super createWindowWithAttributes: attributes osWindow: osWindow ].
	flags := attributes visible
		         ifTrue: [ SDL_WINDOW_SHOWN ]
		         ifFalse: [ SDL_WINDOW_HIDDEN ].
	attributes fullscreen ifTrue: [
		flags := flags | SDL_WINDOW_FULLSCREEN_DESKTOP ].
	attributes borderless ifTrue: [
		flags := flags | SDL_WINDOW_BORDERLESS ].
	flags := flags | SDL_WINDOW_ALLOW_HIGHDPI.
	glAttributes := attributes glAttributes.
	glAttributes ifNotNil: [
			flags := flags | SDL_WINDOW_OPENGL.
			self setGLAttributes: glAttributes ].
	flags := flags | SDL2Vulkan sdlWindowVulkan.
	x := attributes x.
	y := attributes y.
	attributes windowCentered ifTrue: [
			x := SDL_WINDOWPOS_CENTERED.
			y := SDL_WINDOWPOS_CENTERED ].
	attributes resizable ifTrue: [ flags := flags | SDL_WINDOW_RESIZABLE ].
	attributes maximized ifTrue: [ flags := flags | SDL_WINDOW_MAXIMIZED ].
	attributes minimized ifTrue: [ flags := flags | SDL_WINDOW_MINIMIZED ].
	WindowMapMutex critical: [
			handle := SDL2
				          createWindow: attributes title
				          x: x
				          y: y
				          width: attributes width
				          height: attributes height
				          flags: flags.
			aBackendWindow := OSSDL2VulkanBackendWindow
				                  newWithHandle: handle
				                  attributes: attributes.
			aBackendWindow osWindow: osWindow.
			self registerWindow: aBackendWindow.
			osWindow setJustCreatedHandle: aBackendWindow ].
	^ aBackendWindow
]
