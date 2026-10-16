"
Tests for PharoVulkan-Core: the device lifecycle, from instance creation to the last handle destroyed.

`VkCoreTest` opens a real device where one exists and asserts what this project asks of it, and it asserts the layering the split established: no class of the lifecycle reaches a descriptor pool, and a pipeline layout lives below both pipeline kinds. `PVQueueFamilyStub` answers queue families a driver on this machine may not have, so the selection rules can be tested without one.
"
Class {
	#name : 'ManifestPharoVulkanCoreTests',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Core-Tests-Manifest',
	#package : 'PharoVulkan-Core-Tests',
	#tag : 'Manifest'
}
