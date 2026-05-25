"
OpFunctionParameter — function parameter. id assigned during emission.
"
Class {
	#name : 'SpvIRParameter',
	#superclass : 'SpvIRNode',
	#category : 'PharoVulkan-SPIRV',
	#package : 'PharoVulkan',
	#tag : 'SPIRV'
}

{ #category : 'emitting' }
SpvIRParameter >> emitInto: blk idMap: map module: m [
	"Parameters emitted by function header, not by block."
]
