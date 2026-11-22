"
An image whose handle belongs to someone else — a swapchain, which created it and destroys
it with itself. Nothing is created here and no memory is allocated: the handle, the format
and the extent arrive from the owner, and teardown lets go of the handle rather than
destroying it. Key methods: on:handle:format:extent:, ownsHandle, destroy.
"
Class {
	#name : 'VkBorrowedImage',
	#superclass : 'VkImage',
	#category : 'PharoVulkan-Graphics-Targets',
	#package : 'PharoVulkan-Graphics',
	#tag : 'Targets'
}

{ #category : 'instance creation' }
VkBorrowedImage class >> on: aDevice handle: aHandle format: aFormat extent: anExtent usage: usageFlags [
	"The image a swapchain hands out, around the handle it created and with the usage the
	 swapchain asked for."

	^ self new
		  initializeDevice: aDevice
		  handle: aHandle
		  format: aFormat
		  extent: anExtent
		  usage: usageFlags
]

{ #category : 'initialization' }
VkBorrowedImage >> initializeDevice: aDevice handle: aHandle format: aFormat extent: anExtent usage: usageFlags [
	"Nothing is created and nothing is allocated: the handle arrives from its owner, and so
	 does the usage it was created with, which the inspector reads."

	device := aDevice.
	handle := aHandle.
	format := aFormat.
	extent := anExtent.
	usage := usageFlags.
	layout := VkImageLayout undefined
]

{ #category : 'testing' }
VkBorrowedImage >> ownsHandle [
	"The swapchain that created this image destroys it, so teardown here destroys nothing."

	^ false
]
