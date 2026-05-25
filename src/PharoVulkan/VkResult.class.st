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

{ #category : 'result-codes' }
VkResult class >> nameForCode: anInteger [
    "Returns a human-readable name for the given Vulkan result code."
    | table |
    table := Dictionary new.
    table at: self vkSuccess put: 'VK_SUCCESS'.
    table at: self vkNotReady put: 'VK_NOT_READY'.
    table at: self vkTimeout put: 'VK_TIMEOUT'.
    table at: self vkEventSet put: 'VK_EVENT_SET'.
    table at: self vkEventReset put: 'VK_EVENT_RESET'.
    table at: self vkIncomplete put: 'VK_INCOMPLETE'.
    table at: self vkErrorOutOfHostMemory put: 'VK_ERROR_OUT_OF_HOST_MEMORY'.
    table at: self vkErrorOutOfDeviceMemory put: 'VK_ERROR_OUT_OF_DEVICE_MEMORY'.
    table at: self vkErrorInitializationFailed put: 'VK_ERROR_INITIALIZATION_FAILED'.
    table at: self vkErrorDeviceLost put: 'VK_ERROR_DEVICE_LOST'.
    table at: self vkErrorLayerNotPresent put: 'VK_ERROR_LAYER_NOT_PRESENT'.
    table at: self vkErrorExtensionNotPresent put: 'VK_ERROR_EXTENSION_NOT_PRESENT'.
    table at: self vkErrorIncompatibleDriver put: 'VK_ERROR_INCOMPATIBLE_DRIVER'.
    table at: self vkErrorSurfaceLostKHR put: 'VK_ERROR_SURFACE_LOST_KHR'.
    table at: self vkErrorOutOfDateKHR put: 'VK_ERROR_OUT_OF_DATE_KHR'.
    ^ table at: anInteger ifAbsent: [ 'VK_UNKNOWN(' , anInteger printString , ')' ]
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
