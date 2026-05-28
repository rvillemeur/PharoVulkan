Extension { #name : 'Number' }

{ #category : '*pharovulkan-compiler' }
Number >> clamp: lo to: hi [
	"GPU DSL: maps to GLSL fClamp. In Pharo: clamps receiver between lo and hi."
	^ (self max: lo) min: hi
]
