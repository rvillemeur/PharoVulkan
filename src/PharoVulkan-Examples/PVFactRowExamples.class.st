"
I hold the one-click example of PVFactRow, the line every two-column inspector view of this project shows. The example builds a row and answers it, so opening it in the inspector lands on the Row tab and shows the table declaration the sixty-four views share. I carry no state and nothing else builds me; the subject is in PharoVulkan-Inspector, which reaches no other package of the project.
"
Class {
	#name : 'PVFactRowExamples',
	#superclass : 'Object',
	#category : 'PharoVulkan-Examples-Inspector',
	#package : 'PharoVulkan-Examples',
	#tag : 'Inspector'
}

{ #category : 'examples' }
PVFactRowExamples class >> wordCountRow [
	"One click: the fact 'Words' is 7, as a row. The value is given as a number and the
	 row converts it, which is the reason this class exists rather than a dictionary at
	 each call site."

	<sampleInstance>
	^ PVFactRow name: 'Words' value: 7
]
