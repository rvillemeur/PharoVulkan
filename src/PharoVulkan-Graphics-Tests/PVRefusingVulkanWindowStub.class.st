"
I am a Vulkan backend window whose SDL call refuses, used to show that
requiredInstanceExtensions raises when SDL_Vulkan_GetInstanceExtensions says no. SDL answers a
boolean there, and it answers true for every window a test can build, so a refusal cannot be
provoked by the arguments: I answer false myself, for the call the test names in refusedCall,
and answer true for the other one after writing the count the real call would have written.

Key methods: refusedCall:, instanceExtensionsInto:names:, callCount.
"
Class {
	#name : 'PVRefusingVulkanWindowStub',
	#superclass : 'OSSDL2VulkanBackendWindow',
	#instVars : [
		'refusedCall',
		'callCount'
	],
	#category : 'PharoVulkan-Graphics-Tests-Fixtures',
	#package : 'PharoVulkan-Graphics-Tests',
	#tag : 'Fixtures'
}

{ #category : 'accessing' }
PVRefusingVulkanWindowStub >> callCount [
	^ callCount ifNil: [ 0 ]
]

{ #category : 'vulkan' }
PVRefusingVulkanWindowStub >> instanceExtensionsInto: aCountAddress names: aNamesAddress [
	"The seam the real window makes the SDL call through. The first call asks for the count and
	 the second for the names, which is how the refused one is told from the other."

	| wanted |
	callCount := self callCount + 1.
	wanted := callCount = 1
		          ifTrue: [ #count ]
		          ifFalse: [ #names ].
	refusedCall = wanted ifTrue: [ ^ false ].
	wanted = #count ifTrue: [ aCountAddress unsignedLongAt: 1 put: 1 ].
	^ true
]

{ #category : 'initialization' }
PVRefusingVulkanWindowStub >> refusedCall: aSymbol [
	"Which of the two calls of requiredInstanceExtensions answers false: #count or #names."

	refusedCall := aSymbol.
	callCount := 0
]
