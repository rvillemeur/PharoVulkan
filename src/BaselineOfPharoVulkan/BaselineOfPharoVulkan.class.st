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

{ #category : 'as yet unclassified' }
BaselineOfPharoVulkan >> baseline: spec [
	"The packages are declared in the order the split creates them, and each one requires only the
	 packages it actually references: PharoVulkan-SPIRV emits SPIR-V and reaches nothing else, so it
	 loads first, and PharoVulkan-Compiler sits on it alone — it answers bytes and talks to no
	 driver, which is what the compiler group loads without any Vulkan code. The generator and the
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
			package: 'PharoVulkan-Generator'
			with: [ spec requires: #( 'PharoVulkan-SPIRV' 'PharoVulkan' ) ];
			package: 'PharoVulkan-Examples'
			with: [ spec requires: #( 'PharoVulkan' ) ];
			package: 'PharoVulkan-Tests'
			with: [
				spec requires:
					#( 'PharoVulkan' 'PharoVulkan-Examples' 'PharoVulkan-Generator' ) ].
		spec
			group: 'spirv' with: #( 'PharoVulkan-SPIRV' );
			group: 'compiler' with: #( 'PharoVulkan-SPIRV' 'PharoVulkan-Compiler' );
			group: 'default' with: #( 'PharoVulkan' );
			group: 'generator' with: #( 'PharoVulkan-Generator' );
			group: 'examples' with: #( 'PharoVulkan-Examples' );
			group: 'tests'
			with: #( 'default' 'PharoVulkan-Examples' 'PharoVulkan-Tests' ) ]
]
