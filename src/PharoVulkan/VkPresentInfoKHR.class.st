"
The request vkQueuePresentKHR reads: which semaphores the present waits on, which swapchains it carries, which image of each is ready, and where the driver should write a result code per swapchain. Sixty-four bytes, with every list pointed at rather than carried, so each pointer field is one pointer wide however many entries sit behind it.

Only VkSwapchain class >> presentInfoForSwapchain:imageIndex:waitSemaphore: fills it, and only VkSwapchain >> present:queue:waitSemaphore: hands it to the driver. The request owns the three runs of one entry it points at, so VkSwapchain class >> freePresentInfo: gives them back through it: the request is the only record of where they are. No run of per-swapchain results is asked for, because a present of one swapchain learns everything from the code the call itself answers. presentRows is what the Present tab reads; it reports each run as there or not rather than following it, because a run's address says nothing to a reader and the example clears its runs before it is kept.
"
Class {
	#name : 'VkPresentInfoKHR',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_PIMAGEINDICES',
		'OFFSET_PNEXT',
		'OFFSET_PRESULTS',
		'OFFSET_PSWAPCHAINS',
		'OFFSET_PWAITSEMAPHORES',
		'OFFSET_STYPE',
		'OFFSET_SWAPCHAINCOUNT',
		'OFFSET_WAITSEMAPHORECOUNT'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPresentInfoKHR class >> fieldsDesc [
	"A count and a run for the semaphores the present waits on, a count and a run for the
	 swapchains, one image index per swapchain, and an optional run of per-swapchain results.
	 Every run is an array rather than a single structure, so each is declared void* and
	 walked by a named stride; uFFI pads after each count."

	^ #( int32 sType; void* pNext; uint32 waitSemaphoreCount;
	     void* pWaitSemaphores; uint32 swapchainCount; void* pSwapchains;
	     void* pImageIndices; void* pResults )
]

{ #category : 'initialization' }
VkPresentInfoKHR >> initializeConstantFields [
	"The structure type is the one field every present request of this kind carries. Both
	 counts and all three runs are the caller's, so none is written here."

	self sType: VkStructureType presentInfoKHR
]

{ #category : 'inspector' }
VkPresentInfoKHR >> inspectorPresent: aBuilder [
	"What the driver is asked to present, rather than where the fields sit: the Layout and
	 Fields tabs answer that. The rows come from presentRows, which only reads and never
	 follows a run, so opening the tab changes nothing and cannot read memory already given
	 back."

	<inspectorPresentationOrder: 30 title: 'Present'>
	| rows |
	rows := self presentRows.
	^ aBuilder newTable
		  addColumn:
			  (SpStringTableColumn title: 'Presents' evaluated: [ :each | each first ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
				   each second printString ]);
		  items: {
				  { 'Semaphores waited on'. (rows at: #waitSemaphoreCount) }.
				  { 'Semaphore run given'. (rows at: #waitsOnASemaphore) }.
				  { 'Swapchains'. (rows at: #swapchainCount) }.
				  { 'Swapchain run given'. (rows at: #swapchainGiven) }.
				  { 'Image index run given'. (rows at: #imageIndexGiven) }.
				  { 'Per-swapchain results asked for'. (rows at: #resultsRequested) } };
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pImageIndices [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PIMAGEINDICES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pImageIndices: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PIMAGEINDICES put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pNext [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PNEXT) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pNext: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PNEXT put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pResults [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PRESULTS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pResults: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PRESULTS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pSwapchains [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PSWAPCHAINS) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pSwapchains: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PSWAPCHAINS put: anObject getHandle.
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pWaitSemaphores [
	"This method was automatically generated"
	^ExternalData fromHandle: (handle pointerAt: OFFSET_PWAITSEMAPHORES) type: ExternalType void asPointerType
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> pWaitSemaphores: anObject [
	"This method was automatically generated"
	handle pointerAt: OFFSET_PWAITSEMAPHORES put: anObject getHandle.
]

{ #category : 'reporting' }
VkPresentInfoKHR >> presentRows [
	"What the driver is asked to present: how many semaphores the present waits on and how
	 many swapchains it carries, whether each of the three runs is there, and whether a run of
	 per-swapchain results was asked for. The runs are reported as present or absent rather
	 than followed: their addresses say nothing to a reader, and an example clears them before
	 it is kept, so a row that read through one would read freed memory. Read only, so a view
	 built from this leaves the store alone."

	^ Dictionary new
		  at: #waitSemaphoreCount put: self waitSemaphoreCount;
		  at: #waitsOnASemaphore put: self pWaitSemaphores isNull not;
		  at: #swapchainCount put: self swapchainCount;
		  at: #swapchainGiven put: self pSwapchains isNull not;
		  at: #imageIndexGiven put: self pImageIndices isNull not;
		  at: #resultsRequested put: self pResults isNull not;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> sType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_STYPE
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> sType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_STYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> swapchainCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SWAPCHAINCOUNT
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> swapchainCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SWAPCHAINCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> waitSemaphoreCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_WAITSEMAPHORECOUNT
]

{ #category : 'accessing - structure variables' }
VkPresentInfoKHR >> waitSemaphoreCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_WAITSEMAPHORECOUNT put: anObject
]
