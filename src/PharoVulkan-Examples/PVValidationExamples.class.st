"
One example per kernel this project compiles, each running the external SPIR-V validator over the module the compiler emitted: the scalar, vector-add, half vector-add, matmul, tiled matmul, compute loop, compute selection, shared broadcast, subgroup dot and cooperative matrix kernels.

These are the examples that answer whether the compiler is still emitting valid SPIR-V. Each needs spirv-val on the path; without it the validator answers that it could not run rather than that the module is bad, and the distinction matters — a missing tool is not a compiler defect.
"
Class {
	#name : 'PVValidationExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Compiler',
	#package : 'PharoVulkan-Examples',
	#tag : 'Compiler'
}

{ #category : 'examples' }
PVValidationExamples class >> validatorOnComputeLoopKernel [
	"One click: the compute kernel whose body is a whileTrue:. spirv-val cannot see a
	 dropped loop, so read the Module tab for the OpLoopMerge as well as the verdict."
	<sampleInstance>
	^ PVSpirvValidator on: (PVKernelCompiler compile: (PVKernelExamples >> #sumFirst16:data:out:))
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnComputeSelectionKernel [
	"One click: the compute kernel whose body is an ifTrue:ifFalse:."
	<sampleInstance>
	^ PVSpirvValidator on: (PVKernelCompiler compile: (PVKernelExamples >> #clampNegatives:data:out:))
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnCooperativeMatrixKernel [
	"One click: spirv-val on the hand-built cooperative matrix module. The tool knows the
	 rules the extension adds, which is how the two half bindings sharing one runtime array
	 decorated with ArrayStride twice came to light."

	<sampleInstance>
	^ PVSpirvValidator on: PVCooperativeMatrixKernel new spirv
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnHalfVectorAddKernel [
	"One click: the half precision vector add. spirv-val refuses a 16-bit float in a
	 storage buffer unless the module declares Float16 and StorageBuffer16BitAccess, so the
	 verdict is what tells the two capabilities reached the module."

	<sampleInstance>
	^ PVSpirvValidator on:
		  (PVKernelCompiler compile:
			   (PVKernelExamples >> #vectorAddF16:a:b:out:))
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnMatmulKernel [
	"One click: the Phase 7 baseline matmul. The Entry point tab shows the 16 by 16
	 workgroup from the kernel's pragma and the numWorkgroups built-in it reads for N."

	<sampleInstance>
	^ PVSpirvValidator on: (PVKernelCompiler compile: (PVKernelExamples >> #matmulF32:a:b:out:))

]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnScalarKernel [
	"One click on the failing path: a scalar <gpu> method compiles to a SPIR-V function
	 with no OpEntryPoint, which spirv-val must refuse as a standalone module."
	<sampleInstance>
	^ PVSpirvValidator on: (PVKernelCompiler compile: (PVKernelExamples >> #relu:))
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnSharedBroadcastKernel [
	"One click: shared memory and a barrier compiled from Pharo source rather than
	 assembled through the builder. The entry point view shows whether the tile reached the
	 interface list, which is the one thing the DSL path can lose."

	<sampleInstance>
	^ PVSpirvValidator on:
		  (PVKernelCompiler compile:
			   (PVKernelExamples >> #broadcastFirstOf:data:out:tile:))
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnSubgroupDotKernel [
	"One click: the kernel that adds the lanes of a subgroup. The verdict is what tells the
	 two group capabilities and the Subgroup scope reached the module, because spirv-val
	 refuses the instruction without them."

	<sampleInstance>
	^ PVSpirvValidator on:
		  (PVKernelCompiler compile:
			   (PVKernelExamples >> #subgroupDotOf:a:b:out:lanes:))
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnTiledMatmulKernel [
	"One click: the hand-built tiled matmul. Nothing else checks this module's structured
	 control flow, its Workgroup variables or its barrier operands, because it is assembled
	 through the builder rather than compiled from a Pharo method."

	<sampleInstance>
	^ PVSpirvValidator on: PVTiledMatmulKernel new spirv
]

{ #category : 'examples' }
PVValidationExamples class >> validatorOnVectorAddKernel [
	"One click: the compute kernel that must pass spirv-val."
	<sampleInstance>
	^ PVSpirvValidator on: (PVKernelCompiler compile: (PVKernelExamples >> #vectorAdd:a:b:out:))
]
