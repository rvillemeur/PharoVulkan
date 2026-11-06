"
Surveys every physical device the Vulkan loader offers for VK_KHR_cooperative_matrix, and names the reason the cooperative matrix path is skipped. Build it with on: aVkContext and read the answer through availableSomewhere, availableOnContextDevice, supportingDeviceNames, skipReason or the Cooperative matrix tab.

A machine can offer the extension on a device the context does not use, which is what happens here: the hardware device lacks it and the software device has it. The two questions are kept apart, because neither answers the other.
"
Class {
	#name : 'PVCooperativeMatrixSurvey',
	#superclass : 'Object',
	#instVars : [
		'context',
		'deviceReports',
		'chosenDeviceName'
	],
	#category : 'PharoVulkan-Core-CooperativeMatrix',
	#package : 'PharoVulkan-Core',
	#tag : 'CooperativeMatrix'
}

{ #category : 'instance creation' }
PVCooperativeMatrixSurvey class >> on: aContext [
	^ self new setContext: aContext
]

{ #category : 'querying' }
PVCooperativeMatrixSurvey >> availableOnContextDevice [
	"The report of the device the context chose, so this answers the question a kernel path
	 would gate on rather than the machine-wide one."

	^ (deviceReports detect: [ :each | each at: #chosen ] ifNone: [ ^ false ])
		  at: #supported
]

{ #category : 'querying' }
PVCooperativeMatrixSurvey >> availableSomewhere [
	"Whether any device on this machine reports the extension, which is not the same as being
	 able to run a kernel: the device that reports it has to be the one a context is built on."

	^ deviceReports anySatisfy: [ :each | each at: #supported ]
]

{ #category : 'accessing' }
PVCooperativeMatrixSurvey >> chosenDeviceName [
	^ chosenDeviceName
]

{ #category : 'accessing' }
PVCooperativeMatrixSurvey >> deviceReports [
	^ deviceReports
]

{ #category : 'private' }
PVCooperativeMatrixSurvey >> fetchDeviceReports [
	"One report per physical device the loader offers, each naming the device and whether it
	 reports the extension. The context's own device is marked, because a machine can offer
	 the extension on a device no kernel of this project runs on."

	^ (Vk enumeratePhysicalDevices: context instance) collect: [ :each |
		  | device name |
		  device := VkPhysicalDevice on: each.
		  name := device properties deviceNameString.
		  Dictionary newFrom: {
				  (#name -> name).
				  (#supported -> device supportsCooperativeMatrix).
				  (#extensions -> device extensionNames size).
				  (#chosen -> (name = chosenDeviceName)) } ]
]

{ #category : 'inspector' }
PVCooperativeMatrixSurvey >> inspectorCooperativeMatrix: aBuilder [
	"Every device beside the verdict, so the reason the path is skipped is visible next to the
	 device that would lift it. Each row is asked of the survey rather than written here."

	<inspectorPresentationOrder: 10 title: 'Cooperative matrix'>
	^ PVFactRow
		  tableOf: self reportRows
		  nameColumn: 'Device'
		  valueColumn: 'Cooperative matrix'
		  in: aBuilder
]

{ #category : 'reporting' }
PVCooperativeMatrixSurvey >> reportRows [
	"One row per device, plus the verdict. Each row asks its own report, so the table cannot
	 claim support the predicate denies."

	| rows |
	rows := deviceReports collect: [ :each |
			        PVFactRow
				        name: ((each at: #chosen)
						         ifTrue: [ (each at: #name) , ' (this context)' ]
						         ifFalse: [ each at: #name ])
				        value: ((each at: #supported)
						         ifTrue: [ 'reports the extension' ]
						         ifFalse: [ 'does not report it' ]) ].
	^ rows asArray , { (PVFactRow
		   name: 'Verdict'
		   value: (self skipReason ifNil: [ 'available, nothing skipped' ])) }
]

{ #category : 'initialization' }
PVCooperativeMatrixSurvey >> setContext: aContext [
	"Everything the survey reports is read here, because a survey is shown long after the
	 context it asked has been destroyed, and a destroyed context enumerates nothing."

	context := aContext.
	chosenDeviceName := aContext physicalDevice properties deviceNameString.
	deviceReports := self fetchDeviceReports
]

{ #category : 'querying' }
PVCooperativeMatrixSurvey >> skipReason [
	"Why the cooperative matrix path does not run, or nil when it is not skipped. The reason
	 names the extension, and names the other device when one on this machine has it, because
	 that is the difference between an absent feature and a feature behind a device switch."

	self availableOnContextDevice ifTrue: [ ^ nil ].
	self availableSomewhere ifFalse: [
		^ 'No device on this machine reports '
		  , VkPhysicalDevice cooperativeMatrixExtensionName ].
	^ chosenDeviceName , ' does not report '
	  , VkPhysicalDevice cooperativeMatrixExtensionName , ', which '
	  , (', ' join: self supportingDeviceNames) , ' does'
]

{ #category : 'querying' }
PVCooperativeMatrixSurvey >> supportingDeviceNames [
	^ (deviceReports select: [ :each | each at: #supported ]) collect: [
		  :each | each at: #name ]
]
