"
A decoration of one member of a structure: OpMemberDecorate target, member index, decoration, then the decoration's literals. Built by SpvModule >> addMemberDecoration:member:decoration:literals:. Key methods: target:member:decoration:literals: (class-side), instruction.
"
Class {
	#name : 'SpvMemberDecorate',
	#superclass : 'SpvAnnotation',
	#instVars : [
		'member'
	],
	#category : 'PharoVulkan-SPIRV-Builder',
	#package : 'PharoVulkan-SPIRV',
	#tag : 'Builder'
}

{ #category : 'instance creation' }
SpvMemberDecorate class >> target: aStructId member: aMemberIndex decoration: aDecorationNumber literals: aCollection [
"A decoration of one member of a structure, with the literals its decoration asks for."

^ (self target: aStructId decoration: aDecorationNumber literals: aCollection)
	  setMember: aMemberIndex;
	  yourself
]

{ #category : 'accessing' }
SpvMemberDecorate >> member [
	^ member
]

{ #category : 'inspecting' }
SpvMemberDecorate >> memberRows [
	^ { ('member' -> member printString) }
]

{ #category : 'emitting' }
SpvMemberDecorate >> opcode [
	^ SpvOpcode opMemberDecorate
]

{ #category : 'emitting' }
SpvMemberDecorate >> operands [
	"The member index stands between the structure and the decoration, which is where
	 OpMemberDecorate asks for it."

	^ {
		  target.
		  member.
		  decoration } , literals
]

{ #category : 'initialization' }
SpvMemberDecorate >> setMember: anIndex [
	member := anIndex
]
