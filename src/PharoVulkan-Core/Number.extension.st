Extension { #name : 'Number' }

{ #category : '*PharoVulkan-Core' }
Number >> asF16 [
	"Extension on Number: the kernel DSL's half conversion. It lives here rather than
	 upstream because half precision is this project's concept, and a kernel's body must mean
	 the same thing when it runs on the host as when it runs on the device."

	^ PVFloat16 floatFromWord: (PVFloat16 wordForFloat: self)
]
