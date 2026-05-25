"
Generates PharoVulkan-Bindings classes from VkXmlParser output.
Run generateAll to create enums, structs, handles, and command stubs.
Re-running is idempotent: existing methods are skipped with a Transcript warning.
Key method: generateAll.
"
Class {
	#name : 'VkBindingGenerator',
	#superclass : 'Object',
	#instVars : [
		'parser',
		'targetEnvironment',
		'newClassCount'
	],
	#category : 'PharoVulkan-Generator',
	#package : 'PharoVulkan',
	#tag : 'Generator'
}

{ #category : 'generating' }
VkBindingGenerator >> ffiCallSourceFor: cmdDesc selector: sel [
    | buf params kws |
    params := cmdDesc params.
    buf := WriteStream on: String new.
    params isEmpty
        ifTrue: [
            buf nextPutAll: sel.
            buf nextPutAll: (String with: Character cr).
            buf nextPutAll: '    ^ self ffiCall: #( '.
            buf nextPutAll: cmdDesc returnType , ' ' , cmdDesc name , ' () )' ]
        ifFalse: [
            kws := sel substrings: ':'.
            kws doWithIndex: [ :kw :i |
                | arg |
                arg := (params at: i) name.
                i > 1 ifTrue: [ buf nextPut: $  ].
                buf nextPutAll: kw , ': a'.
                arg isEmpty ifFalse: [
                    buf nextPut: arg first asUppercase.
                    arg size > 1 ifTrue: [ buf nextPutAll: (arg copyFrom: 2 to: arg size) ] ] ].
            buf nextPutAll: (String with: Character cr).
            buf nextPutAll: '    ^ self ffiCall: #( '.
            buf nextPutAll: cmdDesc returnType , ' ' , cmdDesc name , ' ( '.
            params doWithIndex: [ :p :i |
                i > 1 ifTrue: [ buf nextPutAll: ', ' ].
                buf nextPutAll: p type.
                p isPointer ifTrue: [ buf nextPut: $* ].
                buf nextPut: $  .
                buf nextPutAll: 'a'.
                p name isEmpty ifFalse: [
                    buf nextPut: p name first asUppercase.
                    p name size > 1 ifTrue: [ buf nextPutAll: (p name copyFrom: 2 to: p name size) ] ] ].
            buf nextPutAll: ' ) )' ].
    ^ buf contents
]

{ #category : 'generating' }
VkBindingGenerator >> ffiTypeFor: aMemberDescriptor [
    | t |
    t := aMemberDescriptor type.
    aMemberDescriptor isPointer ifTrue: [ ^ 'pointer' ].
    (t = 'uint8_t')  ifTrue: [ ^ 'uint8' ].
    (t = 'uint16_t') ifTrue: [ ^ 'uint16' ].
    (t = 'uint32_t') ifTrue: [ ^ 'uint32' ].
    (t = 'uint64_t') ifTrue: [ ^ 'uint64' ].
    (t = 'int8_t')   ifTrue: [ ^ 'int8' ].
    (t = 'int16_t')  ifTrue: [ ^ 'int16' ].
    (t = 'int32_t')  ifTrue: [ ^ 'int32' ].
    (t = 'int64_t')  ifTrue: [ ^ 'int64' ].
    (t = 'float')    ifTrue: [ ^ 'float' ].
    (t = 'double')   ifTrue: [ ^ 'double' ].
    (t = 'size_t')   ifTrue: [ ^ 'ulong' ].
    (t = 'VkBool32')      ifTrue: [ ^ 'uint32' ].
    (t = 'VkFlags')       ifTrue: [ ^ 'uint32' ].
    (t = 'VkFlags64')     ifTrue: [ ^ 'uint64' ].
    (t = 'VkDeviceSize')  ifTrue: [ ^ 'uint64' ].
    (t = 'VkDeviceAddress') ifTrue: [ ^ 'uint64' ].
    (t = 'char')          ifTrue: [ ^ 'uint8' ].
    (t beginsWith: 'Vk') ifTrue: [
        (#('Flags' 'FlagBits' 'Type' 'Mode' 'Result')
            anySatisfy: [ :suf | t endsWith: suf ])
            ifTrue: [ ^ 'uint32' ] ].
    ^ 'pointer'
]

{ #category : 'generating' }
VkBindingGenerator >> fieldsSourceFor: aVkTypeDescriptor [
    "Build the fieldsDesc source string for a struct."
    | buf |
    buf := WriteStream on: String new.
    buf nextPutAll: '#('.
    aVkTypeDescriptor members do: [:m |
        | ffiType |
        ffiType := self ffiTypeFor: m.
        buf nextPutAll: '(#'.
        buf nextPutAll: m name.
        buf nextPutAll: ' #'.
        buf nextPutAll: ffiType.
        buf nextPutAll: ') '].
    buf nextPut: $).
    ^ buf contents
]

{ #category : 'generating' }
VkBindingGenerator >> generateAll [
    "Generate all bindings in dependency order: enums first, then structs, then handles, then commands."
    parser enums  do: [:desc | self generateEnum: desc].
    parser types  do: [:desc |
        desc category = #struct  ifTrue: [self generateStruct: desc].
        desc category = #handle  ifTrue: [self generateHandle: desc].
        desc category = #union   ifTrue: [self generateStruct: desc]].
    self generateCommands
]

{ #category : 'generating' }
VkBindingGenerator >> generateAll: aFilePath [
    | p |
    p := VkXmlParser new.
    p parseFile: aFilePath.
    self parser: p.
    newClassCount := 0.
    self generateAll
]

{ #category : 'generating' }
VkBindingGenerator >> generateCommands [
    "Add class-side ffiCall: stub methods to Vk for each parsed command.
     Skips commands whose selector already exists on Vk class (idempotent)."
    parser commands do: [:desc |
        | selector |
        selector := self pharoSelectorFor: desc.
        (Vk class includesSelector: selector asSymbol) ifTrue: [
            Transcript showCr: '[VkBindingGenerator] skipping existing Vk >> ' , selector]
        ifFalse: [
            Vk class compile: (self ffiCallSourceFor: desc selector: selector)
                classified: 'generated-api']]
]

{ #category : 'generating' }
VkBindingGenerator >> generateEnum: enumDesc [
    | className enumClass |
    className := enumDesc name.
    (className isNil or: [ className isEmpty ]) ifTrue: [ ^ self ].
    className first isUppercase ifFalse: [ ^ self ].
    (className allSatisfy: [ :c | c isAlphaNumeric or: [ c = $_ ] ]) ifFalse: [ ^ self ].
    (Smalltalk globals includesKey: className asSymbol)
        ifFalse: [
            enumClass := Object << className asSymbol
                package: 'PharoVulkan-Bindings'.
            enumClass comment: 'Generated Vulkan enum: ' , className.
            newClassCount := newClassCount + 1 ]
        ifTrue: [ enumClass := Smalltalk at: className asSymbol ].
    enumDesc values associationsDo: [ :assoc |
        | sel val src |
        sel := self selectorFrom: assoc key.
        val := assoc value.
        src := sel , (String with: Character cr) , '    ^ ' , val printString.
        (enumClass respondsTo: sel asSymbol) ifFalse: [
            enumClass class compile: src classified: 'constants' ] ]
]

{ #category : 'generating' }
VkBindingGenerator >> generateHandle: aVkTypeDescriptor [
    "Create a VkHandle subclass for an opaque handle type.
     Adds _H suffix to avoid collision with higher-level wrapper classes."
    | className cls |
    className := (aVkTypeDescriptor name , '_H') asSymbol.
    (self targetEnvironment includesKey: className) ifTrue: [^self].
    cls := (VkHandle << className)
        slots: #();
        package: 'PharoVulkan-Bindings';
        install.
    cls comment: 'Generated opaque handle for ' , aVkTypeDescriptor name
]

{ #category : 'generating' }
VkBindingGenerator >> generateStruct: aVkTypeDescriptor [
    "Create a VkStructure subclass for a Vulkan struct/union.
     Skips if class already exists (idempotent)."
    | className cls fieldsSource |
    className := aVkTypeDescriptor name asSymbol.
    (self targetEnvironment includesKey: className) ifTrue: [^self].
    cls := (VkStructure << className)
        slots: #();
        package: 'PharoVulkan-Bindings';
        install.
    cls comment: 'Generated Vulkan struct binding for ' , aVkTypeDescriptor name , '.
Fields match the C struct layout. See VkStructure for base behaviour.'.
    fieldsSource := self fieldsSourceFor: aVkTypeDescriptor.
    cls class compile: 'fieldsDesc
    ^ ' , fieldsSource
        classified: 'fields'.
    cls compile: 'initialize
    self defineFields'
        classified: 'initialization'
]

{ #category : 'accessing' }
VkBindingGenerator >> parser: aVkXmlParser [
    parser := aVkXmlParser
]

{ #category : 'generating' }
VkBindingGenerator >> pharoSelectorFor: aCommandDescriptor [
    "Convert a Vulkan command name to a Pharo keyword selector.
     vkCreateInstance -> createInstance: (drops vk prefix, adds : per param)."
    | name base params parts |
    name := aCommandDescriptor name.
    base := (name copyFrom: 3 to: name size).
    base := base first asLowercase asString , (base copyFrom: 2 to: base size).
    params := aCommandDescriptor params.
    params isEmpty ifTrue: [^base].
    parts := WriteStream on: String new.
    params doWithIndex: [:p :i |
        i = 1 ifTrue: [parts nextPutAll: base , ':']
               ifFalse: [parts nextPutAll: p name , ':']].
    ^ parts contents
]

{ #category : 'generating' }
VkBindingGenerator >> selectorFrom: aCommandName [
    | parts camel first |
    parts := aCommandName substrings: '_'.
    parts size < 2 ifTrue: [ ^ aCommandName ].
    first := (parts at: 2) asLowercase.
    camel := WriteStream on: String new.
    camel nextPutAll: first.
    3 to: parts size do: [ :i |
        | p |
        p := parts at: i.
        p isEmpty ifFalse: [
            camel nextPut: p first asUppercase.
            p size > 1 ifTrue: [ camel nextPutAll: (p copyFrom: 2 to: p size) ] ] ].
    ^ camel contents
]

{ #category : 'accessing' }
VkBindingGenerator >> targetEnvironment [
    ^ targetEnvironment ifNil: [targetEnvironment := Smalltalk globals]
]

{ #category : 'accessing' }
VkBindingGenerator >> targetEnvironment: anEnvironment [
    targetEnvironment := anEnvironment
]
