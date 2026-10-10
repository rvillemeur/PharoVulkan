"
Named constants for the SPIR-V Scope enumeration, the execution scope a group operation runs over. All methods are class-side. Key method: subgroup, which is the scope of a wave-wide reduction and the only one the compiler emits today.
"
Class {
	#name : 'SpvScope',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'constants' }
SpvScope class >> subgroup [
	"Scope Subgroup from the SPIR-V Scope enumeration, the neighbour of Workgroup 2 and
	 Invocation 4. The set of invocations the hardware runs in lockstep, which is what a
	 subgroup reduction adds over."

	^ 3
]
