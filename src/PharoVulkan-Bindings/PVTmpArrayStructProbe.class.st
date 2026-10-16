Class {
	#name : 'PVTmpArrayStructProbe',
	#superclass : 'FFIExternalStructure',
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'accessing' }
PVTmpArrayStructProbe class >> fieldsDesc [
	^ #(
	uint32 sType;
	void *pNext;
	uint32 features[55]
	)
]
