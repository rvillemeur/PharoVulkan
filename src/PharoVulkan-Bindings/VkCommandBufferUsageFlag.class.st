"
The `VkCommandBufferUsageFlagBits`, with `namedBits` so the Buffer tab can name a mask instead of printing it. `oneTimeSubmitBit` is the one every recording here asks for: a buffer is re-recorded before it is submitted again, so the driver may keep nothing for a resubmission. `renderPassContinueBit` and `simultaneousUseBit` are named for completeness — the first belongs to a secondary buffer, the second to a buffer resubmitted while an earlier submission is still pending, and this project records neither.
"
Class {
	#name : 'VkCommandBufferUsageFlag',
	#superclass : 'VkFlagConstants',
	#category : 'PharoVulkan-Bindings-Constants',
	#package : 'PharoVulkan-Bindings',
	#tag : 'Constants'
}

{ #category : 'decoding' }
VkCommandBufferUsageFlag class >> namedBits [
	^ {
		  (self oneTimeSubmitBit -> 'OneTimeSubmit').
		  (self renderPassContinueBit -> 'RenderPassContinue').
		  (self simultaneousUseBit -> 'SimultaneousUse') }
]

{ #category : 'constants' }
VkCommandBufferUsageFlag class >> oneTimeSubmitBit [
	"VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT: the recording is submitted once and then
	 thrown away, which lets the driver keep nothing for a re-submission. Every recording in
	 this project is re-recorded before it is submitted again."

	^ 1
]

{ #category : 'constants' }
VkCommandBufferUsageFlag class >> renderPassContinueBit [
	"VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT: a secondary buffer recorded inside a
	 render pass its primary buffer began."

	^ 2
]

{ #category : 'constants' }
VkCommandBufferUsageFlag class >> simultaneousUseBit [
	"VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT: the buffer may be resubmitted while an
	 earlier submission of it is still pending."

	^ 4
]
