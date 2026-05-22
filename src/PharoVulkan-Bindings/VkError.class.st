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
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'accessing' }
VkError >> messageText [
    ^ 'Vulkan error: ' , result name
]

{ #category : 'accessing' }
VkError >> result [
    ^ result
]

{ #category : 'accessing' }
VkError >> result: aVkResult [
    result := aVkResult
]
