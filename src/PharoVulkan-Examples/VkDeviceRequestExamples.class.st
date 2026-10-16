"
Examples of the four requests this project makes before it has a device: the application info it names itself with, the instance request, the device request and the queue request.

Each one answers the structure a caller hands the driver, built in object memory so that a click frees nothing. Where the value depends on the machine the example asks VkContext for it, so that reading the example tells you what this project really asks for rather than what it asked for when the example was written.
"
Class {
	#name : 'VkDeviceRequestExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Bindings',
	#package : 'PharoVulkan-Examples',
	#tag : 'Bindings'
}

{ #category : 'examples' }
VkDeviceRequestExamples class >> apiVersionThisProjectAsksFor [
	"One click: the application info both instance paths pass, built in object memory so the
	 click frees nothing. Every field but the API version stays as a fresh store gives it:
	 null names and version zero, which is what tells a driver to apply no workaround."

	<sampleInstance>
	^ VkApplicationInfo new
		  apiVersion: VkContext instanceApiVersion;
		  yourself
]

{ #category : 'examples' }
VkDeviceRequestExamples class >> computeInstanceRequest [
	"One click: the structure the compute path hands vkCreateInstance, built by the real
	 builder and copied into object memory before the external blocks go, so the click frees
	 everything it allocated. No instance is created, so no context needs destroying. The copy
	 is for looking at and not for passing on: its application info pointer still reads as the
	 address of a block that has since been freed."

	<sampleInstance>
	| context appInfo createInfo |
	context := VkContext new.
	appInfo := context buildApplicationInfo.
	^ [
	  createInfo := context
		                buildInstanceCreateInfo: appInfo
		                extensions: VkContext computeInstanceExtensionNames.
	  [ createInfo copyIntoObjectMemory ] ensure: [
		  context freeInstanceCreateInfo: createInfo ] ] ensure: [
		  context freeApplicationInfo: appInfo ]
]

{ #category : 'examples' }
VkDeviceRequestExamples class >> graphicsDeviceRequest [
	"One click: the request the graphics path makes of a device, with the structure type, the
	 one queue create info and the extension count side by side in the Fields tab. The counts
	 come from VkContext rather than from literals here, so the example follows the code that
	 builds the real one. The pointers stay null, because an example must not hold a pointer to
	 a store it does not own; the live create info is covered by
	 VkCoreTest >> testDeviceCreateInfoCarriesEveryEnabledExtension."

	<sampleInstance>
	^ VkDeviceCreateInfo new
		  queueCreateInfoCount: VkContext queueCreateInfosPerDevice;
		  enabledExtensionCount: VkContext graphicsExtensionNames size;
		  yourself
]

{ #category : 'examples' }
VkDeviceRequestExamples class >> oneQueueOnTheFirstFamily [
	"One click: the request the context makes of every device it creates, with the structure
	 type, the family and the queue count side by side in the Fields tab. The count comes from
	 VkContext rather than from a literal here, so the example follows the code that builds the
	 real one. pQueuePriorities stays null, because an example must not hold a pointer to a
	 store it does not own; the live array is covered by
	 VkCoreTest >> testDeviceQueueCreateInfoAsksForOneQueueAtFullPriority."

	<sampleInstance>
	^ VkDeviceQueueCreateInfo new
		  queueFamilyIndex: VkDeviceQueueCreateInfo firstQueueFamily;
		  queueCount: VkContext queuesPerFamily;
		  yourself
]
