"
Examples of the SPIR-V types that carry a shape rather than a width: the cooperative matrix shape this machine reports, and the accumulator type of one subgroup built from it.

Both are built in the image out of what the driver reported, so they can be read on a machine whose driver offers no cooperative matrix support — the shape then answers what that machine actually reports, which is the point of reading it.
"
Class {
	#name : 'SpvTypeExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-SPIRV',
	#package : 'PharoVulkan-Examples',
	#tag : 'SPIRV'
}

{ #category : 'examples' }
SpvTypeExamples class >> accumulatorTypeOfOneSubgroup [
	"One click: the accumulator type the cooperative matrix kernel uses, registered in a
	 fresh module so its id and its operand constants are real. The Instruction tab shows
	 the words it serialises to."

	<sampleInstance>
	| builder |
	builder := SpvBuilder new.
	^ builder types
		  cooperativeMatrixType: (builder types floatType: 32)
		  shape: (SpvCooperativeMatrixShape
				   rows: PVCooperativeMatrixKernel matrixOrder
				   columns: PVCooperativeMatrixKernel matrixOrder
				   scope: SpvScope subgroup
				   use: SpvCooperativeMatrixType matrixAccumulatorUse)
]

{ #category : 'examples' }
SpvTypeExamples class >> cooperativeMatrixShapeThisMachineReports [
	"One click: the shape a device here really offers, taken from the first configuration
	 vkGetPhysicalDeviceCooperativeMatrixPropertiesKHR reports, as the A operand of a
	 multiply-accumulate. Answers nil where no device offers the extension, which is the
	 honest answer on such a machine."

	<sampleInstance>
	| configuration |
	configuration := PVCooperativeMatrixExamples
		                 firstConfigurationOfferedHere.
	configuration ifNil: [ ^ nil ].
	^ SpvCooperativeMatrixShape
		  rows: configuration mSize
		  columns: configuration kSize
		  scope: configuration scope
		  use: SpvCooperativeMatrixType matrixAUse
]
