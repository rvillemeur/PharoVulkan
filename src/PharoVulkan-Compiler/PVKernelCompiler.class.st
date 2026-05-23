Class {
	#name : 'PVKernelCompiler',
	#superclass : 'Object',
	#instVars : [
		'method',
		'annotation'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'compiling' }
PVKernelCompiler class >> compile: aCompiledMethod [
	^ self new method: aCompiledMethod; compile
]

{ #category : 'accessing' }
PVKernelCompiler >> annotation [
^ annotation
]

{ #category : 'accessing' }
PVKernelCompiler >> annotation: ann [
	annotation := ann
]

{ #category : 'compiling' }
PVKernelCompiler >> compile [
	| ann bytecodeOps blocks structNode regOps cfg ssaCFG st typeMap typeInf |
	annotation := PVTypeAnnotation fromMethod: method.
	annotation isGPU ifFalse: [ PVTypeError signal: 'Method is not annotated with <gpu>' ].
	bytecodeOps := PVBytecodeDecoder decode: method.
	blocks := PVCFGBuilder buildBytecodeBlocks: bytecodeOps.
	"Straight-line path (Phase 4): single block"
	blocks size = 1 ifTrue: [
		regOps := PVStackSimulator simulate: bytecodeOps.
		cfg := PVCFGBuilder buildFrom: regOps.
		ssaCFG := PVSSAConstructor construct: cfg.
		st := PVSelectorTable standard.
		typeInf := PVTypeInferencer new initialize annotation: annotation.
		typeMap := typeInf inferAll: regOps selectorTable: st.
		^ PVSPIRVEmitter compileKernel: regOps typeMap: typeMap annotation: annotation selectorTable: st name: method selector ].
	"Control flow path (Phase 5)"
	structNode := PVStructuredCFGRecognizer recognizeFrom: blocks.
	structNode isNil ifTrue: [ PVTypeError signal: 'Unrecognized CFG shape' ].
	"Run flat simulation + type inference for typeMap"
	regOps := PVStackSimulator simulate: bytecodeOps.
	st := PVSelectorTable standard.
	typeMap := Dictionary new.
	typeInf := PVTypeInferencer new initialize annotation: annotation.
	[ typeInf inferAll: regOps selectorTable: st ] on: PVTypeError do: [ :e | typeMap ].
	typeMap := typeInf typeMap.
	(structNode isKindOf: PVSelectionNode) ifTrue: [
		^ PVSPIRVEmitter compileSelection: structNode annotation: annotation typeMap: typeMap selectorTable: st ].
	PVTypeError signal: 'Loop compilation not yet implemented'
]

{ #category : 'accessing' }
PVKernelCompiler >> method [
^ method
]

{ #category : 'accessing' }
PVKernelCompiler >> method: aCompiledMethod [
	method := aCompiledMethod
]
