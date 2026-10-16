"
Examples of the cooperative matrix path: the first configuration this driver offers, the survey of every configuration it offers, the compiled cooperative matrix module, the product it computes on this machine, the product of the host twin that the device result is checked against, and the comparison of the two.

The host twin is the reason this group exists. A cooperative matrix product is only trustworthy if something computed the same product another way, so the twin example answers the reference and the comparison example answers both together. On a driver that offers no cooperative matrix configuration the survey answers empty and the kernel examples raise, which is the correct report of such a machine.
"
Class {
	#name : 'PVCooperativeMatrixExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Compute',
	#package : 'PharoVulkan-Examples',
	#tag : 'Compute'
}

{ #category : 'examples' }
PVCooperativeMatrixExamples class >> cooperativeMatrixComparisonOnThisMachine [
	"One click: the same product run from the hand-built module and from the module the
	 DSL compiles, on whichever device here offers cooperative matrix. Answers an unrun
	 comparison where no device offers the extension, which is what the inspector should
	 show on such a machine rather than a row of zeros."

	<sampleInstance>
	| context |
	context := [ VkContext cooperativeMatrixContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ PVCooperativeMatrixComparison new ].
	^ [ (PVCooperativeMatrixComparison on: context) run ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVCooperativeMatrixExamples class >> cooperativeMatrixModule [
	"One click: the hand-built cooperative matrix module. Its Module tab says what the bytes
	 declare, and spirv-val accepts them; running it needs a device that offers the
	 extension, which exampleCooperativeMatrixProductOnThisMachine looks for."

	<sampleInstance>
	| kernel |
	kernel := PVCooperativeMatrixKernel new.
	kernel spirv.
	^ kernel
]

{ #category : 'examples' }
PVCooperativeMatrixExamples class >> cooperativeMatrixProductOnThisMachine [
	"One click: an eight by eight product computed by cooperative matrix instructions on
	 whichever device here offers them, as floats. The left matrix is a ramp and the right
	 one the identity, so the answer reads back as the ramp. Answers nil where no device
	 offers the extension, which is the honest result on such a machine."

	<sampleInstance>
	| context |
	context := [ VkContext cooperativeMatrixContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ nil ].
	^ [
	  PVCooperativeMatrixKernel new
		  productOf: PVCooperativeMatrixKernel exampleRampMatrix
		  by: PVCooperativeMatrixKernel exampleIdentityMatrix
		  on: context ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVCooperativeMatrixExamples class >> firstConfigurationOfferedHere [
	"One click: the first cooperative matrix configuration any device on this machine offers.
	 Answers nil on a machine where no device reports the extension, which is a fact about
	 the machine rather than a failure. The Members tab shows what a kernel would have to
	 match exactly."
	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [
	  ((Vk enumeratePhysicalDevices: context instance)
		   inject: OrderedCollection new
		   into: [ :all :handle |
			   all
				   addAll: ((VkPhysicalDevice on: handle)
						    cooperativeMatrixConfigurationsOn: context instance);
				   yourself ]) ifNotEmpty: [ :all | all first ] ifEmpty: [ nil ] ]
		  ensure: [ context destroy ]
]

{ #category : 'examples' }
PVCooperativeMatrixExamples class >> productOfTheHostTwin [
	"One click: the eight by eight product the DSL kernel computes, worked out in the
	 image rather than on a device. The left matrix is a ramp and the right one the
	 identity, so the product reads back as the ramp."

	<sampleInstance>
	| order ramp identity |
	order := PVCooperativeMatrixKernel matrixOrder.
	ramp := PVCooperativeMatrixKernel exampleRampMatrix coopMatLoad: 0.
	identity := PVCooperativeMatrixKernel exampleIdentityMatrix coopMatLoad: 0.
	^ ramp coopMatMulAdd: identity
]

{ #category : 'examples' }
PVCooperativeMatrixExamples class >> surveyOfThisMachine [
	"One click: which devices on this machine report VK_KHR_cooperative_matrix, and why the
	 cooperative matrix path is skipped. The survey reads everything while the context is
	 alive, so the Cooperative matrix tab still answers after the context is destroyed."

	<sampleInstance>
	| context |
	context := VkContext computeContext.
	^ [ PVCooperativeMatrixSurvey on: context ] ensure: [ context destroy ]
]
