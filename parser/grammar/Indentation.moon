import Any, Pattern, Sequence, Not, Peek, On, Optional, EOF, T from require 'parser.grammar.generator'
import insert, remove from table
clone = => [v for v in *@]

Whitespace = Pattern '[ \t]*'
Newline = Any {'\r', '\n', '\r\n'},
    tag: 'Newline'

Generate = Sequence {Newline, Optional(Whitespace), Peek Not Newline},
    tag: 'Indent-Generator'
    builder: (stream)=>
        -- Whitespace is node 2, content is node 1
        node = @[2][1]
        indentationLevel = stream.indentationLevel
        whitespaceLength = node and #node or 0

        if whitespaceLength > indentationLevel[#indentationLevel]
            --print '>', stream.getLineInfo!
            stream.pushToken T'INDENT'

            stream.indentationLevel = clone indentationLevel
            indentationLevel = stream.indentationLevel
            insert indentationLevel, whitespaceLength
        else if whitespaceLength == indentationLevel[#indentationLevel]
            --print '=', stream.getLineInfo!
            stream.pushToken T'NEWLINE'
        else
            while whitespaceLength < indentationLevel[#indentationLevel]
                --print '<', stream.getLineInfo!
                stream.pushToken T'DEDENT'
                stream.indentationLevel = clone indentationLevel
                indentationLevel = stream.indentationLevel
                remove indentationLevel

AutoDedent = Peek EOF,
    tag: 'Auto-dedent'
    builder: (stream)=>
        indentationLevel = stream.indentationLevel
        return 'FAIL' if #indentationLevel <= 1

        while #indentationLevel > 1
            --print '-', stream.getLineInfo!
            stream.pushToken T'DEDENT'
            stream.indentationLevel = clone indentationLevel
            indentationLevel = stream.indentationLevel
            remove indentationLevel

return {
    :AutoDedent
    :Generate
    GenerateAndAutoDedent: Any{Generate, AutoDedent}
    :Whitespace
    :Newline
}
