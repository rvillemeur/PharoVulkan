"
Baseline for PharoVulkan — Vulkan uFFI bindings and SPIR-V builder for Pharo.
Load default group for bindings + generator + SPIR-V builder.
Load tests group to also include the test packages.
"
Class {
	#name : 'BaselineOfPharoVulkan',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPharoVulkan-Base',
	#package : 'BaselineOfPharoVulkan',
	#tag : 'Base'
}

{ #category : 'baselines' }
BaselineOfPharoVulkan >> baseline: spec [
	"The packages are declared in the order the split creates them, and each one requires only the
	 packages it actually references: PharoVulkan-SPIRV emits SPIR-V and reaches nothing else, so it
	 loads first, and PharoVulkan-Compiler sits on it alone — it answers bytes and talks to no
	 driver, which is what the compiler group loads without any Vulkan code. PharoVulkan-Core holds
	 the device lifecycle, so it requires the bindings it calls through and the SPIR-V package that
	 declares the type error it raises. PharoVulkan-Compute dispatches, so it requires the compiler
	 that answers it a module as well as the lifecycle that answers it a device. Both are part of
	 'default': a user of this project opens a device and runs something on it. The generator and the
	 examples are left out of 'default' because a user of the bindings needs neither. Loading
	 'tests' brings the examples in, because the test classes read the example classes."

	<baseline>
	spec for: #common do: [
		spec
			package: 'PharoVulkan-SPIRV';
			package: 'PharoVulkan-Compiler'
			with: [ spec requires: #( 'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan'
			with: [ spec requires: #( 'PharoVulkan-SPIRV' 'PharoVulkan-Compiler' ) ];
			package: 'PharoVulkan-Core'
			with: [ spec requires: #( 'PharoVulkan' 'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan-Compute'
			with: [
				spec requires:
					#( 'PharoVulkan' 'PharoVulkan-Core' 'PharoVulkan-Compiler'
					   'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan-Generator'
			with: [ spec requires: #( 'PharoVulkan-SPIRV' 'PharoVulkan' ) ];
			package: 'PharoVulkan-Examples'
			with: [ spec requires: #( 'PharoVulkan-Compute' ) ];
			package: 'PharoVulkan-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-Compute' 'PharoVulkan-Examples'
					   'PharoVulkan-Generator' ) ].
		spec
			group: 'spirv' with: #( 'PharoVulkan-SPIRV' );
			group: 'compiler' with: #( 'PharoVulkan-SPIRV' 'PharoVulkan-Compiler' );
			group: 'core' with: #( 'PharoVulkan-Core' );
			group: 'compute' with: #( 'PharoVulkan-Compute' );
			group: 'default'
			with: #( 'PharoVulkan' 'PharoVulkan-Core' 'PharoVulkan-Compute' );
			group: 'generator' with: #( 'PharoVulkan-Generator' );
			group: 'examples' with: #( 'PharoVulkan-Examples' );
			group: 'tests'
			with: #( 'default' 'PharoVulkan-Examples' 'PharoVulkan-Tests' ) ]
]
