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
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
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
				   kind: #param
				   type: (aPragma argumentAt: 1)
				   name: (aPragma argumentAt: 2)) ].
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
PVTypeAnnotation >> paramNamed: aSymbol [
	^ params detect: [ :p | p name = aSymbol ]
]

{ #category : 'accessing' }
PVTypeAnnotation >> paramTypeFor: aSymbol [
	^ (self paramNamed: aSymbol) type
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
PVTypeAnnotation >> shaderKind [ ^ shaderKind
]

{ #category : 'accessing' }
PVTypeAnnotation >> shaderKind: x [ shaderKind := x
]
