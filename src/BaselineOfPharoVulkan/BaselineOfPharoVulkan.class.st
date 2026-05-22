"
Baseline for PharoVulkan — Vulkan uFFI bindings and SPIR-V builder for Pharo.
Load default group for bindings + generator + SPIR-V builder.
Load tests group to also include the test packages.
"
Class {
	#name : 'BaselineOfPharoVulkan',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPharoVulkan',
	#package : 'BaselineOfPharoVulkan'
}

{ #category : 'baselines' }
BaselineOfPharoVulkan >> baseline: spec [
    <baseline>
    spec for: #common do: [
        spec
            package: 'PharoVulkan-Generator';
            package: 'PharoVulkan-Bindings'
                with: [ spec requires: #('PharoVulkan-Generator') ];
            package: 'PharoVulkan-SPIRV';
            package: 'PharoVulkan-Tests-Bindings'
                with: [ spec requires: #('PharoVulkan-Bindings') ];
            package: 'PharoVulkan-Tests-SPIRV'
                with: [ spec requires: #('PharoVulkan-SPIRV') ].
        spec
            group: 'default'
                with: #('PharoVulkan-Generator' 'PharoVulkan-Bindings' 'PharoVulkan-SPIRV');
            group: 'tests'
                with: #('default' 'PharoVulkan-Tests-Bindings' 'PharoVulkan-Tests-SPIRV') ]
]
