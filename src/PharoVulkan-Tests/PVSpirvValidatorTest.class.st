"
Validates SPIR-V output of PVKernelCompiler against spirv-val. Each test compiles a PVKernelExamples method and pipes the resulting ByteArray through spirv-val --target-env vulkan1.3. All tests skip automatically when spirv-val is not installed.
"
Class {
	#name : 'PVSpirvValidatorTest',
	#superclass : 'TestCase',
	#category : 'PharoVulkan-Tests-Compiler',
	#package : 'PharoVulkan-Tests',
	#tag : 'Compiler'
}

{ #category : 'constants' }
PVSpirvValidatorTest class >> spirvValExecutable [
	^ '/usr/bin/spirv-val'
]

{ #category : 'constants' }
PVSpirvValidatorTest class >> targetEnv [
	^ 'vulkan1.3'
]

{ #category : 'private' }
PVSpirvValidatorTest >> spirvValAvailable [
	^ self class spirvValExecutable asFileReference exists
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testGlslTriFragment [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #glslTriFragment:)) description: 'glslTriFragment:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testGlslTriVertex [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #glslTriVertex:color:)) description: 'glslTriVertex:color:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testTriFragment [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #triFragment:)) description: 'triFragment:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testTriVertex [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #triVertex:color:)) description: 'triVertex:color:'
]

{ #category : 'tests' }
PVSpirvValidatorTest >> testVectorAdd [
	self validateSpirv: (PVKernelCompiler compile: (PVKernelExamples >> #vectorAdd:a:b:out:)) description: 'vectorAdd:a:b:out:'
]

{ #category : 'private' }
PVSpirvValidatorTest >> validateSpirv: bytes description: desc [
	| tmpFile cmd result |
	self spirvValAvailable ifFalse: [ self skip ].
	tmpFile := FileLocator temp / 'pv_spirv_test.spv'.
	tmpFile binaryWriteStreamDo: [ :s | s nextPutAll: bytes ].
	cmd := self class spirvValExecutable , ' --target-env ' , self class targetEnv , ' ' , tmpFile fullName , ' >/dev/null 2>&1'.
	result := LibC system: cmd.
	tmpFile ensureDelete.
	self assert: result = 0 description: desc , ' produced invalid SPIR-V (spirv-val exit ' , result printString , ')'
]
