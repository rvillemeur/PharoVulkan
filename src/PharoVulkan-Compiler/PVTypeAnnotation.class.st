"
Parsed representation of a <gpu> or type pragma on a kernel method. Carries the execution model and any extra type constraints needed by PVTypeInferencer.
"
Class {
	#name : 'PVTypeAnnotation',
	#superclass : 'Object',
	#instVars : [
		'isGPU',
		'params',
		'shaderKind',
		'outputs',
		'localSize'
	],
	#category : 'PharoVulkan-Compiler-Annotations',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Annotations'
}

{ #category : 'constants' }
PVTypeAnnotation class >> defaultLocalSize [
	"The workgroup shape of a kernel that carries no <localSize:> pragma: 64 invocations
	 along x, which is what every compute kernel written before the pragma assumed."

	^ #( 64 1 1 )

]

{ #category : 'factory' }
PVTypeAnnotation class >> fromMethod: aCompiledMethod [
	| ann |
	ann := self new.
	ann isGPU: false.
	ann params: OrderedCollection new.
	ann outputs: OrderedCollection new.
	ann shaderKind: #compute.
	ann localSize: self defaultLocalSize.
	aCompiledMethod pragmas do: [ :each | ann applyPragma: each ].
	^ ann

]

{ #category : 'constants' }
PVTypeAnnotation class >> paramKind [
	"The kind every parameter the host binds carries."

	^ #param
]

{ #category : 'constants' }
PVTypeAnnotation class >> sharedKind [
	"The kind marking a parameter that stands for a shared array rather than for something
	 the host binds. One name, so the annotation and the emitter cannot disagree."

	^ #shared
]

{ #category : 'initialization' }
PVTypeAnnotation >> applyPragma: aPragma [
	"One pragma of a kernel method. Unknown pragmas are ignored: a method may carry
	 pragmas that have nothing to do with the GPU."

	| keyword |
	keyword := aPragma keyword.
	keyword = #gpu ifTrue: [ ^ self beGpuOfKind: #compute ].
	keyword = #gpuVertex ifTrue: [ ^ self beGpuOfKind: #vertex ].
	keyword = #gpuFragment ifTrue: [ ^ self beGpuOfKind: #fragment ].
	keyword = #localSize: ifTrue: [ ^ self localSize: (aPragma argumentAt: 1) ].
	keyword = #param:named: ifTrue: [
		^ params add: (PVParamAnnotation
				   kind: self class paramKind
				   type: (aPragma argumentAt: 1)
				   name: (aPragma argumentAt: 2)) ].
	keyword = #shared:named:count: ifTrue: [
		^ params add: (PVParamAnnotation
				   kind: self class sharedKind
				   type:
					   (PVSPIRVEmitter sharedTypeOf: (aPragma argumentAt: 1))
				   name: (aPragma argumentAt: 2)
				   count: (aPragma argumentAt: 3)) ].
	keyword = #output:named:builtin: ifTrue: [
		^ outputs add: (PVOutputAnnotation
				   type: (aPragma argumentAt: 1)
				   name: (aPragma argumentAt: 2)
				   builtIn: (aPragma argumentAt: 3)) ].
	keyword = #output:named:location: ifTrue: [
		^ outputs add: (PVOutputAnnotation
				   type: (aPragma argumentAt: 1)
				   name: (aPragma argumentAt: 2)
				   location: (aPragma argumentAt: 3)) ]
]

{ #category : 'initialization' }
PVTypeAnnotation >> beGpuOfKind: aSymbol [
	isGPU := true.
	shaderKind := aSymbol
]

{ #category : 'testing' }
PVTypeAnnotation >> isFragment [ ^ shaderKind = #fragment
]

{ #category : 'accessing' }
PVTypeAnnotation >> isGPU [
^ isGPU
]

{ #category : 'accessing' }
PVTypeAnnotation >> isGPU: aBoolean [
	isGPU := aBoolean
]

{ #category : 'testing' }
PVTypeAnnotation >> isVertex [ ^ shaderKind = #vertex
]

{ #category : 'accessing' }
PVTypeAnnotation >> localSize [
	^ localSize
]

{ #category : 'accessing' }
PVTypeAnnotation >> localSize: anArray [
	localSize := anArray
]

{ #category : 'accessing' }
PVTypeAnnotation >> outputs [ ^ outputs
]

{ #category : 'accessing' }
PVTypeAnnotation >> outputs: x [ outputs := x
]

{ #category : 'accessing' }
PVTypeAnnotation >> paramTempDefs [
	"The kernel's parameters occupy the first registers, in declaration order; temp 0 is
	 the first parameter because a kernel method has no receiver on the GPU."

	| defs |
	defs := Dictionary new.
	self params doWithIndex: [ :p :i | defs at: i - 1 put: i ].
	^ defs
]

{ #category : 'accessing' }
PVTypeAnnotation >> params [
^ params
]

{ #category : 'accessing' }
PVTypeAnnotation >> params: aCollection [
	params := aCollection
]

{ #category : 'accessing' }
PVTypeAnnotation >> shaderKind: x [ shaderKind := x
]
