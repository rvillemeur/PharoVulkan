"
Core properties of a VkPhysicalDevice. Returned by vkGetPhysicalDeviceProperties.
deviceName is a 256-byte null-terminated UTF-8 string — use deviceNameString.
limits and sparseProperties are opaque blobs; generator will produce typed structs in Phase 2.
Key methods: deviceNameString, apiVersion, deviceType, vendorID.
"
Class {
	#name : 'VkPhysicalDeviceProperties',
	#superclass : 'VkStructure',
	#classVars : [
		'OFFSET_APIVERSION',
		'OFFSET_DEVICEID',
		'OFFSET_DEVICENAME',
		'OFFSET_DEVICETYPE',
		'OFFSET_DRIVERVERSION',
		'OFFSET_LIMITS',
		'OFFSET_PIPELINECACHEUUID',
		'OFFSET_SPARSEPROPERTIES',
		'OFFSET_VENDORID'
	],
	#category : 'PharoVulkan-Bindings',
	#package : 'PharoVulkan-Bindings'
}

{ #category : 'fields' }
VkPhysicalDeviceProperties class >> fieldsDesc [
    ^ #(
        uint32    apiVersion;
        uint32    driverVersion;
        uint32    vendorID;
        uint32    deviceID;
        int32     deviceType;
        Uint8_256 deviceName;
        Uint8_16  pipelineCacheUUID;
        Uint8_504 limits;
        Uint8_20  sparseProperties
    )
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> apiVersion [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_APIVERSION
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> apiVersion: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_APIVERSION put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceID [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DEVICEID
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceID: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DEVICEID put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceName [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt8 size: 256) fromHandle: (handle copyFrom: OFFSET_DEVICENAME to: OFFSET_DEVICENAME + 255)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceName: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_DEVICENAME to: OFFSET_DEVICENAME + 255 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing' }
VkPhysicalDeviceProperties >> deviceNameString [
    | stream byte |
    stream := WriteStream on: String new.
    0 to: 255 do: [ :j |
        byte := handle basicAt: OFFSET_DEVICENAME + j.
        byte = 0 ifTrue: [ ^ stream contents ].
        stream nextPut: (Character value: byte) ].
    ^ stream contents
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceType [
	"This method was automatically generated"
	^handle signedLongAt: OFFSET_DEVICETYPE
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> deviceType: anObject [
	"This method was automatically generated"
	handle signedLongAt: OFFSET_DEVICETYPE put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> driverVersion [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_DRIVERVERSION
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> driverVersion: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_DRIVERVERSION put: anObject
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> limits [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt8 size: 504) fromHandle: (handle copyFrom: OFFSET_LIMITS to: OFFSET_LIMITS + 503)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> limits: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_LIMITS to: OFFSET_LIMITS + 503 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> pipelineCacheUUID [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt8 size: 16) fromHandle: (handle copyFrom: OFFSET_PIPELINECACHEUUID to: OFFSET_PIPELINECACHEUUID + 15)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> pipelineCacheUUID: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_PIPELINECACHEUUID to: OFFSET_PIPELINECACHEUUID + 15 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> sparseProperties [
	"This method was automatically generated"
	^(FFIArray ofType: #FFIUInt8 size: 20) fromHandle: (handle copyFrom: OFFSET_SPARSEPROPERTIES to: OFFSET_SPARSEPROPERTIES + 19)
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> sparseProperties: anObject [
	"This method was automatically generated"
	handle replaceFrom: OFFSET_SPARSEPROPERTIES to: OFFSET_SPARSEPROPERTIES + 19 with: anObject getHandle startingAt: 1
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> vendorID [
	"This method was automatically generated"
	^handle unsignedLongAt: OFFSET_VENDORID
]

{ #category : 'accessing - structure variables' }
VkPhysicalDeviceProperties >> vendorID: anObject [
	"This method was automatically generated"
	handle unsignedLongAt: OFFSET_VENDORID put: anObject
]
