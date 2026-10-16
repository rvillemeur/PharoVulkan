"
Runnable examples of this project, one click each.

Every class-side <sampleInstance> method of PharoVulkan lives here as an extension method, so the example stays on the class it demonstrates while this package owns it. The helper constants the examples read — exampleExtent, exampleElementCount and the like — came with them, because nothing outside an example or a test reads one. PVGlslTriangleScene is the one class defined here: it is a demonstration scene rather than part of the renderer.

Nothing in the project may depend on this package. It is the top of the dependency order and may reach into any other package.
"
Class {
	#name : 'ManifestPharoVulkanExamples',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Examples-Manifest',
	#package : 'PharoVulkan-Examples',
	#tag : 'Manifest'
}

{ #category : 'code-critics' }
ManifestPharoVulkanExamples class >> ruleReClassNotReferencedRuleV1FalsePositive [
	"An example class is a click target. Nothing sends to it by design: it holds the
	 examples a reader opens from the browser, so a reference from production code would
	 mean an example had become part of the library. The classes listed here are the ones
	 no test happens to name either."

	^ #( #( #( #RGClassDefinition #( #SpvTypeExamples #VkCommandExamples #VkRenderPassExamples #VkFeatureStructureExamples #VkContextExamples #VkDeviceRequestExamples #PVSceneExamples ) ) #'2026-10-16T00:00:00+00:00' ) )
]
