"
Raised when a Vulkan API call returns a non-success VkResult code.
Key methods: result (the VkResult that caused the error), messageText.
"
Class {
	#name : 'VkError',
	#superclass : 'Error',
	#instVars : [
		'result'
	],
	#category : 'PharoVulkan-Bindings-Exceptions',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Exceptions'
}

{ #category : 'accessing' }
VkError >> messageText [
	"A VkError either carries a VkResult code or a plain explanation. Without this fallback
	 every error signalled with a text raised a second error on being described, because
	 nil has no name."
	^ result
		  ifNil: [ super messageText ]
		  ifNotNil: [ 'Vulkan error: ' , result name ]
]

{ #category : 'accessing' }
VkError >> result [
    ^ result
]

{ #category : 'accessing' }
VkError >> result: aVkResult [
    result := aVkResult
]
