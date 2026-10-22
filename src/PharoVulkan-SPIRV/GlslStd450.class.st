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
