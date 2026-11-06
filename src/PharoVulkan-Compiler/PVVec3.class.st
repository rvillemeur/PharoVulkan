"
I am the implementor of record for #mix:factor:, the one DSL selector of this project that no Pharo class answers.

The GPU DSL compiles the body of a method marked <gpu>, <gpuVertex> or <gpuFragment>. Every selector such a body sends has to be implemented somewhere, or the Pharo compiler that produces the bytecode the DSL reads has nothing to resolve and the browser flags the send. For arithmetic and comparison the implementor is the real Pharo class — Number, Float, Boolean. #mix:factor: has no Pharo counterpart: it is the GLSL FMix instruction, linear interpolation between two vectors. So this class carries it, and PVCompilerTest >> testEverySelectorAKernelOfThisProjectSendsIsImplemented holds that rule for every kernel in the project.

Nothing instantiates me and no kernel ever runs in Pharo, so #mix:factor: raises an error rather than computing anything. My four sibling token classes — PVVec2, PVVec4, PVBVec3 and PVMat4 — were deleted in review point 10: they declared no selector the compiler needed, so they carried no rule and nothing referenced them.
"
Class {
	#name : 'PVVec3',
	#superclass : 'Object',
	#category : 'PharoVulkan-Compiler-Types',
	#package : 'PharoVulkan-Compiler',
	#tag : 'Types'
}

{ #category : 'operations' }
PVVec3 >> mix: other factor: f [
	"GPU DSL only: the compiler reads this send and emits the GLSL FMix instruction. Never runs
	 in Pharo — see the class comment for why the method is here at all."

	^ self error: 'mix:factor: is a GPU DSL-only operation'
]
