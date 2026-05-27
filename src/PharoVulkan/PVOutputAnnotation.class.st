Class {
	#name : 'PVOutputAnnotation',
	#superclass : 'Object',
	#instVars : [
		'type',
		'name',
		'location',
		'builtIn'
	],
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'factory' }
PVOutputAnnotation class >> type: t name: n builtIn: b [
    ^ self new type: t; name: n; builtIn: b; location: nil; yourself
]

{ #category : 'factory' }
PVOutputAnnotation class >> type: t name: n location: l [
    ^ self new type: t; name: n; location: l; builtIn: nil; yourself
]

{ #category : 'accessing' }
PVOutputAnnotation >> builtIn [ ^ builtIn
]

{ #category : 'accessing' }
PVOutputAnnotation >> builtIn: x [ builtIn := x
]

{ #category : 'accessing' }
PVOutputAnnotation >> location [ ^ location
]

{ #category : 'accessing' }
PVOutputAnnotation >> location: x [ location := x
]

{ #category : 'accessing' }
PVOutputAnnotation >> name [ ^ name
]

{ #category : 'accessing' }
PVOutputAnnotation >> name: x [ name := x
]

{ #category : 'accessing' }
PVOutputAnnotation >> type [ ^ type
]

{ #category : 'accessing' }
PVOutputAnnotation >> type: x [ type := x
]
