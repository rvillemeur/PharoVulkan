"
Type token for vec3 (3-component float32 vector). Used as pragma argument: <param: #vec3 named: #p>.
"
Class {
	#name : 'PVVec3',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler',
	#package : 'PharoVulkan',
	#tag : 'Compiler'
}

{ #category : 'gpu-dsl' }
PVVec3 >> mix: other factor: f [
	"GPU DSL: maps to GLSL FMix. Not callable from Pharo; present to satisfy the linter."
	^ self error: 'mix:factor: is a GPU DSL-only operation'
]
