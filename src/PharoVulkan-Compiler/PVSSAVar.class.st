Class {
	#name : 'PVSSAVar',
	#superclass : 'Object',
	#instVars : [
		'name',
		'defBlock',
		'defOp'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan-Compiler'
}

{ #category : 'accessing' }
PVSSAVar >> defBlock [
^ defBlock
]

{ #category : 'accessing' }
PVSSAVar >> defBlock: aBlock [
	defBlock := aBlock
]

{ #category : 'accessing' }
PVSSAVar >> defOp [
^ defOp
]

{ #category : 'accessing' }
PVSSAVar >> defOp: anOp [
	defOp := anOp
]

{ #category : 'accessing' }
PVSSAVar >> name [
^ name
]

{ #category : 'accessing' }
PVSSAVar >> name: aSymbol [
	name := aSymbol
]
