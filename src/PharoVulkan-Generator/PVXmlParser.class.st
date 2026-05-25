"
Minimal streaming XML parser sufficient for vk.xml.
Handles elements, attributes, text content, comments, CDATA, and processing instructions.
Key class method: parse: aString -> PVXmlElement root.
"
Class {
	#name : 'PVXmlParser',
	#superclass : 'Object',
	#instVars : [
		'stream',
		'stack',
		'root'
	],
	#category : 'PharoVulkan-Generator',
	#package : 'PharoVulkan-Generator'
}

{ #category : 'parsing' }
PVXmlParser class >> parse: aString [
    "Parse an XML string and return the root PVXmlElement."
    ^ self new parseSource: aString
]

{ #category : 'parsing' }
PVXmlParser class >> parseFile: aFilePath [
    "Parse XML from the file at aFilePath and return the root PVXmlElement."
    ^ self parse: aFilePath asFileReference contents
]

{ #category : 'private' }
PVXmlParser >> currentElement [
    ^ stack last
]

{ #category : 'parsing' }
PVXmlParser >> parseAttributes [

	| dict |
	dict := Dictionary new.
	[
		self skipWhitespace.
		stream atEnd or: [ #($> $/ ) includes: stream peek ] ] whileFalse: [
			| key val |
			key := self readName.
			key isEmpty ifFalse: [
					self skipWhitespace.
					(stream atEnd not and: [ stream peek = $= ])
						ifTrue: [
								stream next.
								self skipWhitespace.
								val := self readAttributeValue ]
						ifFalse: [ val := key ].
					dict at: key put: val ] ].
	^ dict
]

{ #category : 'parsing' }
PVXmlParser >> parseBang [
    "Handle <!- (comment), <![CDATA[, or <!DOCTYPE."
    | ch |
    stream atEnd ifTrue: [^self].
    ch := stream next.
    ch = $- ifTrue: [
        (stream atEnd not and: [stream peek = $-]) ifTrue: [
            stream next. self parseComment. ^self].
        self skipUntil: $>. ^self].
    ch = $[ ifTrue: [
        | token |
        token := String new: 6.
        1 to: 6 do: [:i | stream atEnd ifFalse: [token at: i put: stream next]].
        token = 'CDATA[' ifTrue: [self parseCData. ^self].
        self skipUntil: $>. ^self].
    self skipUntil: $>
]

{ #category : 'parsing' }
PVXmlParser >> parseCData [
    "Called after '<![CDATA['. Collect text until ']]>'."
    | buf a b |
    buf := WriteStream on: String new.
    a := $ . b := $ .
    [stream atEnd] whileFalse: [
        | c content cur |
        c := stream next.
        (a = $] and: [b = $] and: [c = $>]]) ifTrue: [
            content := buf contents.
            content size >= 2 ifTrue: [content := content copyFrom: 1 to: content size - 2].
            cur := self currentElement.
            cur text: cur text , content.
            ^self].
        buf nextPut: c.
        a := b. b := c]
]

{ #category : 'parsing' }
PVXmlParser >> parseCloseTag [
    self readName.
    self skipUntil: $>.
    stack size > 1 ifTrue: [stack removeLast]
]

{ #category : 'parsing' }
PVXmlParser >> parseComment [
    "Called after '<!--'. Skip until '-->'."
    | a b |
    a := $ . b := $ .
    [stream atEnd] whileFalse: [
        | c |
        c := stream next.
        (a = $- and: [b = $- and: [c = $>]]) ifTrue: [^self].
        a := b. b := c]
]

{ #category : 'parsing' }
PVXmlParser >> parseContent [
    [stream atEnd] whileFalse: [self parseNode]
]

{ #category : 'parsing' }
PVXmlParser >> parseMarkup [
    | ch |
    ch := stream peek.
    ch = $/ ifTrue: [stream next. self parseCloseTag. ^self].
    ch = $! ifTrue: [stream next. self parseBang. ^self].
    ch = $? ifTrue: [stream next. self parseProcessingInstruction. ^self].
    self parseOpenTag
]

{ #category : 'parsing' }
PVXmlParser >> parseNode [
    stream peek = $< ifTrue: [stream next. self parseMarkup. ^self].
    self parseText
]

{ #category : 'parsing' }
PVXmlParser >> parseOpenTag [
    | name attrs elem selfClosing |
    name := self readName.
    name isEmpty ifTrue: [self skipUntil: $>. ^self].
    attrs := self parseAttributes.
    self skipWhitespace.
    selfClosing := (stream atEnd not and: [stream peek = $/]).
    selfClosing ifTrue: [stream next].
    (stream atEnd not and: [stream peek = $>]) ifTrue: [stream next].
    elem := PVXmlElement new.
    elem tag: name.
    attrs keysAndValuesDo: [:k :v | elem attributes at: k put: v].
    self currentElement children add: elem.
    selfClosing ifFalse: [stack addLast: elem]
]

{ #category : 'parsing' }
PVXmlParser >> parseProcessingInstruction [
    "Called after '<'. Skip until '?>'."
    | prev |
    prev := $ .
    [stream atEnd] whileFalse: [
        | c |
        c := stream next.
        (prev = $? and: [c = $>]) ifTrue: [^self].
        prev := c]
]

{ #category : 'parsing' }
PVXmlParser >> parseSource: aString [
    | synthetic |
    synthetic := PVXmlElement new tag: '__root__'.
    stream := ReadStream on: aString.
    stack := OrderedCollection with: synthetic.
    root := synthetic.
    self parseContent.
    ^ root children size = 1
        ifTrue: [root children first]
        ifFalse: [root]
]

{ #category : 'parsing' }
PVXmlParser >> parseText [
    | buf ch txt cur |
    buf := WriteStream on: String new.
    [stream atEnd or: [stream peek = $<]] whileFalse: [
        ch := stream next.
        ch = $& ifTrue: [self readEntityInto: buf] ifFalse: [buf nextPut: ch]].
    txt := buf contents trimmed.
    txt isEmpty ifFalse: [
        cur := self currentElement.
        cur text: cur text , txt]
]

{ #category : 'parsing' }
PVXmlParser >> readAttributeValue [
    | delim buf |
    (stream atEnd or: [(stream peek ~= $') and: [stream peek ~= $"]]) ifTrue: [^''].
    delim := stream next.
    buf := WriteStream on: String new.
    [stream atEnd or: [stream peek = delim]] whileFalse: [
        | ch |
        ch := stream next.
        ch = $& ifTrue: [self readEntityInto: buf] ifFalse: [buf nextPut: ch]].
    stream atEnd ifFalse: [stream next].
    ^ buf contents
]

{ #category : 'parsing' }
PVXmlParser >> readEntityInto: buf [
    "Read XML entity like &amp; &lt; &gt; and write decoded char to buf."
    | entity |
    entity := self readName.
    (stream atEnd not and: [stream peek = $;]) ifTrue: [stream next].
    entity = 'amp' ifTrue: [buf nextPut: $&. ^self].
    entity = 'lt' ifTrue: [buf nextPut: $<. ^self].
    entity = 'gt' ifTrue: [buf nextPut: $>. ^self].
    entity = 'apos' ifTrue: [buf nextPut: $'. ^self].
    entity = 'quot' ifTrue: [buf nextPut: $". ^self].
    "Unknown entity — emit as-is"
    buf nextPut: $&.
    buf nextPutAll: entity.
    buf nextPut: $;
]

{ #category : 'parsing' }
PVXmlParser >> readName [

	| buf |
	buf := WriteStream on: String new.
	[
		| c |
		stream atEnd or: [
				c := stream peek.
				c isSeparator or: [ c = $= or: [ #( $/ $> $< ) includes: c ] ] ] ]
		whileFalse: [ buf nextPut: stream next ].
	^ buf contents
]

{ #category : 'private' }
PVXmlParser >> skipUntil: aChar [
    [stream atEnd or: [stream next = aChar]] whileFalse: []
]

{ #category : 'private' }
PVXmlParser >> skipWhitespace [
    [stream atEnd or: [stream peek isSeparator not]] whileFalse: [stream next]
]
