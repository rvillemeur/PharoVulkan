"
Exposes SDL_Vulkan_* functions via uFFI. All methods are class-side.
"
Class {
	#name : 'SDL2Vulkan',
	#superclass : 'Object',
	#category : 'PharoVulkan-SDL2',
	#package : 'PharoVulkan',
	#tag : 'SDL2'
}

{ #category : 'ffi' }
SDL2Vulkan class >> createSurface: window instance: instance pSurface: pSurface [
    ^ self ffiCall: #( bool SDL_Vulkan_CreateSurface (
        void* window, VkInstance_H instance, void* pSurface ) )
]

{ #category : 'library' }
SDL2Vulkan class >> ffiLibrary [
    ^ SDL2Library
]

{ #category : 'ffi' }
SDL2Vulkan class >> getDrawableSize: window w: pW h: pH [
    ^ self ffiCall: #( void SDL_Vulkan_GetDrawableSize (
        void* window, void* pW, void* pH ) )
]

{ #category : 'ffi' }
SDL2Vulkan class >> getInstanceExtensions: window count: pCount names: ppNames [
    ^ self ffiCall: #( bool SDL_Vulkan_GetInstanceExtensions (
        void* window, void* pCount, void* ppNames ) )
]

{ #category : 'constants' }
SDL2Vulkan class >> sdlWindowVulkan [
    "SDL_WINDOW_VULKAN = 0x10000000"
    ^ 16r10000000
]
