"
One semaphore a submit batch waits on or signals: the handle, the timeline value, the pipeline stage the wait or the signal applies to, and the device index. Forty-eight bytes, because synchronization2 widened the stage mask to sixty-four bits. This project uses binary semaphores on a single device, so the value and the index stay zero. Built by VkQueue class >> semaphoreSubmitInfoFor:. Key methods: semaphoreSubmitRows, which the Semaphore tab reads.
"
Class {
	#name : 'VkSemaphoreSubmitInfo',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_DEVICEINDEX',
		'OFFSET_PNEXT',
		'OFFSET_SEMAPHORE',
		'OFFSET_STAGEMASK',
		'OFFSET_STYPE',
		'OFFSET_VALUE'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkSemaphoreSubmitInfo class >> exampleWaitOnAFrameSemaphore [
	"One click: the semaphore info a frame's batch carries on either side, built by the
	 recorder's own builder. No device is touched, so the semaphore handle is null and the tab
	 says so; the stage mask is the one the window path really waits at."

	<sampleInstance>
	| info |
	info := VkQueue semaphoreSubmitInfoFor: ExternalAddress null.
	^ [ info copyIntoObjectMemory ] ensure: [ info getHandle free ]
]

{ #category : 'field definition' }
VkSemaphoreSubmitInfo class >> fieldsDesc [
	^ #( int32 sType; void* pNext; VkSemaphore_H* semaphore; uint64 value;
	     uint64 stageMask; uint32 deviceIndex )
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> deviceIndex [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEVICEINDEX
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> deviceIndex: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEVICEINDEX put: anObject
]

{ #category : 'initialization' }
VkSemaphoreSubmitInfo >> initializeConstantFields [
	self sType: VkStructureType semaphoreSubmitInfo
]

{ #category : 'inspector' }
VkSemaphoreSubmitInfo >> inspectorSemaphore: aBuilder [
	"The semaphore of one side of a batch: whether it is set, the stage it synchronises at
	 named by the class that owns the bits, the timeline value and the device index. The rows
	 are read back through the accessors, so opening the tab cannot change the info."

	<inspectorPresentationOrder: 30 title: 'Semaphore'>
	| rows |
	rows := self semaphoreSubmitRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Property' evaluated: [ :each |
					   each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Semaphore set'. (rows at: #semaphoreSet) }.
				  { 'Stage'. (rows at: #stageNames) }.
				  { 'Timeline value'. (rows at: #value) }.
				  { 'Device index'. (rows at: #deviceIndex) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> semaphore [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_SEMAPHORE) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> semaphore: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_SEMAPHORE put: anObject getHandle.
]

{ #category : 'reporting' }
VkSemaphoreSubmitInfo >> semaphoreSubmitRows [
	"The semaphore this side of a batch waits on or signals: whether the handle is set, the
	 stage mask and its names from the class that owns the stage bits, the timeline value and
	 the device index. The names are decoded rather than restated, so the row cannot drift from
	 the mask the builder writes."

	^ Dictionary new
		  at: #semaphoreSet put: self semaphore isNull not;
		  at: #stageMask put: self stageMask;
		  at: #stageNames
		  put: (VkPipelineStage2 nameForFlags: self stageMask);
		  at: #value put: self value;
		  at: #deviceIndex put: self deviceIndex;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> stageMask [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_STAGEMASK
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> stageMask: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_STAGEMASK put: anObject
]

{ #category : 'evaluating' }
VkSemaphoreSubmitInfo >> value [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_VALUE
]

{ #category : 'accessing - structure variables' }
VkSemaphoreSubmitInfo >> value: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_VALUE put: anObject
]
