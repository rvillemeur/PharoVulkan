Extension { #name : 'Number' }

{ #category : '*PharoVulkan-Compiler' }
Number >> asF32 [
	"Extension on Number: the kernel DSL's widening conversion, which on the host is only
	 asFloat. Named for the SPIR-V type so a kernel reads the same in both precisions."

	^ self asFloat
]

{ #category : '*PharoVulkan-Compiler' }
Number >> clamp: lo to: hi [
	"GPU DSL: maps to GLSL fClamp. In Pharo: clamps receiver between lo and hi."
	^ (self max: lo) min: hi
]

{ #category : '*PharoVulkan-Compiler' }
Number >> subgroupSum [
	"Extension on Number: the kernel DSL's subgroup reduction. It lives here rather than
	 upstream because a kernel body must mean something when it runs in the image, and a
	 single Pharo process is a subgroup of one, whose sum is the value itself."

	^ self
]
