"
A batch of work submitted to a queue under synchronization2: three count-and-pointer pairs, one for the semaphores waited on, one for the command buffers run and one for the semaphores signalled. Sixty-four bytes. The compute path submits one command buffer and no semaphore; the window path adds one semaphore on each side. Built by VkQueue class >> submitInfoFor:waitSemaphoreInfo:signalSemaphoreInfo: and handed to the driver by VkQueue >> submitBatch:fence:. Key methods: submitRows, which the Batch tab reads.
"
Class {
	#name : 'VkSubmitInfo2',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_COMMANDBUFFERINFOCOUNT',
		'OFFSET_FLAGS',
		'OFFSET_PCOMMANDBUFFERINFOS',
		'OFFSET_PNEXT',
		'OFFSET_PSIGNALSEMAPHOREINFOS',
		'OFFSET_PWAITSEMAPHOREINFOS',
		'OFFSET_SIGNALSEMAPHOREINFOCOUNT',
		'OFFSET_STYPE',
		'OFFSET_WAITSEMAPHOREINFOCOUNT'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkSubmitInfo2 class >> fieldsDesc [
	^ #( int32 sType; void* pNext; uint32 flags;
	     uint32 waitSemaphoreInfoCount; void* pWaitSemaphoreInfos;
	     uint32 commandBufferInfoCount; void* pCommandBufferInfos;
	     uint32 signalSemaphoreInfoCount; void* pSignalSemaphoreInfos )
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> commandBufferInfoCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_COMMANDBUFFERINFOCOUNT
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> commandBufferInfoCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_COMMANDBUFFERINFOCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> flags [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FLAGS
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> flags: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FLAGS put: anObject
]

{ #category : 'initialization' }
VkSubmitInfo2 >> initializeConstantFields [
	self sType: VkStructureType submitInfo2
]

{ #category : 'inspector' }
VkSubmitInfo2 >> inspectorBatch: aBuilder [
	"What this batch asks of the queue: the flags, and the count and pointer state of the
	 semaphores waited on, the command buffers run and the semaphores signalled. The rows are
	 read back through the accessors, so opening the tab cannot change the batch, and no
	 pointer is followed."

	<inspectorPresentationOrder: 30 title: 'Batch'>
	| rows |
	rows := self submitRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Flags'. (rows at: #flagNames) }.
				  { 'Waits on semaphores'. (rows at: #waitSemaphoreInfoCount) }.
				  { 'Wait infos set'. (rows at: #waitSemaphoreInfosSet) }.
				  { 'Command buffers'. (rows at: #commandBufferInfoCount) }.
				  { 'Command buffer infos set'.
				  (rows at: #commandBufferInfosSet) }.
				  { 'Signals semaphores'. (rows at: #signalSemaphoreInfoCount) }.
				  { 'Signal infos set'. (rows at: #signalSemaphoreInfosSet) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pCommandBufferInfos [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PCOMMANDBUFFERINFOS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pCommandBufferInfos: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PCOMMANDBUFFERINFOS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pSignalSemaphoreInfos [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSIGNALSEMAPHOREINFOS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pSignalSemaphoreInfos: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSIGNALSEMAPHOREINFOS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pWaitSemaphoreInfos [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PWAITSEMAPHOREINFOS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> pWaitSemaphoreInfos: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PWAITSEMAPHOREINFOS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> signalSemaphoreInfoCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SIGNALSEMAPHOREINFOCOUNT
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> signalSemaphoreInfoCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SIGNALSEMAPHOREINFOCOUNT put: anObject
]

{ #category : 'reporting' }
VkSubmitInfo2 >> submitRows [
	"What this batch carries: the flags named by the class that owns the bits, and for each of
	 the three kinds of info its count and whether the pointer beside the count is set. The
	 pointers are reported as set or not rather than followed: a batch is freed as soon as the
	 driver has read it, and the infos it pointed at go with it."

	^ Dictionary new
		  at: #flags put: self flags;
		  at: #flagNames put: (VkSubmitFlag nameForFlags: self flags);
		  at: #waitSemaphoreInfoCount put: self waitSemaphoreInfoCount;
		  at: #waitSemaphoreInfosSet
		  put: self pWaitSemaphoreInfos isNull not;
		  at: #commandBufferInfoCount put: self commandBufferInfoCount;
		  at: #commandBufferInfosSet
		  put: self pCommandBufferInfos isNull not;
		  at: #signalSemaphoreInfoCount put: self signalSemaphoreInfoCount;
		  at: #signalSemaphoreInfosSet
		  put: self pSignalSemaphoreInfos isNull not;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> waitSemaphoreInfoCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_WAITSEMAPHOREINFOCOUNT
]

{ #category : 'accessing - structure variables' }
VkSubmitInfo2 >> waitSemaphoreInfoCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_WAITSEMAPHOREINFOCOUNT put: anObject
]
