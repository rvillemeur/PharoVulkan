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
