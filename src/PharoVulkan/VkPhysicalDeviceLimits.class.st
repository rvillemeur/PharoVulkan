"
The VkPhysicalDeviceLimits block of VkPhysicalDeviceProperties, declared field by field rather than as a byte blob, so every limit is reached through a generated accessor at an offset uFFI computed instead of a hand counted one.
Key methods: maxComputeSharedMemorySize, maxComputeWorkGroupInvocations, maxComputeWorkGroupSize. It is a by-value member of VkPhysicalDeviceProperties and the driver never allocates it on its own.
"
Class {
	#name : 'VkPhysicalDeviceLimits',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_BUFFERIMAGEGRANULARITY',
		'OFFSET_DISCRETEQUEUEPRIORITIES',
		'OFFSET_FRAMEBUFFERCOLORSAMPLECOUNTS',
		'OFFSET_FRAMEBUFFERDEPTHSAMPLECOUNTS',
		'OFFSET_FRAMEBUFFERNOATTACHMENTSSAMPLECOUNTS',
		'OFFSET_FRAMEBUFFERSTENCILSAMPLECOUNTS',
		'OFFSET_LINEWIDTHGRANULARITY',
		'OFFSET_LINEWIDTHRANGE',
		'OFFSET_MAXBOUNDDESCRIPTORSETS',
		'OFFSET_MAXCLIPDISTANCES',
		'OFFSET_MAXCOLORATTACHMENTS',
		'OFFSET_MAXCOMBINEDCLIPANDCULLDISTANCES',
		'OFFSET_MAXCOMPUTESHAREDMEMORYSIZE',
		'OFFSET_MAXCOMPUTEWORKGROUPCOUNT',
		'OFFSET_MAXCOMPUTEWORKGROUPINVOCATIONS',
		'OFFSET_MAXCOMPUTEWORKGROUPSIZE',
		'OFFSET_MAXCULLDISTANCES',
		'OFFSET_MAXDESCRIPTORSETINPUTATTACHMENTS',
		'OFFSET_MAXDESCRIPTORSETSAMPLEDIMAGES',
		'OFFSET_MAXDESCRIPTORSETSAMPLERS',
		'OFFSET_MAXDESCRIPTORSETSTORAGEBUFFERS',
		'OFFSET_MAXDESCRIPTORSETSTORAGEBUFFERSDYNAMIC',
		'OFFSET_MAXDESCRIPTORSETSTORAGEIMAGES',
		'OFFSET_MAXDESCRIPTORSETUNIFORMBUFFERS',
		'OFFSET_MAXDESCRIPTORSETUNIFORMBUFFERSDYNAMIC',
		'OFFSET_MAXDRAWINDEXEDINDEXVALUE',
		'OFFSET_MAXDRAWINDIRECTCOUNT',
		'OFFSET_MAXFRAGMENTCOMBINEDOUTPUTRESOURCES',
		'OFFSET_MAXFRAGMENTDUALSRCATTACHMENTS',
		'OFFSET_MAXFRAGMENTINPUTCOMPONENTS',
		'OFFSET_MAXFRAGMENTOUTPUTATTACHMENTS',
		'OFFSET_MAXFRAMEBUFFERHEIGHT',
		'OFFSET_MAXFRAMEBUFFERLAYERS',
		'OFFSET_MAXFRAMEBUFFERWIDTH',
		'OFFSET_MAXGEOMETRYINPUTCOMPONENTS',
		'OFFSET_MAXGEOMETRYOUTPUTCOMPONENTS',
		'OFFSET_MAXGEOMETRYOUTPUTVERTICES',
		'OFFSET_MAXGEOMETRYSHADERINVOCATIONS',
		'OFFSET_MAXGEOMETRYTOTALOUTPUTCOMPONENTS',
		'OFFSET_MAXIMAGEARRAYLAYERS',
		'OFFSET_MAXIMAGEDIMENSION1D',
		'OFFSET_MAXIMAGEDIMENSION2D',
		'OFFSET_MAXIMAGEDIMENSION3D',
		'OFFSET_MAXIMAGEDIMENSIONCUBE',
		'OFFSET_MAXINTERPOLATIONOFFSET',
		'OFFSET_MAXMEMORYALLOCATIONCOUNT',
		'OFFSET_MAXPERSTAGEDESCRIPTORINPUTATTACHMENTS',
		'OFFSET_MAXPERSTAGEDESCRIPTORSAMPLEDIMAGES',
		'OFFSET_MAXPERSTAGEDESCRIPTORSAMPLERS',
		'OFFSET_MAXPERSTAGEDESCRIPTORSTORAGEBUFFERS',
		'OFFSET_MAXPERSTAGEDESCRIPTORSTORAGEIMAGES',
		'OFFSET_MAXPERSTAGEDESCRIPTORUNIFORMBUFFERS',
		'OFFSET_MAXPERSTAGERESOURCES',
		'OFFSET_MAXPUSHCONSTANTSSIZE',
		'OFFSET_MAXSAMPLEMASKWORDS',
		'OFFSET_MAXSAMPLERALLOCATIONCOUNT',
		'OFFSET_MAXSAMPLERANISOTROPY',
		'OFFSET_MAXSAMPLERLODBIAS',
		'OFFSET_MAXSTORAGEBUFFERRANGE',
		'OFFSET_MAXTESSELLATIONCONTROLPERPATCHOUTPUTCOMPONENTS',
		'OFFSET_MAXTESSELLATIONCONTROLPERVERTEXINPUTCOMPONENTS',
		'OFFSET_MAXTESSELLATIONCONTROLPERVERTEXOUTPUTCOMPONENTS',
		'OFFSET_MAXTESSELLATIONCONTROLTOTALOUTPUTCOMPONENTS',
		'OFFSET_MAXTESSELLATIONEVALUATIONINPUTCOMPONENTS',
		'OFFSET_MAXTESSELLATIONEVALUATIONOUTPUTCOMPONENTS',
		'OFFSET_MAXTESSELLATIONGENERATIONLEVEL',
		'OFFSET_MAXTESSELLATIONPATCHSIZE',
		'OFFSET_MAXTEXELBUFFERELEMENTS',
		'OFFSET_MAXTEXELGATHEROFFSET',
		'OFFSET_MAXTEXELOFFSET',
		'OFFSET_MAXUNIFORMBUFFERRANGE',
		'OFFSET_MAXVERTEXINPUTATTRIBUTEOFFSET',
		'OFFSET_MAXVERTEXINPUTATTRIBUTES',
		'OFFSET_MAXVERTEXINPUTBINDINGS',
		'OFFSET_MAXVERTEXINPUTBINDINGSTRIDE',
		'OFFSET_MAXVERTEXOUTPUTCOMPONENTS',
		'OFFSET_MAXVIEWPORTDIMENSIONS',
		'OFFSET_MAXVIEWPORTS',
		'OFFSET_MININTERPOLATIONOFFSET',
		'OFFSET_MINMEMORYMAPALIGNMENT',
		'OFFSET_MINSTORAGEBUFFEROFFSETALIGNMENT',
		'OFFSET_MINTEXELBUFFEROFFSETALIGNMENT',
		'OFFSET_MINTEXELGATHEROFFSET',
		'OFFSET_MINTEXELOFFSET',
		'OFFSET_MINUNIFORMBUFFEROFFSETALIGNMENT',
		'OFFSET_MIPMAPPRECISIONBITS',
		'OFFSET_NONCOHERENTATOMSIZE',
		'OFFSET_OPTIMALBUFFERCOPYOFFSETALIGNMENT',
		'OFFSET_OPTIMALBUFFERCOPYROWPITCHALIGNMENT',
		'OFFSET_POINTSIZEGRANULARITY',
		'OFFSET_POINTSIZERANGE',
		'OFFSET_SAMPLEDIMAGECOLORSAMPLECOUNTS',
		'OFFSET_SAMPLEDIMAGEDEPTHSAMPLECOUNTS',
		'OFFSET_SAMPLEDIMAGEINTEGERSAMPLECOUNTS',
		'OFFSET_SAMPLEDIMAGESTENCILSAMPLECOUNTS',
		'OFFSET_SPARSEADDRESSSPACESIZE',
		'OFFSET_STANDARDSAMPLELOCATIONS',
		'OFFSET_STORAGEIMAGESAMPLECOUNTS',
		'OFFSET_STRICTLINES',
		'OFFSET_SUBPIXELINTERPOLATIONOFFSETBITS',
		'OFFSET_SUBPIXELPRECISIONBITS',
		'OFFSET_SUBTEXELPRECISIONBITS',
		'OFFSET_TIMESTAMPCOMPUTEANDGRAPHICS',
		'OFFSET_TIMESTAMPPERIOD',
		'OFFSET_VIEWPORTBOUNDSRANGE',
		'OFFSET_VIEWPORTSUBPIXELBITS'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan',
	#tag : 'Bindings'
}

{ #category : 'field definition' }
VkPhysicalDeviceLimits class >> fieldsDesc [
	"The members of VkPhysicalDeviceLimits in specification order. The eight byte aligned
	 VkDeviceSize and size_t members are declared as the scalars they are, so uFFI inserts the
	 pads the C layout has; a byte array member would carry alignment one and lose them."

	^ #(
		uint32 maxImageDimension1D;
		uint32 maxImageDimension2D;
		uint32 maxImageDimension3D;
		uint32 maxImageDimensionCube;
		uint32 maxImageArrayLayers;
		uint32 maxTexelBufferElements;
		uint32 maxUniformBufferRange;
		uint32 maxStorageBufferRange;
		uint32 maxPushConstantsSize;
		uint32 maxMemoryAllocationCount;
		uint32 maxSamplerAllocationCount;
		uint64 bufferImageGranularity;
		uint64 sparseAddressSpaceSize;
		uint32 maxBoundDescriptorSets;
		uint32 maxPerStageDescriptorSamplers;
		uint32 maxPerStageDescriptorUniformBuffers;
		uint32 maxPerStageDescriptorStorageBuffers;
		uint32 maxPerStageDescriptorSampledImages;
		uint32 maxPerStageDescriptorStorageImages;
		uint32 maxPerStageDescriptorInputAttachments;
		uint32 maxPerStageResources;
		uint32 maxDescriptorSetSamplers;
		uint32 maxDescriptorSetUniformBuffers;
		uint32 maxDescriptorSetUniformBuffersDynamic;
		uint32 maxDescriptorSetStorageBuffers;
		uint32 maxDescriptorSetStorageBuffersDynamic;
		uint32 maxDescriptorSetSampledImages;
		uint32 maxDescriptorSetStorageImages;
		uint32 maxDescriptorSetInputAttachments;
		uint32 maxVertexInputAttributes;
		uint32 maxVertexInputBindings;
		uint32 maxVertexInputAttributeOffset;
		uint32 maxVertexInputBindingStride;
		uint32 maxVertexOutputComponents;
		uint32 maxTessellationGenerationLevel;
		uint32 maxTessellationPatchSize;
		uint32 maxTessellationControlPerVertexInputComponents;
		uint32 maxTessellationControlPerVertexOutputComponents;
		uint32 maxTessellationControlPerPatchOutputComponents;
		uint32 maxTessellationControlTotalOutputComponents;
		uint32 maxTessellationEvaluationInputComponents;
		uint32 maxTessellationEvaluationOutputComponents;
		uint32 maxGeometryShaderInvocations;
		uint32 maxGeometryInputComponents;
		uint32 maxGeometryOutputComponents;
		uint32 maxGeometryOutputVertices;
		uint32 maxGeometryTotalOutputComponents;
		uint32 maxFragmentInputComponents;
		uint32 maxFragmentOutputAttachments;
		uint32 maxFragmentDualSrcAttachments;
		uint32 maxFragmentCombinedOutputResources;
		uint32 maxComputeSharedMemorySize;
		Uint32_3 maxComputeWorkGroupCount;
		uint32 maxComputeWorkGroupInvocations;
		Uint32_3 maxComputeWorkGroupSize;
		uint32 subPixelPrecisionBits;
		uint32 subTexelPrecisionBits;
		uint32 mipmapPrecisionBits;
		uint32 maxDrawIndexedIndexValue;
		uint32 maxDrawIndirectCount;
		float maxSamplerLodBias;
		float maxSamplerAnisotropy;
		uint32 maxViewports;
		Uint32_2 maxViewportDimensions;
		Float_2 viewportBoundsRange;
		uint32 viewportSubPixelBits;
		uint64 minMemoryMapAlignment;
		uint64 minTexelBufferOffsetAlignment;
		uint64 minUniformBufferOffsetAlignment;
		uint64 minStorageBufferOffsetAlignment;
		int32 minTexelOffset;
		uint32 maxTexelOffset;
		int32 minTexelGatherOffset;
		uint32 maxTexelGatherOffset;
		float minInterpolationOffset;
		float maxInterpolationOffset;
		uint32 subPixelInterpolationOffsetBits;
		uint32 maxFramebufferWidth;
		uint32 maxFramebufferHeight;
		uint32 maxFramebufferLayers;
		uint32 framebufferColorSampleCounts;
		uint32 framebufferDepthSampleCounts;
		uint32 framebufferStencilSampleCounts;
		uint32 framebufferNoAttachmentsSampleCounts;
		uint32 maxColorAttachments;
		uint32 sampledImageColorSampleCounts;
		uint32 sampledImageIntegerSampleCounts;
		uint32 sampledImageDepthSampleCounts;
		uint32 sampledImageStencilSampleCounts;
		uint32 storageImageSampleCounts;
		uint32 maxSampleMaskWords;
		uint32 timestampComputeAndGraphics;
		float timestampPeriod;
		uint32 maxClipDistances;
		uint32 maxCullDistances;
		uint32 maxCombinedClipAndCullDistances;
		uint32 discreteQueuePriorities;
		Float_2 pointSizeRange;
		Float_2 lineWidthRange;
		float pointSizeGranularity;
		float lineWidthGranularity;
		uint32 strictLines;
		uint32 standardSampleLocations;
		uint64 optimalBufferCopyOffsetAlignment;
		uint64 optimalBufferCopyRowPitchAlignment;
		uint64 nonCoherentAtomSize
	)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> bufferImageGranularity [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_BUFFERIMAGEGRANULARITY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> bufferImageGranularity: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_BUFFERIMAGEGRANULARITY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> discreteQueuePriorities [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DISCRETEQUEUEPRIORITIES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> discreteQueuePriorities: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DISCRETEQUEUEPRIORITIES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferColorSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FRAMEBUFFERCOLORSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferColorSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FRAMEBUFFERCOLORSAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferDepthSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FRAMEBUFFERDEPTHSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferDepthSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FRAMEBUFFERDEPTHSAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferNoAttachmentsSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FRAMEBUFFERNOATTACHMENTSSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferNoAttachmentsSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FRAMEBUFFERNOATTACHMENTSSAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferStencilSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_FRAMEBUFFERSTENCILSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> framebufferStencilSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_FRAMEBUFFERSTENCILSAMPLECOUNTS put: anObject
]

{ #category : 'inspector' }
VkPhysicalDeviceLimits >> inspectorLimits: aBuilder [
	"One row per member, named by the compiled field specification and valued by performing the
	 generated accessor, so neither column can drift from the structure. The store is only read."

	<inspectorPresentationOrder: 10 title: 'Limits'>
	^ aBuilder newTable
		  addColumn: (SpStringTableColumn title: 'Limit' evaluated: [ :each |
					   each ]);
		  addColumn: (SpStringTableColumn title: 'Value' evaluated: [ :each |
					   self printableValueOf: each ]);
		  items: self class fieldSpec fieldNames;
		  yourself
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> lineWidthGranularity [
	"This method was automatically generated"
	^handle floatAt: OFFSET_LINEWIDTHGRANULARITY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> lineWidthGranularity: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_LINEWIDTHGRANULARITY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> lineWidthRange [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIFloat32 size: 2) fromHandle: (handle copyFrom: OFFSET_LINEWIDTHRANGE to: OFFSET_LINEWIDTHRANGE + 7)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> lineWidthRange: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_LINEWIDTHRANGE to: OFFSET_LINEWIDTHRANGE + 7 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxBoundDescriptorSets [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXBOUNDDESCRIPTORSETS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxBoundDescriptorSets: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXBOUNDDESCRIPTORSETS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxClipDistances [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXCLIPDISTANCES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxClipDistances: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXCLIPDISTANCES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxColorAttachments [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXCOLORATTACHMENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxColorAttachments: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXCOLORATTACHMENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxCombinedClipAndCullDistances [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXCOMBINEDCLIPANDCULLDISTANCES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxCombinedClipAndCullDistances: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXCOMBINEDCLIPANDCULLDISTANCES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeSharedMemorySize [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXCOMPUTESHAREDMEMORYSIZE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeSharedMemorySize: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXCOMPUTESHAREDMEMORYSIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeWorkGroupCount [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt32 size: 3) fromHandle: (handle copyFrom: OFFSET_MAXCOMPUTEWORKGROUPCOUNT to: OFFSET_MAXCOMPUTEWORKGROUPCOUNT + 11)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeWorkGroupCount: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_MAXCOMPUTEWORKGROUPCOUNT to: OFFSET_MAXCOMPUTEWORKGROUPCOUNT + 11 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeWorkGroupInvocations [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXCOMPUTEWORKGROUPINVOCATIONS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeWorkGroupInvocations: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXCOMPUTEWORKGROUPINVOCATIONS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeWorkGroupSize [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt32 size: 3) fromHandle: (handle copyFrom: OFFSET_MAXCOMPUTEWORKGROUPSIZE to: OFFSET_MAXCOMPUTEWORKGROUPSIZE + 11)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxComputeWorkGroupSize: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_MAXCOMPUTEWORKGROUPSIZE to: OFFSET_MAXCOMPUTEWORKGROUPSIZE + 11 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxCullDistances [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXCULLDISTANCES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxCullDistances: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXCULLDISTANCES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetInputAttachments [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETINPUTATTACHMENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetInputAttachments: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETINPUTATTACHMENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetSampledImages [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSAMPLEDIMAGES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetSampledImages: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSAMPLEDIMAGES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetSamplers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSAMPLERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetSamplers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSAMPLERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetStorageBuffers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSTORAGEBUFFERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetStorageBuffers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSTORAGEBUFFERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetStorageBuffersDynamic [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSTORAGEBUFFERSDYNAMIC
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetStorageBuffersDynamic: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSTORAGEBUFFERSDYNAMIC put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetStorageImages [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSTORAGEIMAGES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetStorageImages: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETSTORAGEIMAGES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetUniformBuffers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETUNIFORMBUFFERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetUniformBuffers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETUNIFORMBUFFERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetUniformBuffersDynamic [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETUNIFORMBUFFERSDYNAMIC
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDescriptorSetUniformBuffersDynamic: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDESCRIPTORSETUNIFORMBUFFERSDYNAMIC put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDrawIndexedIndexValue [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDRAWINDEXEDINDEXVALUE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDrawIndexedIndexValue: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDRAWINDEXEDINDEXVALUE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDrawIndirectCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXDRAWINDIRECTCOUNT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxDrawIndirectCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXDRAWINDIRECTCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentCombinedOutputResources [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXFRAGMENTCOMBINEDOUTPUTRESOURCES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentCombinedOutputResources: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXFRAGMENTCOMBINEDOUTPUTRESOURCES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentDualSrcAttachments [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXFRAGMENTDUALSRCATTACHMENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentDualSrcAttachments: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXFRAGMENTDUALSRCATTACHMENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentInputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXFRAGMENTINPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentInputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXFRAGMENTINPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentOutputAttachments [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXFRAGMENTOUTPUTATTACHMENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFragmentOutputAttachments: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXFRAGMENTOUTPUTATTACHMENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFramebufferHeight [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXFRAMEBUFFERHEIGHT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFramebufferHeight: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXFRAMEBUFFERHEIGHT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFramebufferLayers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXFRAMEBUFFERLAYERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFramebufferLayers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXFRAMEBUFFERLAYERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFramebufferWidth [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXFRAMEBUFFERWIDTH
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxFramebufferWidth: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXFRAMEBUFFERWIDTH put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryInputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXGEOMETRYINPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryInputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXGEOMETRYINPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryOutputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXGEOMETRYOUTPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryOutputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXGEOMETRYOUTPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryOutputVertices [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXGEOMETRYOUTPUTVERTICES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryOutputVertices: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXGEOMETRYOUTPUTVERTICES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryShaderInvocations [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXGEOMETRYSHADERINVOCATIONS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryShaderInvocations: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXGEOMETRYSHADERINVOCATIONS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryTotalOutputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXGEOMETRYTOTALOUTPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxGeometryTotalOutputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXGEOMETRYTOTALOUTPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageArrayLayers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXIMAGEARRAYLAYERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageArrayLayers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXIMAGEARRAYLAYERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimension1D [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSION1D
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimension1D: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSION1D put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimension2D [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSION2D
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimension2D: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSION2D put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimension3D [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSION3D
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimension3D: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSION3D put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimensionCube [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSIONCUBE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxImageDimensionCube: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXIMAGEDIMENSIONCUBE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxInterpolationOffset [
	"This method was automatically generated"
	^handle floatAt: OFFSET_MAXINTERPOLATIONOFFSET
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxInterpolationOffset: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_MAXINTERPOLATIONOFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxMemoryAllocationCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXMEMORYALLOCATIONCOUNT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxMemoryAllocationCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXMEMORYALLOCATIONCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorInputAttachments [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORINPUTATTACHMENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorInputAttachments: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORINPUTATTACHMENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorSampledImages [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSAMPLEDIMAGES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorSampledImages: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSAMPLEDIMAGES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorSamplers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSAMPLERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorSamplers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSAMPLERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorStorageBuffers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSTORAGEBUFFERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorStorageBuffers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSTORAGEBUFFERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorStorageImages [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSTORAGEIMAGES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorStorageImages: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORSTORAGEIMAGES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorUniformBuffers [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORUNIFORMBUFFERS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageDescriptorUniformBuffers: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPERSTAGEDESCRIPTORUNIFORMBUFFERS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageResources [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPERSTAGERESOURCES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPerStageResources: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPERSTAGERESOURCES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPushConstantsSize [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXPUSHCONSTANTSSIZE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxPushConstantsSize: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXPUSHCONSTANTSSIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSampleMaskWords [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXSAMPLEMASKWORDS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSampleMaskWords: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXSAMPLEMASKWORDS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSamplerAllocationCount [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXSAMPLERALLOCATIONCOUNT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSamplerAllocationCount: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXSAMPLERALLOCATIONCOUNT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSamplerAnisotropy [
	"This method was automatically generated"
	^handle floatAt: OFFSET_MAXSAMPLERANISOTROPY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSamplerAnisotropy: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_MAXSAMPLERANISOTROPY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSamplerLodBias [
	"This method was automatically generated"
	^handle floatAt: OFFSET_MAXSAMPLERLODBIAS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxSamplerLodBias: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_MAXSAMPLERLODBIAS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxStorageBufferRange [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXSTORAGEBUFFERRANGE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxStorageBufferRange: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXSTORAGEBUFFERRANGE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlPerPatchOutputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLPERPATCHOUTPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlPerPatchOutputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLPERPATCHOUTPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlPerVertexInputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLPERVERTEXINPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlPerVertexInputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLPERVERTEXINPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlPerVertexOutputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLPERVERTEXOUTPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlPerVertexOutputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLPERVERTEXOUTPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlTotalOutputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLTOTALOUTPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationControlTotalOutputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONCONTROLTOTALOUTPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationEvaluationInputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONEVALUATIONINPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationEvaluationInputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONEVALUATIONINPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationEvaluationOutputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONEVALUATIONOUTPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationEvaluationOutputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONEVALUATIONOUTPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationGenerationLevel [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONGENERATIONLEVEL
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationGenerationLevel: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONGENERATIONLEVEL put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationPatchSize [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTESSELLATIONPATCHSIZE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTessellationPatchSize: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTESSELLATIONPATCHSIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTexelBufferElements [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTEXELBUFFERELEMENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTexelBufferElements: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTEXELBUFFERELEMENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTexelGatherOffset [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTEXELGATHEROFFSET
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTexelGatherOffset: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTEXELGATHEROFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTexelOffset [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXTEXELOFFSET
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxTexelOffset: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXTEXELOFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxUniformBufferRange [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXUNIFORMBUFFERRANGE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxUniformBufferRange: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXUNIFORMBUFFERRANGE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputAttributeOffset [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXVERTEXINPUTATTRIBUTEOFFSET
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputAttributeOffset: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXVERTEXINPUTATTRIBUTEOFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputAttributes [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXVERTEXINPUTATTRIBUTES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputAttributes: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXVERTEXINPUTATTRIBUTES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputBindingStride [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXVERTEXINPUTBINDINGSTRIDE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputBindingStride: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXVERTEXINPUTBINDINGSTRIDE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputBindings [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXVERTEXINPUTBINDINGS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexInputBindings: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXVERTEXINPUTBINDINGS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexOutputComponents [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXVERTEXOUTPUTCOMPONENTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxVertexOutputComponents: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXVERTEXOUTPUTCOMPONENTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxViewportDimensions [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt32 size: 2) fromHandle: (handle copyFrom: OFFSET_MAXVIEWPORTDIMENSIONS to: OFFSET_MAXVIEWPORTDIMENSIONS + 7)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxViewportDimensions: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_MAXVIEWPORTDIMENSIONS to: OFFSET_MAXVIEWPORTDIMENSIONS + 7 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxViewports [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MAXVIEWPORTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> maxViewports: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MAXVIEWPORTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minInterpolationOffset [
	"This method was automatically generated"
	^handle floatAt: OFFSET_MININTERPOLATIONOFFSET
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minInterpolationOffset: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_MININTERPOLATIONOFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minMemoryMapAlignment [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_MINMEMORYMAPALIGNMENT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minMemoryMapAlignment: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_MINMEMORYMAPALIGNMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minStorageBufferOffsetAlignment [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_MINSTORAGEBUFFEROFFSETALIGNMENT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minStorageBufferOffsetAlignment: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_MINSTORAGEBUFFEROFFSETALIGNMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minTexelBufferOffsetAlignment [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_MINTEXELBUFFEROFFSETALIGNMENT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minTexelBufferOffsetAlignment: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_MINTEXELBUFFEROFFSETALIGNMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minTexelGatherOffset [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_MINTEXELGATHEROFFSET
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minTexelGatherOffset: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_MINTEXELGATHEROFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minTexelOffset [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_MINTEXELOFFSET
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minTexelOffset: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_MINTEXELOFFSET put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minUniformBufferOffsetAlignment [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_MINUNIFORMBUFFEROFFSETALIGNMENT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> minUniformBufferOffsetAlignment: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_MINUNIFORMBUFFEROFFSETALIGNMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> mipmapPrecisionBits [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_MIPMAPPRECISIONBITS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> mipmapPrecisionBits: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_MIPMAPPRECISIONBITS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> nonCoherentAtomSize [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_NONCOHERENTATOMSIZE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> nonCoherentAtomSize: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_NONCOHERENTATOMSIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> optimalBufferCopyOffsetAlignment [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_OPTIMALBUFFERCOPYOFFSETALIGNMENT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> optimalBufferCopyOffsetAlignment: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_OPTIMALBUFFERCOPYOFFSETALIGNMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> optimalBufferCopyRowPitchAlignment [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_OPTIMALBUFFERCOPYROWPITCHALIGNMENT
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> optimalBufferCopyRowPitchAlignment: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_OPTIMALBUFFERCOPYROWPITCHALIGNMENT put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> pointSizeGranularity [
	"This method was automatically generated"
	^handle floatAt: OFFSET_POINTSIZEGRANULARITY
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> pointSizeGranularity: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_POINTSIZEGRANULARITY put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> pointSizeRange [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIFloat32 size: 2) fromHandle: (handle copyFrom: OFFSET_POINTSIZERANGE to: OFFSET_POINTSIZERANGE + 7)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> pointSizeRange: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_POINTSIZERANGE to: OFFSET_POINTSIZERANGE + 7 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing' }
VkPhysicalDeviceLimits >> printableValueOf: aFieldName [
	"The value as the generated accessor answers it, so a row of the Limits view cannot state
	 something the structure does not hold. An array member answers an FFIArray, which prints
	 as its own elements."

	| value |
	value := self perform: aFieldName.
	^ (value isKindOf: FFIArray)
		  ifTrue: [ ((1 to: value size) collect: [ :i | value at: i ]) printString ]
		  ifFalse: [ value printString ]
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageColorSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLEDIMAGECOLORSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageColorSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLEDIMAGECOLORSAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageDepthSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLEDIMAGEDEPTHSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageDepthSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLEDIMAGEDEPTHSAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageIntegerSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLEDIMAGEINTEGERSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageIntegerSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLEDIMAGEINTEGERSAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageStencilSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SAMPLEDIMAGESTENCILSAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sampledImageStencilSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SAMPLEDIMAGESTENCILSAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sparseAddressSpaceSize [
	"This method was automatically generated"
	^handle unsignedLongLongAt: OFFSET_SPARSEADDRESSSPACESIZE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> sparseAddressSpaceSize: anObject [
	"This method was automatically generated"
	handle unsignedLongLongAt: OFFSET_SPARSEADDRESSSPACESIZE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> standardSampleLocations [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STANDARDSAMPLELOCATIONS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> standardSampleLocations: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STANDARDSAMPLELOCATIONS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> storageImageSampleCounts [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STORAGEIMAGESAMPLECOUNTS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> storageImageSampleCounts: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STORAGEIMAGESAMPLECOUNTS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> strictLines [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_STRICTLINES
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> strictLines: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_STRICTLINES put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> subPixelInterpolationOffsetBits [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUBPIXELINTERPOLATIONOFFSETBITS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> subPixelInterpolationOffsetBits: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUBPIXELINTERPOLATIONOFFSETBITS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> subPixelPrecisionBits [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUBPIXELPRECISIONBITS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> subPixelPrecisionBits: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUBPIXELPRECISIONBITS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> subTexelPrecisionBits [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_SUBTEXELPRECISIONBITS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> subTexelPrecisionBits: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_SUBTEXELPRECISIONBITS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> timestampComputeAndGraphics [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_TIMESTAMPCOMPUTEANDGRAPHICS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> timestampComputeAndGraphics: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_TIMESTAMPCOMPUTEANDGRAPHICS put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> timestampPeriod [
	"This method was automatically generated"
	^handle floatAt: OFFSET_TIMESTAMPPERIOD
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> timestampPeriod: anObject [
	"This method was automatically generated"
	handle floatAt: OFFSET_TIMESTAMPPERIOD put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> viewportBoundsRange [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIFloat32 size: 2) fromHandle: (handle copyFrom: OFFSET_VIEWPORTBOUNDSRANGE to: OFFSET_VIEWPORTBOUNDSRANGE + 7)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> viewportBoundsRange: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_VIEWPORTBOUNDSRANGE to: OFFSET_VIEWPORTBOUNDSRANGE + 7 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> viewportSubPixelBits [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VIEWPORTSUBPIXELBITS
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceLimits >> viewportSubPixelBits: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VIEWPORTSUBPIXELBITS put: anObject
]
