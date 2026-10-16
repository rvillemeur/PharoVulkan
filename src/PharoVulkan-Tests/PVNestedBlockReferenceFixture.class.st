"
A class that names a class of another package from inside a block three levels deep, so that
PVArchitectureTest can state that its scan reads blocks as well as methods. The reference is
deliberate and is declared in the allowed set of this package: a scan that reads only a method's
own literals misses it, which is how the first scan of this project missed 86 edges.
"
Class {
	#name : 'PVNestedBlockReferenceFixture',
	#superclass : 'Object',
	#category : 'PharoVulkan-Tests-Fixtures',
	#package : 'PharoVulkan-Tests',
	#tag : 'Fixtures'
}

{ #category : 'planted reference' }
PVNestedBlockReferenceFixture >> reachThroughThreeBlocks [
	"Answers the name of a class this method never names outside a block. Nothing sends this
	 method but the test that scans it."

	^ [ [ [ VkDevice name ] value ] value ] value
]
