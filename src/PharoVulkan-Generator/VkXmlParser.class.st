"
Parses vk.xml (Khronos Vulkan API registry) and produces structured descriptor objects.
No Pharo class generation happens here — output is plain descriptor objects.
Key methods: parseFile: aFilePath, types, commands, enums.
"
Class {
	#name : 'VkXmlParser',
	#superclass : 'Object',
	#instVars : [
		'xml',
		'types',
		'commands',
		'enums'
	],
	#category : 'PharoVulkan-Generator-Vulkan',
	#package : 'PharoVulkan-Generator',
	#tag : 'Vulkan'
}

{ #category : 'accessing' }
VkXmlParser >> commands [ ^ commands
]

{ #category : 'accessing' }
VkXmlParser >> enums [    ^ enums
]

{ #category : 'parsing' }
VkXmlParser >> parseCommands [
    | cmdsEl |
    cmdsEl := root children detect: [ :c | c tag = 'commands' ] ifNone: [ ^ self ].
    cmdsEl children do: [ :cmdEl |
        | desc nameEl typeEl |
        cmdEl tag = 'command' ifTrue: [
            desc := VkCommandDescriptor new.
            (cmdEl at: 'successcodes' ifAbsent: [ nil ]) ifNotNil: [ :ss |
                desc successCodes: (ss substrings: ',') ].
            (cmdEl at: 'errorcodes' ifAbsent: [ nil ]) ifNotNil: [ :es |
                desc errorCodes: (es substrings: ',') ].
            nameEl := cmdEl children detect: [ :c | c tag = 'proto' ] ifNone: [ nil ].
            nameEl ifNotNil: [
                typeEl := nameEl children detect: [ :c | c tag = 'type' ] ifNone: [ nil ].
                typeEl ifNotNil: [ desc returnType: typeEl text asString ].
                nameEl children detect: [ :c | c tag = 'name' ] ifFound: [ :n |
                    desc name: n text asString ].
                desc params: (self parseParamsFrom: cmdEl) ].
            desc name ifNotNil: [ commands at: desc name put: desc ] ] ]
]

{ #category : 'parsing' }
VkXmlParser >> parseEnums [
	"Iterate top-level <enums> nodes and build VkEnumDescriptor objects."

	(xml childrenNamed: 'enums') do: [ :enumsNode |
			| desc name enumType |
			name := enumsNode at: 'name'.
			name ifNotNil: [
					enumType := enumsNode at: 'type'.
					desc := VkEnumDescriptor new.
					desc name: name.
					desc type:
						(enumType ifNil: [ #enum ] ifNotNil: [ enumType asSymbol ]).
					desc values: Dictionary new.
					(enumsNode childrenNamed: 'enum') do: [ :eNode |
							| valName valStr val |
							valName := eNode at: 'name'.
							valStr := eNode at: 'value'.
							valStr ifNil: [ valStr := eNode at: 'bitpos' ].
							valStr ifNotNil: [
									val := [
										       valStr ifNil: [ 0 ] ifNotNil: [
												       (valStr beginsWith: '0x')
													       ifTrue: [
													       Integer
														       readFrom: (valStr copyFrom: 3 to: valStr size)
														       radix: 16 ]
													       ifFalse: [ valStr asInteger ] ] ]
										       on: Error
										       do: [ :e | 0 ].
									valName ifNotNil: [ desc values at: valName put: val ] ] ].
					enums at: name put: desc ] ]
]

{ #category : 'parsing' }
VkXmlParser >> parseFile: aFilePath [
    "Parse vk.xml at aFilePath. Populates types, commands, and enums dictionaries."
    xml := PVXmlParser parseFile: aFilePath.
    types    := Dictionary new.
    commands := Dictionary new.
    enums    := Dictionary new.
    self parseTypes.
    self parseCommands.
    self parseEnums
]

{ #category : 'parsing' }
VkXmlParser >> parseMembersFrom: typeEl [
    | members |
    members := OrderedCollection new.
    typeEl children do: [ :mNode |
        mNode tag = 'member' ifTrue: [
            | desc raw |
            desc := VkMemberDescriptor new.
            mNode children detect: [ :c | c tag = 'name' ] ifFound: [ :n |
                desc name: n text asString ].
            mNode children detect: [ :c | c tag = 'type' ] ifFound: [ :t |
                desc type: t text asString ].
            raw := mNode text asString.
            desc isPointer: (raw includesSubstring: '*').
            desc isConst: (raw includesSubstring: 'const').
            members add: desc ] ].
    ^ members
]

{ #category : 'parsing' }
VkXmlParser >> parseParamsFrom: cmdEl [
    | params |
    params := OrderedCollection new.
    cmdEl children do: [ :pNode |
        pNode tag = 'param' ifTrue: [
            | desc raw |
            desc := VkMemberDescriptor new.
            pNode children detect: [ :c | c tag = 'name' ] ifFound: [ :n |
                desc name: n text asString ].
            pNode children detect: [ :c | c tag = 'type' ] ifFound: [ :t |
                desc type: t text asString ].
            raw := pNode text asString.
            desc isPointer: (raw includesSubstring: '*').
            desc isConst: (raw includesSubstring: 'const').
            params add: desc ] ].
    ^ params
]

{ #category : 'parsing' }
VkXmlParser >> parseTypes [
    "Iterate <types> nodes and build VkTypeDescriptor objects."
    (xml childrenNamed: 'types') do: [:typesNode |
        (typesNode childrenNamed: 'type') do: [:node |
            | desc name cat |
            name := node at: 'name'.
            name isNil ifTrue: [
                "name may be a child <name> element"
                | nameEl |
                nameEl := node firstChildNamed: 'name'.
                name := nameEl isNil ifTrue: [nil] ifFalse: [nameEl text trimmed]].
            name isNil ifFalse: [
                cat := node at: 'category'.
                desc := VkTypeDescriptor new.
                desc name: name.
                desc category: (cat isNil ifTrue: [#basetype] ifFalse: [cat asSymbol]).
                desc requires: (node at: 'requires').
                desc alias: (node at: 'alias').
                desc members: (self parseMembersFrom: node).
                types at: name put: desc]]]
]

{ #category : 'accessing' }
VkXmlParser >> types [    ^ types
]
