import Any, Pattern, Sequence, Not, Peek, EOF, T from require 'parser.grammar.generator'

Whitespace = Pattern '[ \t]*'
Newline = Any {'\r', '\n', '\r\n'}

-- TODO: Add ability to store custom state for instances of parsers
Generate = (indentationLevel)=>
    Sequence {Newline, Whitespace, Peek Not Newline},
        builder: (stream)=>
            -- Whitespace is node 2, content is node 1
            whitespaceLength = #@[2][1]

            if whitespaceLength > indentationLevel[#indentationLevel]
                stream.pushToken T'INDENT'
                table\insert indentationLevel, whitespaceLength

            while whitespaceLength < indentationLevel[#indentationLevel]
                stream.pushToken T'DEDENT'
                table\remove indentationLevel

-- In the event of an EOF, push required DEDENT tokens onto stack
AutoDedent = (indentationLevel)=>
    Peek EOF,
        builder: (stream)=>
            return 'FAIL' if #indentationLevel <= 1

            while #indentationLevel > 1
                stream.pushToken T'DEDENT'
                table\remove indentationLevel

GenerateAndAutoDedent = =>
    indentationLevel = {0}

    Any {
        -- nil because not calling with self
        Generate nil, indentationLevel
        AutoDedent nil, indentationLevel
    }

return {
    :AutoDedent
    :Generate
    :GenerateAndAutoDedent
    :Whitespace
    :Newline
}
