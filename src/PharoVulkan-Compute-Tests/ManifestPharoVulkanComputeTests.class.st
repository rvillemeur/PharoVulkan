"
Tests for PharoVulkan-Compute: that a kernel dispatches, that the numbers it writes back are the numbers expected, and that the benchmarks measure what they claim.

`PVComputeTest` runs on a real device and skips with a reason where the device lacks a feature, which is what makes the cooperative-matrix and subgroup tests honest on a software driver. `PVNoSubgroupArithmeticStub` stands in for a device without subgroup arithmetic so the fallback path is tested on every machine.

Two of its tests compile kernels out of `PVCfgShapeFixture` in `PharoVulkan-Tests-Compiler`: the control-flow shapes the recogniser accepts are pinned there, and running them on a device is how this package shows the acceptance is real.
"
Class {
	#name : 'ManifestPharoVulkanComputeTests',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Compute-Tests-Manifest',
	#package : 'PharoVulkan-Compute-Tests',
	#tag : 'Manifest'
}
