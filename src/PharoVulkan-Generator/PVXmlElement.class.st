"
Minimal XML element for parsing vk.xml.
tag is a String, attributes is a Dictionary, children is an OrderedCollection of PVXmlElement,
text is the concatenated character data content of this element.
"
Class {
	#name : 'PVXmlElement',
	#superclass : 'Object',
	#instVars : [
		'tag',
		'attributes',
		'children',
		'text'
	],
	#category : 'PharoVulkan-Generator-Vulkan',
	#package : 'PharoVulkan-Generator',
	#tag : 'Vulkan'
}

{ #category : 'accessing' }
PVXmlElement >> at: key [
    "Return attribute value string or nil."
    ^ attributes at: key ifAbsent: [nil]
]

{ #category : 'accessing' }
PVXmlElement >> at: key ifAbsent: aBlock [
    ^ attributes at: key ifAbsent: aBlock
]

{ #category : 'accessing' }
PVXmlElement >> attributes [ ^ attributes
]

{ #category : 'accessing' }
PVXmlElement >> children [ ^ children
]

{ #category : 'querying' }
PVXmlElement >> childrenNamed: aTag [
    "Return children whose tag equals aTag."
    ^ children select: [:c | c tag = aTag]
]

{ #category : 'querying' }
PVXmlElement >> firstChildNamed: aTag [
    "Return first child with aTag or nil."
    ^ children detect: [:c | c tag = aTag] ifNone: [nil]
]

{ #category : 'initialization' }
PVXmlElement >> initialize [

	super initialize.
	attributes := Dictionary new.
	children := OrderedCollection new.
	text := ''
]

{ #category : 'accessing' }
PVXmlElement >> tag [ ^ tag
]

{ #category : 'accessing' }
PVXmlElement >> tag: s [  tag := s
]

{ #category : 'accessing' }
PVXmlElement >> text [ ^ text
]

{ #category : 'accessing' }
PVXmlElement >> text: s [  text := s
]
