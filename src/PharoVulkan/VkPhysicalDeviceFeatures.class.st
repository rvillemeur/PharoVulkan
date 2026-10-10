"
The fifty-five core Vulkan 1.0 feature flags, as VkPhysicalDeviceFeatures declares them. This image never reads the flags one by one; the structure exists because it is embedded in VkPhysicalDeviceFeatures2, whose whole extent a driver writes. Every member is declared, so uFFI computes the size (220 bytes) instead of this image counting it — a short declaration there would let vkGetPhysicalDeviceFeatures2 write past the allocation.
"
Class {
	#name : 'VkPhysicalDeviceFeatures',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_ALPHATOONE',
		'OFFSET_DEPTHBIASCLAMP',
		'OFFSET_DEPTHBOUNDS',
		'OFFSET_DEPTHCLAMP',
		'OFFSET_DRAWINDIRECTFIRSTINSTANCE',
		'OFFSET_DUALSRCBLEND',
		'OFFSET_FILLMODENONSOLID',
		'OFFSET_FRAGMENTSTORESANDATOMICS',
		'OFFSET_FULLDRAWINDEXUINT32',
		'OFFSET_GEOMETRYSHADER',
		'OFFSET_IMAGECUBEARRAY',
		'OFFSET_INDEPENDENTBLEND',
		'OFFSET_INHERITEDQUERIES',
		'OFFSET_LARGEPOINTS',
		'OFFSET_LOGICOP',
		'OFFSET_MULTIDRAWINDIRECT',
		'OFFSET_MULTIVIEWPORT',
		'OFFSET_OCCLUSIONQUERYPRECISE',
		'OFFSET_PIPELINESTATISTICSQUERY',
		'OFFSET_ROBUSTBUFFERACCESS',
		'OFFSET_SAMPLERANISOTROPY',
		'OFFSET_SAMPLERATESHADING',
		'OFFSET_SHADERCLIPDISTANCE',
		'OFFSET_SHADERCULLDISTANCE',
		'OFFSET_SHADERFLOAT64',
		'OFFSET_SHADERIMAGEGATHEREXTENDED',
		'OFFSET_SHADERINT16',
		'OFFSET_SHADERINT64',
		'OFFSET_SHADERRESOURCEMINLOD',
		'OFFSET_SHADERRESOURCERESIDENCY',
		'OFFSET_SHADERSAMPLEDIMAGEARRAYDYNAMICINDEXING',
		'OFFSET_SHADERSTORAGEBUFFERARRAYDYNAMICINDEXING',
		'OFFSET_SHADERSTORAGEIMAGEARRAYDYNAMICINDEXING',
		'OFFSET_SHADERSTORAGEIMAGEEXTENDEDFORMATS',
		'OFFSET_SHADERSTORAGEIMAGEMULTISAMPLE',
		'OFFSET_SHADERSTORAGEIMAGEREADWITHOUTFORMAT',
		'OFFSET_SHADERSTORAGEIMAGEWRITEWITHOUTFORMAT',
		'OFFSET_SHADERTESSELLATIONANDGEOMETRYPOINTSIZE',
		'OFFSET_SHADERUNIFORMBUFFERARRAYDYNAMICINDEXING',
		'OFFSET_SPARSEBINDING',
		'OFFSET_SPARSERESIDENCY16SAMPLES',
		'OFFSET_SPARSERESIDENCY2SAMPLES',
		'OFFSET_SPARSERESIDENCY4SAMPLES',
		'OFFSET_SPARSERESIDENCY8SAMPLES',
		'OFFSET_SPARSERESIDENCYALIASED',
		'OFFSET_SPARSERESIDENCYBUFFER',
		'OFFSET_SPARSERESIDENCYIMAGE2D',
		'OFFSET_SPARSERESIDENCYIMAGE3D',
		'OFFSET_TESSELLATIONSHADER',
		'OFFSET_TEXTURECOMPRESSIONASTC_LDR',
		'OFFSET_TEXTURECOMPRESSIONBC',
		'OFFSET_TEXTURECOMPRESSIONETC2',
		'OFFSET_VARIABLEMULTISAMPLERATE',
		'OFFSET_VERTEXPIPELINESTORESANDATOMICS',
		'OFFSET_WIDELINES'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPhysicalDeviceFeatures class >> fieldsDesc [
	"The fifty-five VkBool32 members of VkPhysicalDeviceFeatures, in the order vk.xml
	 declares them. They are spelled out rather than reserved as a block of bytes, because
	 a driver writes the whole structure and a short declaration overruns object memory."

	^ #(
		uint32 robustBufferAccess;
		uint32 fullDrawIndexUint32;
		uint32 imageCubeArray;
		uint32 independentBlend;
		uint32 geometryShader;
		uint32 tessellationShader;
		uint32 sampleRateShading;
		uint32 dualSrcBlend;
		uint32 logicOp;
		uint32 multiDrawIndirect;
		uint32 drawIndirectFirstInstance;
		uint32 depthClamp;
		uint32 depthBiasClamp;
		uint32 fillModeNonSolid;
		uint32 depthBounds;
		uint32 wideLines;
		uint32 largePoints;
		uint32 alphaToOne;
		uint32 multiViewport;
		uint32 samplerAnisotropy;
		uint32 textureCompressionETC2;
		uint32 textureCompressionASTC_LDR;
		uint32 textureCompressionBC;
		uint32 occlusionQueryPrecise;
		uint32 pipelineStatisticsQuery;
		uint32 vertexPipelineStoresAndAtomics;
		uint32 fragmentStoresAndAtomics;
		uint32 shaderTessellationAndGeometryPointSize;
		uint32 shaderImageGatherExtended;
		uint32 shaderStorageImageExtendedFormats;
		uint32 shaderStorageImageMultisample;
		uint32 shaderStorageImageReadWithoutFormat;
		uint32 shaderStorageImageWriteWithoutFormat;
		uint32 shaderUniformBufferArrayDynamicIndexing;
		uint32 shaderSampledImageArrayDynamicIndexing;
		uint32 shaderStorageBufferArrayDynamicIndexing;
		uint32 shaderStorageImageArrayDynamicIndexing;
		uint32 shaderClipDistance;
		uint32 shaderCullDistance;
		uint32 shaderFloat64;
		uint32 shaderInt64;
		uint32 shaderInt16;
		uint32 shaderResourceResidency;
		uint32 shaderResourceMinLod;
		uint32 sparseBinding;
		uint32 sparseResidencyBuffer;
		uint32 sparseResidencyImage2D;
		uint32 sparseResidencyImage3D;
		uint32 sparseResidency2Samples;
		uint32 sparseResidency4Samples;
		uint32 sparseResidency8Samples;
		uint32 sparseResidency16Samples;
		uint32 sparseResidencyAliased;
		uint32 variableMultisampleRate;
		uint32 inheritedQueries
	)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> alphaToOne [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ALPHATOONE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> alphaToOne: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ALPHATOONE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> depthBiasClamp [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPTHBIASCLAMP
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> depthBiasClamp: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPTHBIASCLAMP put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> depthBounds [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPTHBOUNDS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> depthBounds: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPTHBOUNDS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> depthClamp [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEPTHCLAMP
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> depthClamp: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEPTHCLAMP put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> drawIndirectFirstInstance [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DRAWINDIRECTFIRSTINSTANCE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> drawIndirectFirstInstance: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DRAWINDIRECTFIRSTINSTANCE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> dualSrcBlend [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DUALSRCBLEND
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> dualSrcBlend: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DUALSRCBLEND put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> fillModeNonSolid [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FILLMODENONSOLID
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> fillModeNonSolid: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FILLMODENONSOLID put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> fragmentStoresAndAtomics [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FRAGMENTSTORESANDATOMICS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> fragmentStoresAndAtomics: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FRAGMENTSTORESANDATOMICS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> fullDrawIndexUint32 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FULLDRAWINDEXUINT32
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> fullDrawIndexUint32: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FULLDRAWINDEXUINT32 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> geometryShader [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_GEOMETRYSHADER
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> geometryShader: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_GEOMETRYSHADER put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> imageCubeArray [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_IMAGECUBEARRAY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> imageCubeArray: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_IMAGECUBEARRAY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> independentBlend [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_INDEPENDENTBLEND
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> independentBlend: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_INDEPENDENTBLEND put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> inheritedQueries [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_INHERITEDQUERIES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> inheritedQueries: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_INHERITEDQUERIES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> largePoints [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LARGEPOINTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> largePoints: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LARGEPOINTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> logicOp [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_LOGICOP
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> logicOp: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_LOGICOP put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> multiDrawIndirect [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MULTIDRAWINDIRECT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> multiDrawIndirect: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MULTIDRAWINDIRECT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> multiViewport [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MULTIVIEWPORT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> multiViewport: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MULTIVIEWPORT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> occlusionQueryPrecise [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_OCCLUSIONQUERYPRECISE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> occlusionQueryPrecise: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_OCCLUSIONQUERYPRECISE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> pipelineStatisticsQuery [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_PIPELINESTATISTICSQUERY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> pipelineStatisticsQuery: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_PIPELINESTATISTICSQUERY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> robustBufferAccess [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_ROBUSTBUFFERACCESS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> robustBufferAccess: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_ROBUSTBUFFERACCESS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sampleRateShading [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLERATESHADING
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sampleRateShading: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLERATESHADING put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> samplerAnisotropy [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLERANISOTROPY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> samplerAnisotropy: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLERANISOTROPY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderClipDistance [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERCLIPDISTANCE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderClipDistance: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERCLIPDISTANCE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderCullDistance [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERCULLDISTANCE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderCullDistance: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERCULLDISTANCE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderFloat64 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERFLOAT64
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderFloat64: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERFLOAT64 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderImageGatherExtended [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERIMAGEGATHEREXTENDED
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderImageGatherExtended: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERIMAGEGATHEREXTENDED put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderInt16 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERINT16
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderInt16: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERINT16 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderInt64 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERINT64
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderInt64: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERINT64 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderResourceMinLod [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERRESOURCEMINLOD
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderResourceMinLod: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERRESOURCEMINLOD put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderResourceResidency [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERRESOURCERESIDENCY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderResourceResidency: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERRESOURCERESIDENCY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderSampledImageArrayDynamicIndexing [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERSAMPLEDIMAGEARRAYDYNAMICINDEXING
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderSampledImageArrayDynamicIndexing: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERSAMPLEDIMAGEARRAYDYNAMICINDEXING put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageBufferArrayDynamicIndexing [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERSTORAGEBUFFERARRAYDYNAMICINDEXING
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageBufferArrayDynamicIndexing: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERSTORAGEBUFFERARRAYDYNAMICINDEXING put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageArrayDynamicIndexing [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEARRAYDYNAMICINDEXING
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageArrayDynamicIndexing: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEARRAYDYNAMICINDEXING put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageExtendedFormats [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEEXTENDEDFORMATS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageExtendedFormats: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEEXTENDEDFORMATS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageMultisample [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEMULTISAMPLE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageMultisample: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEMULTISAMPLE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageReadWithoutFormat [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEREADWITHOUTFORMAT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageReadWithoutFormat: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEREADWITHOUTFORMAT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageWriteWithoutFormat [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEWRITEWITHOUTFORMAT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderStorageImageWriteWithoutFormat: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERSTORAGEIMAGEWRITEWITHOUTFORMAT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderTessellationAndGeometryPointSize [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERTESSELLATIONANDGEOMETRYPOINTSIZE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderTessellationAndGeometryPointSize: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERTESSELLATIONANDGEOMETRYPOINTSIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderUniformBufferArrayDynamicIndexing [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SHADERUNIFORMBUFFERARRAYDYNAMICINDEXING
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> shaderUniformBufferArrayDynamicIndexing: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SHADERUNIFORMBUFFERARRAYDYNAMICINDEXING put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseBinding [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSEBINDING
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseBinding: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSEBINDING put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency16Samples [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCY16SAMPLES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency16Samples: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCY16SAMPLES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency2Samples [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCY2SAMPLES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency2Samples: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCY2SAMPLES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency4Samples [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCY4SAMPLES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency4Samples: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCY4SAMPLES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency8Samples [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCY8SAMPLES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidency8Samples: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCY8SAMPLES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyAliased [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCYALIASED
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyAliased: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCYALIASED put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyBuffer [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCYBUFFER
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyBuffer: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCYBUFFER put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyImage2D [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCYIMAGE2D
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyImage2D: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCYIMAGE2D put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyImage3D [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SPARSERESIDENCYIMAGE3D
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> sparseResidencyImage3D: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SPARSERESIDENCYIMAGE3D put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> tessellationShader [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TESSELLATIONSHADER
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> tessellationShader: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TESSELLATIONSHADER put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> textureCompressionASTC_LDR [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TEXTURECOMPRESSIONASTC_LDR
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> textureCompressionASTC_LDR: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TEXTURECOMPRESSIONASTC_LDR put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> textureCompressionBC [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TEXTURECOMPRESSIONBC
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> textureCompressionBC: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TEXTURECOMPRESSIONBC put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> textureCompressionETC2 [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TEXTURECOMPRESSIONETC2
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> textureCompressionETC2: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TEXTURECOMPRESSIONETC2 put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> variableMultisampleRate [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VARIABLEMULTISAMPLERATE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> variableMultisampleRate: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VARIABLEMULTISAMPLERATE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> vertexPipelineStoresAndAtomics [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VERTEXPIPELINESTORESANDATOMICS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> vertexPipelineStoresAndAtomics: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VERTEXPIPELINESTORESANDATOMICS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> wideLines [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_WIDELINES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceFeatures >> wideLines: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_WIDELINES put: anObject
]
