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
		'outputs'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'factory' }
PVTypeAnnotation class >> fromMethod: aCompiledMethod [
    | ann |
    ann := self new.
    ann isGPU: false.
    ann params: OrderedCollection new.
    ann outputs: OrderedCollection new.
    ann shaderKind: #compute.
    aCompiledMethod pragmas do: [ :p |
        p keyword = #gpu ifTrue: [ ann isGPU: true. ann shaderKind: #compute ].
        p keyword = #gpuVertex ifTrue: [ ann isGPU: true. ann shaderKind: #vertex ].
        p keyword = #gpuFragment ifTrue: [ ann isGPU: true. ann shaderKind: #fragment ].
        (p keyword = 'param:named:') ifTrue: [
            ann params add: (PVParamAnnotation kind: #param type: (p argumentAt: 1) name: (p argumentAt: 2)) ].
        (p keyword = 'output:named:builtin:') ifTrue: [
            ann outputs add: (PVOutputAnnotation type: (p argumentAt: 1) name: (p argumentAt: 2) builtIn: (p argumentAt: 3)) ].
        (p keyword = 'output:named:location:') ifTrue: [
            ann outputs add: (PVOutputAnnotation type: (p argumentAt: 1) name: (p argumentAt: 2) location: (p argumentAt: 3)) ] ].
    ^ ann
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
