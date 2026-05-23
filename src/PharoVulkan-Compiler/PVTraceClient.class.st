Class {
	#name : 'PVTraceClient',
	#superclass : 'InstructionClient',
	#instVars : [
		'trace',
		'currentPc'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'misc' }
PVTraceClient >> doPop [
	trace add: 'pop'
]

{ #category : 'init' }
PVTraceClient >> initialize [
	trace := OrderedCollection new. currentPc := 0
]

{ #category : 'jump' }
PVTraceClient >> jump: offset [
	trace add: ('jump offset=' , offset printString , ' afterPc=' , currentPc printString)
]

{ #category : 'jump' }
PVTraceClient >> jump: offset if: cond [
	trace add: ('jumpIf offset=' , offset printString , ' cond=' , cond printString , ' afterPc=' , currentPc printString)
]

{ #category : 'misc' }
PVTraceClient >> methodReturnTop [
	trace add: 'returnTop'
]

{ #category : 'pc' }
PVTraceClient >> pc: n [
	currentPc := n
]

{ #category : 'misc' }
PVTraceClient >> popIntoTemporaryVariable: i [
	trace add: ('popTemp ' , i printString)
]

{ #category : 'misc' }
PVTraceClient >> pushConstant: v [
	trace add: ('pushConst ' , v printString)
]

{ #category : 'misc' }
PVTraceClient >> pushTemporaryVariable: i [
	trace add: ('pushTemp ' , i printString)
]

{ #category : 'misc' }
PVTraceClient >> send: s super: b numArgs: n [
	trace add: ('send ' , s)
]

{ #category : 'misc' }
PVTraceClient >> storeIntoTemporaryVariable: i [
	trace add: ('storeTemp ' , i printString)
]

{ #category : 'accessing' }
PVTraceClient >> trace [
	^ trace
]
