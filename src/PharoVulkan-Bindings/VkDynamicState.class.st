"
Which parts of a pipeline are set while a command buffer is recorded rather than when the pipeline is built, one constant per state. Only the two rectangles this project sets are named; VkValueConstants answers nil for a value no constant here carries, so a view shows the raw number rather than a wrong name.
"
Class {
	#name : 'VkDynamicState',
	#superclass : 'VkValueConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'reflecting' }
VkDynamicState class >> constantProtocol [

	^ 'constants'
]

{ #category : 'constants' }
VkDynamicState class >> scissor [
	"The scissor rectangle is set while the command buffer is recorded, for the same reason as
	 the viewport: the target's extent is known then and not before."

	^ 1
]

{ #category : 'constants' }
VkDynamicState class >> viewport [
	"The viewport rectangle is set while the command buffer is recorded rather than when the
	 pipeline is built, so one pipeline draws into a target of any size."

	^ 0
]
