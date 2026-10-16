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
	 packages it actually references. PharoVulkan-Bindings declares the structures, the handles,
	 the constants and the foreign calls, and reaches nothing else, so it loads first and requires
	 nothing. PharoVulkan-SPIRV emits SPIR-V and reaches nothing either; PharoVulkan-Compiler sits
	 on it alone — it answers bytes and talks to no driver, which is what the compiler group loads
	 without any Vulkan code. PharoVulkan-Core holds the device lifecycle, so it requires the
	 bindings it calls through and the SPIR-V package that declares the type error it raises.
	 PharoVulkan-Compute dispatches and PharoVulkan-Graphics renders, so both require the compiler
	 that answers them a module as well as the lifecycle that answers them a device, and Graphics
	 requires Compute for the kernel sources its shaders are compiled from. All of these are part
	 of 'default': a user of this project opens a device, runs something on it and draws. The
	 generator and the examples are left out of 'default' because a user of the bindings needs
	 neither. PharoVulkan-Examples requires all six code packages rather than Graphics alone,
	 because there is an example class for each of them; Graphics would pull the others in anyway,
	 but then the declaration would stop saying what the package reaches."
	"There is one test package per code package that has tests, named for the package it covers
	 and ending in -Tests, which is the convention Pharo's own tools and critics expect. Each
	 requires the package it covers and whatever else its tests build on, which for most of them
	 includes the examples the test classes read. PharoVulkan-Compute-Tests also requires
	 PharoVulkan-Compiler-Tests: the control-flow shapes the recogniser accepts are written down
	 as kernels there, and running two of them on a device is how the compute tests show that
	 acceptance is real. PharoVulkan-Tests survives as a package of one class, because a rule
	 about how packages may depend on each other belongs to no single package; it requires the six
	 so that loading it loads everything the rule is about, and PharoVulkan-Core besides, because
	 the fixture that proves the scan reads inside nested blocks names a class from there."

	<baseline>
	spec for: #common do: [
		spec
			package: 'PharoVulkan-Bindings';
			package: 'PharoVulkan-SPIRV';
			package: 'PharoVulkan-Compiler'
			with: [ spec requires: #( 'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan-Core'
			with: [
				spec requires: #( 'PharoVulkan-Bindings' 'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan-Compute'
			with: [
				spec requires:
					#( 'PharoVulkan-Bindings' 'PharoVulkan-Core' 'PharoVulkan-Compiler'
					   'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan-Graphics'
			with: [
				spec requires:
					#( 'PharoVulkan-Bindings' 'PharoVulkan-Core' 'PharoVulkan-Compute'
					   'PharoVulkan-Compiler' 'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan-Generator'
			with: [
				spec requires: #( 'PharoVulkan-SPIRV' 'PharoVulkan-Bindings' ) ];
			package: 'PharoVulkan-Examples'
			with: [
				spec requires:
					#( 'PharoVulkan-Graphics' 'PharoVulkan-Bindings' 'PharoVulkan-Core'
					   'PharoVulkan-Compute' 'PharoVulkan-Compiler' 'PharoVulkan-SPIRV' ) ];
			package: 'PharoVulkan-Bindings-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-Bindings' 'PharoVulkan-Core' 'PharoVulkan-Compute'
					   'PharoVulkan-Graphics' 'PharoVulkan-Generator'
					   'PharoVulkan-Examples' ) ];
			package: 'PharoVulkan-SPIRV-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-SPIRV' 'PharoVulkan-Core' 'PharoVulkan-Compute' ) ];
			package: 'PharoVulkan-Compiler-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-Compiler' 'PharoVulkan-SPIRV' 'PharoVulkan-Compute'
					   'PharoVulkan-Examples' ) ];
			package: 'PharoVulkan-Core-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-Core' 'PharoVulkan-Bindings' 'PharoVulkan-Compute'
					   'PharoVulkan-SPIRV' 'PharoVulkan-Examples' ) ];
			package: 'PharoVulkan-Compute-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-Compute' 'PharoVulkan-Bindings' 'PharoVulkan-Core'
					   'PharoVulkan-Compiler' 'PharoVulkan-SPIRV' 'PharoVulkan-Examples'
					   'PharoVulkan-Compiler-Tests' ) ];
			package: 'PharoVulkan-Graphics-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-Graphics' 'PharoVulkan-Bindings' 'PharoVulkan-Core'
					   'PharoVulkan-Compute' 'PharoVulkan-Compiler'
					   'PharoVulkan-Examples' ) ];
			package: 'PharoVulkan-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan-Bindings-Tests' 'PharoVulkan-SPIRV-Tests'
					   'PharoVulkan-Compiler-Tests' 'PharoVulkan-Core-Tests'
					   'PharoVulkan-Compute-Tests' 'PharoVulkan-Graphics-Tests'
					   'PharoVulkan-Core' ) ].
		spec
			group: 'bindings' with: #( 'PharoVulkan-Bindings' );
			group: 'spirv' with: #( 'PharoVulkan-SPIRV' );
			group: 'compiler' with: #( 'PharoVulkan-SPIRV' 'PharoVulkan-Compiler' );
			group: 'core' with: #( 'PharoVulkan-Core' );
			group: 'compute' with: #( 'PharoVulkan-Compute' );
			group: 'graphics' with: #( 'PharoVulkan-Graphics' );
			group: 'default'
			with:
				#( 'PharoVulkan-Bindings' 'PharoVulkan-Core' 'PharoVulkan-Compute'
				   'PharoVulkan-Graphics' );
			group: 'generator' with: #( 'PharoVulkan-Generator' );
			group: 'examples' with: #( 'PharoVulkan-Examples' );
			group: 'tests'
			with:
				#( 'default' 'PharoVulkan-Examples' 'PharoVulkan-Generator'
				   'PharoVulkan-Tests' ) ]
]
