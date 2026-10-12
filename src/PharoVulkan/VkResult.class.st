"
Wraps a raw Vulkan result code (int32). Knows whether it represents success or an error,
and can signal a VkError. Class-side methods provide named constants for all result codes.
Key methods: code, isSuccess, isError, name, signal, withCode: (class-side).
"
Class {
	#name : 'VkResult',
	#superclass : 'Object',
	#instVars : [
		'code'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'ffi' }
VkResult class >> asExternalTypeOn: aFFICallout [
	^ FFIInt32 asExternalTypeOn: aFFICallout
]

{ #category : 'examples' }
VkResult class >> exampleSuboptimalPresentResult [
	"The code a present answers after the window has been resized: not a failure, which is the
	 distinction the Result codes inspector tab makes visible."

	<sampleInstance>
	^ self withCode: self vkSuboptimalKHR
]

{ #category : 'result-codes' }
VkResult class >> nameForCode: anInteger [
	"The Vulkan spelling of a result code, derived from the declaring selectors rather than
	 from a second hand-written table: the table had drifted and answered VK_UNKNOWN for
	 VK_SUBOPTIMAL_KHR, a code this project's swapchain really does receive."

	^ self resultCodeSelectors
		  detect: [ :each | (self perform: each) = anInteger ]
		  ifFound: [ :each | self nameForSelector: each ]
		  ifNone: [ 'VK_UNKNOWN(' , anInteger printString , ')' ]
]

{ #category : 'reflecting' }
VkResult class >> nameForSelector: aSelector [
	"The Vulkan spelling of a declaring selector: vkErrorOutOfDateKHR answers
	 VK_ERROR_OUT_OF_DATE_KHR. A run of capitals is one word, so the KHR suffix does not come
	 back as K_H_R."

	| words current |
	words := OrderedCollection new.
	current := WriteStream on: String new.
	aSelector asString doWithIndex: [ :character :index |
		(character isUppercase and: [
			 index > 1 and: [ (aSelector at: index - 1) isUppercase not ] ]) ifTrue: [
			words add: current contents.
			current := WriteStream on: String new ].
		current nextPut: character asUppercase ].
	words add: current contents.
	^ '_' join: words
]

{ #category : 'reflecting' }
VkResult class >> resultCodeProtocol [

	^ #'result-codes'
]

{ #category : 'reflecting' }
VkResult class >> resultCodeSelectors [
	"The declared codes, selected by protocol and by taking no argument, so nameForCode: and
	 withCode: are left out. Selecting by protocol rather than by performing every candidate
	 follows VkValueConstants, where performing them all would recurse."

	^ (self class selectors select: [ :each |
		   (self class >> each) protocolName = self resultCodeProtocol and: [
			   each numArgs = 0 ] ]) asSortedCollection asArray
]

{ #category : 'result-codes' }
VkResult class >> vkErrorDeviceLost [            ^ -4
]

{ #category : 'result-codes' }
VkResult class >> vkErrorExtensionNotPresent [   ^ -7
]

{ #category : 'result-codes' }
VkResult class >> vkErrorFeatureNotPresent [     ^ -8
]

{ #category : 'result-codes' }
VkResult class >> vkErrorFormatNotSupported [    ^ -11
]

{ #category : 'result-codes' }
VkResult class >> vkErrorIncompatibleDriver [    ^ -9
]

{ #category : 'result-codes' }
VkResult class >> vkErrorInitializationFailed [  ^ -3
]

{ #category : 'result-codes' }
VkResult class >> vkErrorLayerNotPresent [       ^ -6
]

{ #category : 'result-codes' }
VkResult class >> vkErrorMemoryMapFailed [       ^ -5
]

{ #category : 'result-codes' }
VkResult class >> vkErrorNativeWindowInUseKHR [  ^ -1000000001
]

{ #category : 'result-codes' }
VkResult class >> vkErrorOutOfDateKHR [          ^ -1000001004
]

{ #category : 'result-codes' }
VkResult class >> vkErrorOutOfDeviceMemory [     ^ -2
]

{ #category : 'result-codes' }
VkResult class >> vkErrorOutOfHostMemory [       ^ -1
]

{ #category : 'result-codes' }
VkResult class >> vkErrorOutOfPoolMemory [
	"VK_KHR_maintenance1, promoted to core in 1.1; answered when a descriptor set does not
	 fit the pool it is allocated from."
	^ -1000069000
]

{ #category : 'result-codes' }
VkResult class >> vkErrorSurfaceLostKHR [        ^ -1000000000
]

{ #category : 'result-codes' }
VkResult class >> vkErrorTooManyObjects [        ^ -10
]

{ #category : 'result-codes' }
VkResult class >> vkEventReset [          ^ 4
]

{ #category : 'result-codes' }
VkResult class >> vkEventSet [            ^ 3
]

{ #category : 'result-codes' }
VkResult class >> vkIncomplete [          ^ 5
]

{ #category : 'result-codes' }
VkResult class >> vkNotReady [            ^ 1
]

{ #category : 'result-codes' }
VkResult class >> vkSuboptimalKHR [              ^ 1000001003
]

{ #category : 'result-codes' }
VkResult class >> vkSuccess [             ^ 0
]

{ #category : 'result-codes' }
VkResult class >> vkTimeout [             ^ 2
]

{ #category : 'instance creation' }
VkResult class >> withCode: anInteger [
    ^ self new code: anInteger
]

{ #category : 'accessing' }
VkResult >> code [ ^ code
]

{ #category : 'private' }
VkResult >> code: anInteger [
    code := anInteger
]

{ #category : 'inspecting' }
VkResult >> inspectorResultCodes: aBuilder [
	"Every code VkResult declares, with the name and the error verdict asked of the real rules
	 rather than restated, and the inspected code marked. Each row is a fresh VkResult, so
	 nothing here touches the code being inspected."

	<inspectorPresentationOrder: 10 title: 'Result codes'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn
				   title: 'Name'
				   evaluated: [ :each | each name ]);
		  addColumn: (SpStringTableColumn
				   title: 'Code'
				   evaluated: [ :each | each code printString ]);
		  addColumn: (SpStringTableColumn
				   title: 'Error'
				   evaluated: [ :each | each isError ifTrue: [ 'yes' ] ifFalse: [ 'no' ] ]);
		  addColumn: (SpStringTableColumn
				   title: 'This one'
				   evaluated: [ :each |
					   each code = code
						   ifTrue: [ 'yes' ]
						   ifFalse: [ '' ] ]);
		  items: (self class resultCodeSelectors collect: [ :selector |
					   self class withCode: (self class perform: selector) ]);
		  yourself
]

{ #category : 'testing' }
VkResult >> isError [ ^ code < 0
]

{ #category : 'testing' }
VkResult >> isSuccess [ ^ code = VkResult vkSuccess
]

{ #category : 'accessing' }
VkResult >> name [
    ^ VkResult nameForCode: code
]

{ #category : 'printing' }
VkResult >> printOn: aStream [
    aStream nextPutAll: 'VkResult('; nextPutAll: self name; nextPut: $)
]

{ #category : 'error handling' }
VkResult >> signal [
    VkError new
        result: self;
        signal
]
