"
GLSL.std.450 extended instruction set opcode constants. Used by PVSPIRVEmitter to emit normalize, length, mix, clamp, sqrt via OpExtInst.
"
Class {
	#name : 'GlslStd450',
	#superclass : 'Object',
	#category : 'PharoVulkan-SPIRV-Constants',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Constants'
}

{ #category : 'constants' }
GlslStd450 class >> ceil [
	"The smallest whole float at or above one float, the other half of the pair floor belongs
	 to: a clip whose bottom edge falls inside a pixel row still allows that row."

	^ 9
]

{ #category : 'constants' }
GlslStd450 class >> fClamp [ ^ 43
]

{ #category : 'constants' }
GlslStd450 class >> fMax [
	"The larger of two floats. The clamp beside it is the pair applied at once, and a
	 rasteriser that trims a span to a clip needs the two separately."

	^ 40
]

{ #category : 'constants' }
GlslStd450 class >> fMin [
	"The smaller of two floats, which the GLSL set carries because SPIR-V has no core
	 instruction for it."

	^ 37
]

{ #category : 'constants' }
GlslStd450 class >> fMix [ ^ 46
]

{ #category : 'constants' }
GlslStd450 class >> floor [
	"The largest whole float at or below one float, which SPIR-V has no core instruction for.
	 A rasteriser reads it to find the first whole pixel row a fractional clip edge allows."

	^ 8
]

{ #category : 'constants' }
GlslStd450 class >> instSetName [ ^ 'GLSL.std.450'
]

{ #category : 'constants' }
GlslStd450 class >> length [ ^ 66
]

{ #category : 'constants' }
GlslStd450 class >> normalize [ ^ 69
]

{ #category : 'constants' }
GlslStd450 class >> sqrt [ ^ 31
]

{ #category : 'constants' }
GlslStd450 class >> uMin [
	"The smaller of two unsigned integers. The core instruction set has none, and every byte
	 a compositor sums has to be capped at the largest byte."

	^ 38
]
