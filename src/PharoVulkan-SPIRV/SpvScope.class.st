"
Named constants for the SPIR-V Scope enumeration, the execution scope a group operation runs over. All methods are class-side. Key method: subgroup, which is the scope of a wave-wide reduction and the only one the compiler emits today.
"
Class {
	#name : 'SpvScope',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV-Constants',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Constants'
}

{ #category : 'constants' }
SpvScope class >> subgroup [
	"Scope Subgroup from the SPIR-V Scope enumeration, the neighbour of Workgroup 2 and
	 Invocation 4. The set of invocations the hardware runs in lockstep, which is what a
	 subgroup reduction adds over."

	^ 3
]

{ #category : 'constants' }
SpvScope class >> workgroup [
	"Scope Workgroup from the SPIR-V Scope enumeration, between Device 1 and Subgroup 3.
	 All invocations of one workgroup, which is the scope a shared memory tile and the
	 barrier guarding it belong to."

	^ 2
]
