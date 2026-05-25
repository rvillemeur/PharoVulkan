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

	<baseline>
	spec for: #common do: [
			spec
				package: 'PharoVulkan';
				package: 'PharoVulkan-Tests'
				with: [ spec requires: #( 'PharoVulkan' ) ].
			spec
				group: 'default' with: #( 'PharoVulkan' );
				group: 'tests' with: #( 'default' 'PharoVulkan-Tests' ) ]
]
