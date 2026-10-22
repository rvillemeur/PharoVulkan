"
Examples of the compute path at the level the DSL is written in: the vector-add kernel run on this machine, a work item read in a 512-wide grid and the same item read inside its workgroup, a half-precision float built from one third, and the subgroup dot product of 1024 elements.

The work item and the float examples compute in the image and talk to no driver, so they answer the same values anywhere. The kernel and the dot product dispatch on this machine and give their device objects back before answering.
"
Class {
	#name : 'PVComputeExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Compute',
	#package : 'PharoVulkan-Examples',
	#tag : 'Compute'
}

{ #category : 'examples' }
PVComputeExamples class >> halfOfOneThird [
	"A third is not representable in any binary format, so this half shows the rounding:
	 the Half tab names its fields and re-encodes its own value."

	<sampleInstance>
	^ PVFloat16 fromFloat: 1 / 3
]

{ #category : 'examples' }
PVComputeExamples class >> opcodeProbeOnThisMachine [
	"One click: every opcode the tiled fill rasteriser needs, dispatched on this machine. The
	 Instructions tab names what the module really holds, and the comparison tab puts each
	 invocation of the device next to the formula the kernel states in Pharo. It asks the
	 device for a context exactly as the other compute examples do, so a machine with no
	 driver refuses here as it refuses there."

	<sampleInstance>
	| kernel context |
	kernel := PVOpcodeProbeKernel new.
	context := VkContext computeContext.
	^ [
	  kernel runOn: context.
	  kernel ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVComputeExamples class >> subgroupDotOf1024Elements [
	"One click: a dot product over 1024 elements reduced in hardware. The Reduction tab holds
	 the two subgroup widths and the two totals. On a device that reports no subgroup
	 arithmetic the run refuses, and the example answers the refusing run so the tab can say
	 why rather than raising past the click."

	<sampleInstance>
	| context run |
	context := VkContext computeContext.
	^ [ run := PVSubgroupDotProduct on: context size: 1024.
	    run available ifTrue: [ run run ].
	    run ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVComputeExamples class >> vectorAddKernelOnThisMachine [
	"One click: the kernel the README's playground builds, prepared and dispatched once on
	 whichever device is here, then released with its buffers and its context, as every
	 example here does. The pipeline tab reads the binding list and the SPIR-V module the
	 instance keeps, so the kernel still answers afterwards. Where no device is available it
	 answers the same kernel unprepared, which is what the inspector should show on such a
	 machine."
	<sampleInstance>
	| context kernel buffers |
	context := [ VkContext computeContext ]
		           on: VkError
		           do: [ :error | nil ].
	context ifNil: [ ^ PVComputeKernel fromMethod: PVComputeKernel exampleKernelMethod on: nil ].
	^ [
	  kernel := PVComputeKernel fromMethod: PVComputeKernel exampleKernelMethod on: context.
	  buffers := (1 to: PVComputeKernel exampleBufferCount) collect: [ :each |
		             VkBuffer
			             storageBuffer: PVComputeKernel exampleElementCount
			             on: context device ].
	  buffers do: [ :each | kernel bindBuffer: each ].
	  kernel prepare.
	  kernel dispatch: 1 y: 1 z: 1.
	  kernel destroy.
	  buffers do: [ :each | each destroy ].
	  kernel ] ensure: [ context destroy ]
]

{ #category : 'examples' }
PVComputeExamples class >> workItemInA512Grid [
	<sampleInstance>
	^ PVWorkItem x: 3 y: 7 z: 0 gridWidth: 512
]

{ #category : 'examples' }
PVComputeExamples class >> workItemInsideItsWorkgroup [
	"An invocation whose position in the dispatch and position in its workgroup differ: slot
	 5 of a workgroup 16 wide, which is global invocation 21. Inspect it and read the
	 Dispatch tab to see the two indices side by side."

	<sampleInstance>
	^ PVWorkItem
		  x: 21
		  y: 0
		  z: 0
		  localX: 5
		  localY: 0
		  localZ: 0
		  gridWidth: 512
]
