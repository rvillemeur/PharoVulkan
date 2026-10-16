"
Tests for PharoVulkan-Graphics: the offscreen render path, the window path, and the coverage rule that keeps them honest.

`PVGraphicsTest` renders a triangle both offscreen and into a real window, reads the pixels back, and compares the hand-built shaders against the ones the DSL compiles. `VkImageTest` covers images and their views. `PVFailingTriangleSceneStub` raises part-way through preparation so the release order can be asserted after a failure, and `PVRecordingContextStub` records the commands a scene would issue without a device.

The class side holds a coverage rule rather than a test fixture: every class of the graphics package must be reachable from a test that builds a device context, or be named with its reason. The populations it reads are derived from the organiser by prefix and asserted non-empty, because a package split once emptied them and the rule passed in silence.
"
Class {
	#name : 'ManifestPharoVulkanGraphicsTests',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Graphics-Tests-Manifest',
	#package : 'PharoVulkan-Graphics-Tests',
	#tag : 'Manifest'
}
