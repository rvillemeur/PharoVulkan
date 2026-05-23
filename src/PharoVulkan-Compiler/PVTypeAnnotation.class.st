Class {
	#name : 'PVTypeAnnotation',
	#superclass : 'Object',
	#instVars : [
		'isGPU',
		'params'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'instance creation' }
PVTypeAnnotation class >> fromMethod: aCompiledMethod [
	| ann |
	ann := self new.
	ann isGPU: false.
	ann params: OrderedCollection new.
	aCompiledMethod pragmas do: [ :p |
		p keyword = #gpu ifTrue: [ ann isGPU: true ].
		(p keyword beginsWith: 'param:named:') ifTrue: [
			ann params add:
				(PVParamAnnotation kind: #param type: (p argumentAt: 1) name: (p argumentAt: 2)) ] ].
	^ ann
]

{ #category : 'accessing' }
PVTypeAnnotation >> isGPU [
^ isGPU
]

{ #category : 'accessing' }
PVTypeAnnotation >> isGPU: aBoolean [
	isGPU := aBoolean
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
