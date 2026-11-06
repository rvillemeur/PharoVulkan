"
One shape PVStructuredCFGRecognizer matches, and the single place that says what happens when a target has no emitter for that shape. A target method of PVKernelCompiler sends emitKernelWith:, emitComputeKernelWith: or emitShaderWith:executionModel: to the node it recognised; a subclass overrides the ones its shape can be emitted as, and inherits the refusal for the rest. Adding a shape means adding a subclass and the emitters it has, not a branch in four cascades.
"
Class {
	#name : 'PVStructuredNode',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler-Graph',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Graph'
}

{ #category : 'emitting' }
PVStructuredNode >> classHoldingTheRefusals [
	"The class that implements refuseFor: is the one whose emitters are the refusals, so an
	 emitter still found there is one no subclass overrode. Asked rather than named, so this
	 keeps working if the hierarchy gains a level."

	^ (self class lookupSelector: #refuseFor:) methodClass
]

{ #category : 'accessing' }
PVStructuredNode >> coveredBlocks [
	"The recogniser's coverage check reads this to refuse a graph holding anything beyond the
	 shape matched."

	^ self subclassResponsibility
]

{ #category : 'emitting' }
PVStructuredNode >> emitComputeKernelWith: aCompiler [
	"Refused by default: a shape is emitted only by a target that has an emitter for it."

	^ self refuseFor: 'compute kernel'
]

{ #category : 'emitting' }
PVStructuredNode >> emitKernelWith: aCompiler [
	"Refused by default: a shape is emitted only by a target that has an emitter for it."

	^ self refuseFor: 'kernel'
]

{ #category : 'emitting' }
PVStructuredNode >> emitShaderWith: aCompiler executionModel: anExecutionModel [
	"Refused by default: a shape is emitted only by a target that has an emitter for it."

	^ self refuseFor: 'shader'
]

{ #category : 'emitting' }
PVStructuredNode >> emitterSelectorsByTarget [
	"The three targets a shape can be emitted for, each with the selector its emitter
	 answers to. Read by targetRows, so the tab cannot name a target the dispatch does not
	 have."

	^ {
		  'Kernel' -> #emitKernelWith:.
		  'Compute kernel' -> #emitComputeKernelWith:.
		  'Shader' -> #emitShaderWith:executionModel: }
]

{ #category : 'inspecting' }
PVStructuredNode >> inspectorTargets: aBuilder [
	"Reading a recognised node, the question is which targets can emit it: a shape with no
	 emitter for the target in hand is the refusal PVKernelCompiler reports."

	<inspectorPresentationOrder: 30 title: 'Targets'>
	^ PVFactRow
		  tableOf: self targetRows
		  nameColumn: 'Target'
		  valueColumn: 'Emitted'
		  in: aBuilder
]

{ #category : 'emitting' }
PVStructuredNode >> refuseFor: aTargetName [
	"Names the shape the recogniser matched. Without it the failure reads as a missing
	 register inside the emitter."

	^ PVTypeError signal:
		  'Unrecognized control flow node: ' , self class name , ' in a ' , aTargetName
]

{ #category : 'emitting' }
PVStructuredNode >> targetRows [
	"Which targets emit this shape, asked of the class: a subclass that overrides the
	 emitter has one, and one that inherits the refusal does not."

	^ self emitterSelectorsByTarget collect: [ :each |
		  PVFactRow
			  name: each key
			  value: ((self class lookupSelector: each value) methodClass
					   = self classHoldingTheRefusals
					   ifTrue: [ 'no' ]
					   ifFalse: [ 'yes' ]) ]
]
