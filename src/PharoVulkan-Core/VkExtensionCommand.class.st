"
A Vulkan command the loader does not export as a symbol, reached through vkGetInstanceProcAddr instead.

libvulkan.so.1 exports the core entry points and a handful of KHR ones; an extension command such as vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR is not among them, so a uFFI declaration naming the symbol cannot link. This class resolves the address once for a given instance and calls through it.

Key methods: on:named: resolves, isAvailable answers whether the loader knew the name, and callWithArguments:parameterTypes:returnType: performs the call, raising VkError rather than jumping to address zero when the command is not there.
"
Class {
	#name : 'VkExtensionCommand',
	#superclass : 'Object',
	#instVars : [
		'name',
		'address'
	],
	#category : 'PharoVulkan-Core-Device',
	#package : 'PharoVulkan-Core',
	#tag : 'Device'
}

{ #category : 'instance creation' }
VkExtensionCommand class >> on: anInstanceHandle named: aCommandName [
	"Resolve the command once. The name is passed as a C string the caller owns, which is
	 why it is freed here rather than left to the collector."

	| cString |
	cString := Vk allocateCString: aCommandName.
	^ [
	  self new
		  setName: aCommandName
		  address: (Vk primGetInstanceProcAddr: anInstanceHandle name: cString) ]
		  ensure: [ cString free ]
]

{ #category : 'accessing' }
VkExtensionCommand class >> runner [
	"The runner the project's own uFFI calls already go through, asked for rather than chosen
	 here, so an extension command cannot run on a different thread from vkCreateDevice."
	^ Vk ffiLibrary uniqueInstance runner
]

{ #category : 'constants' }
VkExtensionCommand class >> threadedTypeFor: aTypeSymbol [
	^ self threadedTypes
		  at: aTypeSymbol
		  ifAbsent: [
			  VkError signal:
				  'No ThreadedFFI type for ' , aTypeSymbol printString ]
]

{ #category : 'constants' }
VkExtensionCommand class >> threadedTypes [
	"The ThreadedFFI type for each type symbol a Vulkan extension command uses here. A
	 symbol outside this table raises rather than defaulting, because a wrong argument
	 width on a call through a raw pointer corrupts the stack silently."

	^ Dictionary newFrom: {
			  (#int32 -> TFBasicType sint).
			  (#uint32 -> TFBasicType uint).
			  (#pointer -> TFBasicType pointer).
			  (#void -> TFBasicType void) }
]

{ #category : 'accessing' }
VkExtensionCommand >> address [
	^ address
]

{ #category : 'calling' }
VkExtensionCommand >> callWithArguments: anArray parameterTypes: typeSymbols returnType: aReturnTypeSymbol [
	"Call through the resolved address. An unresolved command raises here, because calling
	 address zero would take the image down instead of failing."
	| function arguments |
	self isAvailable ifFalse: [
		VkError signal: 'Vulkan command not offered by the loader: ' , name ].
	function := TFExternalFunction
		            fromAddress: address
		            definition: (TFFunctionDefinition
				             parameterTypes:
				             (typeSymbols collect: [ :each |
						              self class threadedTypeFor: each ])
				             returnType: (self class threadedTypeFor: aReturnTypeSymbol)).
	arguments := anArray
		             with: typeSymbols
		             collect: [ :argument :type | self marshal: argument as: type ].
	^ self class runner invokeFunction: function withArguments: arguments
]

{ #category : 'testing' }
VkExtensionCommand >> isAvailable [
	"The loader answers a null pointer for a name it does not know, which is the only
	 signal that an extension command is absent."

	^ address notNil and: [ address isNull not ]
]

{ #category : 'private' }
VkExtensionCommand >> marshal: anArgument as: aTypeSymbol [
	"ThreadedFFI takes a pointer as an ExternalAddress, not as one of the VkHandle wrappers
	 the bindings pass around, so a pointer argument is asked for its address first."
	^ aTypeSymbol = #pointer
		  ifTrue: [ anArgument getHandle ]
		  ifFalse: [ anArgument ]
]

{ #category : 'accessing' }
VkExtensionCommand >> name [
	^ name
]

{ #category : 'initialization' }
VkExtensionCommand >> setName: aCommandName address: anAddress [
	name := aCommandName.
	address := anAddress
]
