"
Test stub standing in for a device that reports no subgroup arithmetic: available always answers false, so the refusal path of PVSubgroupDotProduct can be tested on a machine whose driver does support the operations, without touching production code.
"
Class {
	#name : 'PVNoSubgroupArithmeticStub',
	#superclass : 'PVSubgroupDotProduct',
	#category : 'PharoVulkan-Tests-Compute',
	#package : 'PharoVulkan-Tests',
	#tag : 'Compute'
}

{ #category : 'querying' }
PVNoSubgroupArithmeticStub >> available [
	"The device this stub stands for lacks the arithmetic, whatever the driver under it says."

	^ false
]
