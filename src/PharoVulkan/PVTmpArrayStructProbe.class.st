Class {
	#name : 'PVTmpArrayStructProbe',
	#superclass : 'FFIExternalStructure',
	#category : 'PharoVulkan',
	#package : 'PharoVulkan'
}

{ #category : 'accessing' }
PVTmpArrayStructProbe class >> fieldsDesc [
	^ #(
	uint32 sType;
	void *pNext;
	uint32 features[55]
	)
]
