"
The examples of SpvSerializer: a serializer that has written one module, so a reader meets it
with its sections already emitted. serializerOfTheStructuredControlFlowModule answers it, and its
Sections tab names the words each section of that module contributed. The module is the one
SpvBuilderExamples builds, so the example reads the module the builder examples and the validator
gate already read rather than a copy of it.
"
Class {
	#name : 'SpvSerializerExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-SPIRV',
	#package : 'PharoVulkan-Examples',
	#tag : 'SPIRV'
}

{ #category : 'examples' }
SpvSerializerExamples class >> serializerOfTheStructuredControlFlowModule [
	"One click: the serializer that wrote the module of the structured control flow example.
	 Open the Sections tab to read how many words each section of that module took."

	<sampleInstance>
	| serializer |
	serializer := SpvSerializer new.
	serializer serializeModule: SpvBuilderExamples structuredControlFlowBuilder module.
	^ serializer
]
