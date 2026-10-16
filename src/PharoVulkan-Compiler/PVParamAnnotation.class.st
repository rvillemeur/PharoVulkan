"
Parsed representation of a <param: #type named: #name> pragma. Carries the SPIR-V type symbol and parameter name. Extracted from a CompiledMethod by PVKernelCompiler at compile time.
"
Class {
	#name : 'PVParamAnnotation',
	#superclass : 'Object',
	#instVars : [
		'kind',
		'type',
		'name',
		'count'
	],
	#category : 'PharoVulkan-Compiler-Annotations',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Annotations'
}

{ #category : 'instance creation' }
PVParamAnnotation class >> kind: k type: t name: n [
	^ self new kind: k; type: t; name: n; yourself
]

{ #category : 'instance creation' }
PVParamAnnotation class >> kind: k type: t name: n count: anInteger [
	"A parameter that carries a length: a shared array has to state how many elements it
	 holds, because a workgroup's share of shared memory is fixed when the module is
	 compiled rather than when it is dispatched."

	^ self new
		  kind: k;
		  type: t;
		  name: n;
		  count: anInteger;
		  yourself
]

{ #category : 'accessing' }
PVParamAnnotation >> count [
	^ count
]

{ #category : 'accessing' }
PVParamAnnotation >> count: anInteger [
	count := anInteger
]

{ #category : 'testing' }
PVParamAnnotation >> isShared [
	"Shared parameters are not bound by the host: they become Workgroup-storage variables,
	 so they take no descriptor and the host passes nothing for them."

	^ kind = PVTypeAnnotation sharedKind
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
