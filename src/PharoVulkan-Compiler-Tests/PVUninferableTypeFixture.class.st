"
Kernels whose types PVTypeInferencer cannot infer, used to pin what the compiler does with a DSL method it cannot type. Like PVCfgShapeFixture these are deliberately not in PVKernelExamples: nobody should run them, each one exists only because its type error has a known expected verdict, which is PVTypeError. The selector names the error.
"
Class {
	#name : 'PVUninferableTypeFixture',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler-Tests-Fixtures',
	#package : 'PharoVulkan-Compiler-Tests',
	#tag : 'Fixtures'
}

{ #category : 'type errors' }
PVUninferableTypeFixture >> sendsASelectorWithNoSpirvMapping: x [
	"tan has no entry in PVSelectorTable for an f32 receiver, so inference cannot type the result."

	<gpu>
	<param: #f32 named: #x>
	^ x tan
]

{ #category : 'type errors' }
PVUninferableTypeFixture >> usesAParameterNoPragmaDeclares: aWorkItem data: aBuffer out: anOutput scale: aScale [
	"No <param:> pragma declares aScale, so its register carries no type into inference."

	<gpu>
	<param: #workItem named: #aWorkItem>
	<param: #bufferOf_f32 named: #aBuffer>
	<param: #bufferOf_f32 named: #anOutput>
	anOutput at: aWorkItem x put: aScale + (aBuffer at: aWorkItem x)
]
