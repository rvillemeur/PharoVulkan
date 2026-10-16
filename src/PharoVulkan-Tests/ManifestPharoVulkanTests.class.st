"
Holds the project-wide architecture test: the one test that states which dependencies the eight
code packages and the six test packages are allowed to have on each other, and that fails when a
method anywhere in the project names a class outside what its own package is permitted to reach.

A rule about how packages may depend on one another belongs to no single package, which is why
this package keeps its name after the split instead of being folded into one of the six test
packages. It requires all six, so that loading it loads every package the rule is about and the
rule can be checked against the whole project at once.

The tests of a code package live in the matching PharoVulkan-<Name>-Tests package, never here.
"
Class {
	#name : 'ManifestPharoVulkanTests',
	#superclass : 'PackageManifest',
	#category : 'PharoVulkan-Tests-Manifest',
	#package : 'PharoVulkan-Tests',
	#tag : 'Manifest'
}
