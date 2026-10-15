"
Wrapper around a VkQueue_H with its queue family index. Submits compute dispatches (submitCompute:) and graphics frames (submitGraphics:waitSemaphore:signalSemaphore:fence:). Also performs waitIdle and present.
"
Class {
	#name : 'VkQueue',
	#superclass : 'Object',
	#instVars : [
		'handle',
		'familyIndex'
	],
	#category : 'PharoVulkan-Graphics',
	#package : 'PharoVulkan',
	#tag : 'Graphics'
}

{ #category : 'constants' }
VkQueue class >> commandBufferInfosPerSubmit [
	"One command buffer per batch, on both the compute and the window path."

	^ 1
]

{ #category : 'structures' }
VkQueue class >> commandBufferSubmitInfoFor: aCommandBufferHandle [
	"The info naming one command buffer inside a batch. The device mask is the zero a fresh
	 block holds, which means the one device this project opens. The caller owns the structure
	 and frees its handle."

	| info |
	info := VkCommandBufferSubmitInfo externalInstance.
	^ info
		  commandBuffer: aCommandBufferHandle;
		  yourself
]

{ #category : 'constants' }
VkQueue class >> graphicsSemaphoreStageMask [
	"The stage every semaphore of a frame's batch waits at and signals from: the colour
	 attachment writes are the frame's work, so waiting earlier would stall nothing useful and
	 signalling later would say the frame was drawn before it was."

	^ VkPipelineStage2 colorAttachmentOutputBit
]

{ #category : 'factory' }
VkQueue class >> on: aHandle familyIndex: idx [
    ^ self new initializeWith: aHandle familyIndex: idx
]

{ #category : 'constants' }
VkQueue class >> semaphoreInfosPerSubmit [
	"One semaphore on each side of a batch that has semaphores at all: the window path waits
	 for one image and signals one finished frame."

	^ 1
]

{ #category : 'structures' }
VkQueue class >> semaphoreSubmitInfoFor: aSemaphoreHandle [
	"The info naming one semaphore a batch waits on or signals, at the stage a frame's work
	 happens. The timeline value and the device index are the zeros a fresh block holds: these
	 are binary semaphores on a single device. The caller owns the structure and frees its
	 handle."

	| info |
	info := VkSemaphoreSubmitInfo externalInstance.
	^ info
		  semaphore: aSemaphoreHandle;
		  stageMask: self graphicsSemaphoreStageMask;
		  yourself
]

{ #category : 'structures' }
VkQueue class >> submitInfoFor: aCommandBufferInfoHandle waitSemaphoreInfo: aWaitInfoOrNil signalSemaphoreInfo: aSignalInfoOrNil [
	"The whole batch: one command buffer, and a semaphore on either side where the caller gives
	 one. A nil semaphore info leaves the count at zero and the pointer null, which is what the
	 compute path submits; the window path gives both. The flags are the zero a fresh block
	 holds, because no batch here is a protected submission. The caller owns the structure and
	 frees its handle."

	| info |
	info := VkSubmitInfo2 externalInstance.
	info
		commandBufferInfoCount: self commandBufferInfosPerSubmit;
		pCommandBufferInfos: aCommandBufferInfoHandle.
	aWaitInfoOrNil ifNotNil: [ :waitInfo |
		info
			waitSemaphoreInfoCount: self semaphoreInfosPerSubmit;
			pWaitSemaphoreInfos: waitInfo getHandle ].
	aSignalInfoOrNil ifNotNil: [ :signalInfo |
		info
			signalSemaphoreInfoCount: self semaphoreInfosPerSubmit;
			pSignalSemaphoreInfos: signalInfo getHandle ].
	^ info
]

{ #category : 'constants' }
VkQueue class >> submitsPerBatch [
	"One submit info per call; a queue can take several batches at once, which no path here
	 needs."

	^ 1
]

{ #category : 'accessing' }
VkQueue >> handle [
    ^ handle
]

{ #category : 'initialization' }
VkQueue >> initializeWith: aHandle familyIndex: idx [
    handle := aHandle. familyIndex := idx
]

{ #category : 'submitting' }
VkQueue >> submit: aCmdBuffer andWait: doWait [
	"Submits one command buffer with no semaphores, and waits for the queue to go idle when
	 asked. This is the compute path: nothing else is in flight, so the idle wait is the whole
	 synchronisation."

	| bufferInfo |
	bufferInfo := self class commandBufferSubmitInfoFor:
		              aCmdBuffer handle getHandle.
	[
	| batch |
	batch := self class
		         submitInfoFor: bufferInfo getHandle
		         waitSemaphoreInfo: nil
		         signalSemaphoreInfo: nil.
	[ self submitBatch: batch fence: ExternalAddress null ] ensure: [
		batch getHandle free ] ] ensure: [ bufferInfo getHandle free ].
	doWait ifTrue: [ self waitIdle ]
]

{ #category : 'submitting' }
VkQueue >> submitBatch: aSubmitInfo fence: aFenceHandle [
	"The one sender of vkQueueSubmit2 in the project. The driver reads the batch and every
	 structure it points at during this call, so the caller keeps them all alive until it
	 returns and frees them afterwards."

	Vk checkResult: (Vk
			 queueSubmit2: handle
			 submitCount: self class submitsPerBatch
			 submits: aSubmitInfo getHandle
			 fence: aFenceHandle)
]

{ #category : 'submitting' }
VkQueue >> submitGraphics: aCommandBuffer waitSemaphore: aWaitSemaphore signalSemaphore: aSignalSemaphore fence: aFence [
	"Submits one frame: waits for the acquired image, draws, signals that the frame is drawn
	 and signals the fence the frame loop waits on. All four structures stay alive until the
	 driver has read the batch, which is what the nested ensure blocks are for."

	| bufferInfo |
	bufferInfo := self class commandBufferSubmitInfoFor:
		              aCommandBuffer handle getHandle.
	[
	| waitInfo |
	waitInfo := self class semaphoreSubmitInfoFor:
		            aWaitSemaphore handle getHandle.
	[
	| signalInfo |
	signalInfo := self class semaphoreSubmitInfoFor:
		              aSignalSemaphore handle getHandle.
	[
	| batch |
	batch := self class
		         submitInfoFor: bufferInfo getHandle
		         waitSemaphoreInfo: waitInfo
		         signalSemaphoreInfo: signalInfo.
	[ self submitBatch: batch fence: aFence handle getHandle ] ensure: [
		batch getHandle free ] ] ensure: [ signalInfo getHandle free ] ]
		ensure: [ waitInfo getHandle free ] ] ensure: [
		bufferInfo getHandle free ]
]

{ #category : 'submitting' }
VkQueue >> waitIdle [
    Vk checkResult: (Vk queueWaitIdle: handle)
]
