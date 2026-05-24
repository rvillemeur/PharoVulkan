"
Parsed representation of a <param: #type named: #name> pragma. Carries the SPIR-V type symbol and parameter name. Extracted from a CompiledMethod by PVKernelCompiler at compile time.
"
Class {
	#name : 'PVParamAnnotation',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'type',
		'name'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'instance creation' }
PVParamAnnotation class >> kind: k type: t name: n [
	^ self new kind: k; type: t; name: n; yourself
]

{ #category : 'accessing' }
PVParamAnnotation >> kind [
^ kind
]

{ #category : 'accessing' }
PVParamAnnotation >> kind: aSymbol [
	kind := aSymbol
]

{ #category : 'accessing' }
PVParamAnnotation >> name [
^ name
]

{ #category : 'accessing' }
PVParamAnnotation >> name: aSymbol [
	name := aSymbol
]

{ #category : 'accessing' }
PVParamAnnotation >> type [
^ type
]

{ #category : 'accessing' }
PVParamAnnotation >> type: aSymbol [
	type := aSymbol
]
