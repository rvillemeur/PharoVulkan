"
Maps a (selector, receiverType, argTypes) triple to a SPIR-V opcode or emit strategy. One entry in the PVSelectorTable dispatch table.
"
Class {
	#name : 'PVSelectorMapping',
	#superclass : 'Object',
	#instVars : [
		'spirvOp',
		'resultTypeSymbol'
	],
	#category : 'PharoVulkan-Compiler-Selectors',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Selectors'
}

{ #category : 'instance creation' }
PVSelectorMapping class >> spirvOp: op resultType: rt [
	^ self new spirvOp: op; resultTypeSymbol: rt; yourself
]

{ #category : 'accessing' }
PVSelectorMapping >> resultTypeSymbol [
^ resultTypeSymbol
]

{ #category : 'accessing' }
PVSelectorMapping >> resultTypeSymbol: aSymbol [
	resultTypeSymbol := aSymbol
]

{ #category : 'accessing' }
PVSelectorMapping >> spirvOp [
^ spirvOp
]

{ #category : 'accessing' }
PVSelectorMapping >> spirvOp: aSymbol [
	spirvOp := aSymbol
]
